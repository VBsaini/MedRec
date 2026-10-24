# MedRec — RFID Medical Record Lookup

MedRec is a local web app that looks up a patient record using an RFID card UID. An RC522 reader connected to an ESP32 reads the UID, sends it over USB serial, and a Python bridge opens the corresponding MedRec page in Brave.

## How the reader workflow works

```text
RFID card → RC522 + ESP32 → USB serial → Python bridge → Brave record page
                                                   ↓
                                      React app → Express API → MongoDB
```

The RC522 reads a card's UID. The ESP32 sends that UID to the computer; it does not open a browser or need Wi-Fi. The Python bridge adds the UID to the configured record URL and opens it in Brave. The website then fetches the matching record from the API.

This project uses the UID as the record lookup key. A regular RFID card does not open a URL by itself. If you want a phone to open a website by tapping the card, the card must support an NDEF URL and the phone must read it; that is a different flow from this RC522/ESP32 desktop reader.

## Project layout

```text
Backend/                         Express API and MongoDB models
Frontend/                        React + Vite record viewer
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

### 2. Configure MongoDB

Create a root `.env` file based on `.env.example` and set a working MongoDB connection string. The backend reads `PORT` from this file; the Vite development proxy uses the same value automatically.

```bash
cp .env.example .env
```

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

The UID printed by the bridge is upper-case hexadecimal. Store that exact UID in the patient's `card_Id` field in MongoDB. For example, if the reader reports `04A1B2C3`, the patient record's `card_Id` must be `04A1B2C3`. The sample records use IDs such as `MED001`; those are placeholders and will not match a physical card unless its stored ID is changed to the UID the reader reports.

The frontend route `/record/:cardId` calls `GET /api/records/user/card/:cardId`. The API returns a 404 page when that UID is not registered.

## Troubleshooting

- **No serial port detected:** run `python Python/rfid_bridge.py --list`, then pass the ESP32 port with `--port`.
- **Port is busy:** close Arduino Serial Monitor and any other serial terminal.
- **Brave was not found:** install Brave or run the bridge with `--browser default`.
- **The record page says the card is not registered:** compare the UID printed in the terminal with the patient's `card_Id` value in MongoDB.
- **The record page cannot fetch data:** confirm MongoDB is reachable, the backend is running, and the Vite proxy target uses the backend's `PORT`.
- **ESP32 does not read cards:** check RC522 wiring and 3.3V power, then confirm the firmware's pin constants match the board wiring.

## API endpoints

| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/records/user/card/:cardId` | Find a patient and populated medical record by card UID |
| GET | `/api/records/user/:userId/profile` | Get a patient profile |
| POST | `/api/records/visitor` | Log a visitor access |
| GET | `/api/records/visitors/:userId` | Get visitor history |
| POST | `/api/auth/signup` | Register a user |
| POST | `/api/auth/login` | Log in and receive a JWT |
| GET | `/api/health` | API health check |

## Access note

An RFID UID can be copied, and the current card lookup endpoint serves records without a login. Treat this as a prototype with sample data until access to real medical records is protected with an appropriate authentication and authorization design.

## License

ISC
