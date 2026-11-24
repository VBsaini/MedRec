# MedRec — RFID Medical Record Lookup

MedRec is a local web app that looks up a patient record using an RFID card UID. An RC522 reader connected to an ESP32 reads the UID, sends it over USB serial, and a Python bridge opens the corresponding MedRec page in Brave.

Patients fill in that record from the MedRec mobile app (Flutter): they sign up, enter their details, allergies, medications and contacts, and upload photos or PDFs of their reports.

## How the reader workflow works

```text
RFID card → RC522 + ESP32 → USB serial → Python bridge → Brave record page
                                                   ↓
                                      React app → Express API → MongoDB
                                                       ↑
                              Flutter app (patient enters data, uploads reports)
```

The RC522 reads a card's UID. The ESP32 sends that UID to the computer; it does not open a browser or need Wi-Fi. The Python bridge adds the UID to the configured record URL and opens it in Brave. The website then fetches the matching record from the API.

This project uses the UID as the record lookup key. A regular RFID card does not open a URL by itself. If you want a phone to open a website by tapping the card, the card must support an NDEF URL and the phone must read it; that is a different flow from this RC522/ESP32 desktop reader.

## Project layout

```text
Backend/                         Express API and MongoDB models
Frontend/                        React + Vite record viewer
mobile/                          Flutter app for patients (data entry and uploads)
Firmware/MedRec_Reader/          Arduino sketch for ESP32 + RC522
Python/rfid_bridge.py            Serial-to-Brave bridge
Python/requirements.txt          Python dependencies
.env.example                     Backend environment template
```

## Run locally

### 1. Install the app dependencies

From the project root:

```bash
npm run install:all
```

### 2. Configure the backend

Create a root `.env` file based on `.env.example`. Set a working MongoDB connection string in `MONGODB_URI` and a long random value in `JWT_SECRET` (it signs login tokens; the backend will not start without it). The backend reads `PORT` from this file; the Vite development proxy uses the same value automatically.

```bash
cp .env.example .env
```

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
```

To load sample patients, run `node Backend/createFakeData.js`. It deletes all existing MedRec data in that database first.

The default backend port is `5000`. If your `.env` sets `PORT=5001`, both the backend and frontend proxy will use port `5001`. You can set `VITE_API_PROXY_TARGET` in `.env` to override the proxy target explicitly.

### 3. Start the API and website

Use two terminals from the project root:

```bash
npm run dev:backend
```

```bash
npm run dev:frontend
```

The frontend is at `http://localhost:5173`. The API health endpoint is at `http://localhost:5000/api/health` (or the port configured in `.env`).

### 4. Flash the ESP32

1. Open `Firmware/MedRec_Reader/MedRec_Reader.ino` in Arduino IDE.
2. Select your ESP32 board and USB port.
3. Install the **MFRC522** Arduino library.
4. Upload the sketch. It uses `115200` baud and emits `RFID_UID:<UID>` when it reads a card.

No Wi-Fi credentials or API address are needed in the firmware. Close Arduino IDE's Serial Monitor before starting the Python bridge, because only one program can use the serial port at a time.

### 5. Connect the RC522 reader

Use 3.3V power for the RC522. These pins match the sketch for a classic ESP32 DevKit:

| RC522 | ESP32 |
|---|---:|
| SDA / SS | GPIO 5 |
| SCK | GPIO 18 |
| MOSI | GPIO 23 |
| MISO | GPIO 19 |
| RST | GPIO 22 |
| 3.3V | 3V3 |
| GND | GND |

The sketch uses GPIO 2 for the onboard status LED. If your board uses different SPI pins or has no LED on GPIO 2, update the pin constants near the top of the sketch.

### 6. Install and run the Python bridge

From the project root:

```bash
python -m pip install -r Python/requirements.txt
python Python/rfid_bridge.py --list
python Python/rfid_bridge.py
```

The bridge tries to detect the ESP32 serial port and opens Brave by default. If detection does not find the board, pass the port shown by `--list`:

```bash
python Python/rfid_bridge.py --port /dev/cu.usbserial-0001
```

On Windows, the port may look like `COM3`:

```powershell
python Python/rfid_bridge.py --port COM3
```

## Mobile app

The Flutter app in `mobile/` is how a patient puts data into their record. It needs the backend from step 3 running.

```bash
cd mobile
```

```bash
flutter pub get
```

```bash
flutter run
```

**Pointing the app at your backend.** The app has to reach the computer running the API:

- Android emulator: the default `http://10.0.2.2:5000` already points at your computer.
- Real phone: connect it to the same Wi-Fi, find your computer's IP address (`ipconfig` on Windows), and enter `http://<that-ip>:5000` under **Server address** on the login screen. You may need to allow Node.js through the Windows firewall.
- To change the default at build time: `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:5000`.

Debug builds allow plain `http://` so they can talk to a local backend. Release builds only allow `https://`.

**What the app does**

- Sign up and log in. The login token is kept in the phone's secure storage.
- Edit your profile and the diabetes, heart and mental-health sections.
- Add, edit and delete allergies, medications, surgeries, medical history, family history and emergency contacts.
- Upload reports: take a photo, pick photos from the gallery, or pick PDFs. Up to 10 files per report, 10 MB each. View and delete them later.
- Link your RFID card by typing its UID, and see who has viewed your record by card.

Run the checks with `flutter analyze` and `flutter test` from `mobile/`.

**Android build fails with "Unable to establish loopback connection".** Java cannot create its local sockets in a Windows temp folder whose path uses a short name such as `C:\Users\VAIBHA~1\...` (common when the Windows user name has a space). Point Java at a normal folder before building:

```powershell
New-Item -ItemType Directory -Force C:\Users\Public\jtmp
$env:JAVA_TOOL_OPTIONS = "-Djdk.net.unixdomain.tmpdir=C:/Users/Public/jtmp"
flutter run
```

To make it permanent, set `JAVA_TOOL_OPTIONS` to that value in your Windows user environment variables.

## Testing

Tests run in three phases. Each phase needs a bit more running.

**1. Unit tests.** No database, device or network is needed.

```bash
cd Backend && npm run test:unit
```

```bash
python -m unittest discover -s Python/tests -v
```

```bash
cd mobile && flutter test test/unit
```

**2. Integration tests.** The backend tests run the real API against MongoDB at `mongodb://127.0.0.1:27017/medrec_test`. Set `TEST_MONGODB_URI` to use another server. The database is wiped, so its name must contain "test". The app tests run the whole app against an in-memory fake API.

```bash
cd Backend && npm run test:integration
```

```bash
cd mobile && flutter test test/integration
```

**3. Whole-system test.** This needs MongoDB, a running Android emulator, Flutter, Python and Chrome. It starts a throwaway API and runs the real app on the emulator: sign up, profile, record lists, a photo and PDF upload, card linking and logging back in. It then checks the uploads through the API, feeds the card through the RFID bridge's serial loop as the ESP32 would, and opens the resulting URL in headless Chrome to check the web record page. Everything it creates is removed afterwards, except a screenshot in `system-test/output/`.

```bash
npm run test:system
```

For a real phone, set `SYSTEM_TEST_DEVICE_HOST` to your computer's Wi-Fi IP address.

## URL configuration

By default, a tap on UID `04A1B2C3` opens:

```text
http://localhost:5173/record/04A1B2C3
```

Set the URL prefix and optional suffix on the command line. This supports a deployed website or an existing short-link pattern:

```bash
python Python/rfid_bridge.py \
  --prefix "https://medrec.example/record/" \
  --suffix "?source=rfid"
```

You can also set `MEDREC_URL_PREFIX` and `MEDREC_URL_SUFFIX` environment variables. The prefix must be a complete `http://` or `https://` URL. Use `--browser default` to open the system's default browser instead of Brave, or `--no-browser` to print URLs without opening them.

## Registering cards

The UID printed by the bridge is upper-case hexadecimal. The patient links it from the mobile app (**RFID card** on the home screen), which stores it in their `card_Id` field. For example, if the reader reports `04A1B2C3`, the patient record's `card_Id` must be `04A1B2C3`. The sample records use IDs such as `MED001`; those are placeholders and will not match a physical card unless its stored ID is changed to the UID the reader reports.

The frontend route `/record/:cardId` calls `GET /api/records/user/card/:cardId`. The API returns a 404 page when that UID is not registered.

## Troubleshooting

- **No serial port detected:** run `python Python/rfid_bridge.py --list`, then pass the ESP32 port with `--port`.
- **Port is busy:** close Arduino Serial Monitor and any other serial terminal.
- **Brave was not found:** install Brave or run the bridge with `--browser default`.
- **The record page says the card is not registered:** compare the UID printed in the terminal with the patient's `card_Id` value in MongoDB.
- **The record page cannot fetch data:** confirm MongoDB is reachable, the backend is running, and the Vite proxy target uses the backend's `PORT`.
- **ESP32 does not read cards:** check RC522 wiring and 3.3V power, then confirm the firmware's pin constants match the board wiring.

## API endpoints

| Method | Endpoint | Access | Description |
|---|---|---|---|
| GET | `/api/records/user/card/:cardId` | public | Find a patient's record by card UID |
| POST | `/api/records/visitor` | public | Log a visitor access |
| POST | `/api/auth/signup` | public | Register and receive a JWT |
| POST | `/api/auth/login` | public | Log in and receive a JWT |
| GET, PATCH, ... | `/api/me/...` | login | The logged-in patient's own record |
| GET, POST, ... | `/api/reports/...` | login | The logged-in patient's uploaded reports |
| GET | `/api/health` | public | API health check |

The full list, with request fields, is in [Backend/README_DB_ROUTES.md](Backend/README_DB_ROUTES.md).

## Access note

Everything a patient can change, and every uploaded report or photo, requires that patient's login. The card lookup is different: it is deliberately open so a record can be read in an emergency, and it returns the profile, conditions, allergies, medications, history and emergency contacts (never the email, password or uploaded files) to anyone who has the card's UID. An RFID UID can be copied, so treat this as a prototype with sample data until card access to real medical records is protected with an appropriate design.

## License

ISC
