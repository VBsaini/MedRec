# MedRec — Medical Records System with RFID Card Access

A complete medical records management system that opens patient records by tapping an RFID card on an RC522 reader connected to an ESP32.

## Architecture

```
┌─────────────┐     Serial/USB      ┌──────────────────┐     HTTP      ┌─────────────────┐
│ ESP32 +     │ ──────────────────► │ Python Bridge    │ ───────────► │ React Frontend  │
│ RC522 RFID  │   Card UID          │ rfid_bridge.py   │  Open URL    │ (Vite + React)  │
└─────────────┘                     └──────────────────┘              └────────┬────────┘
                                                                                │
                                                                                │ API
                                                                                ▼
                                                                       ┌─────────────────┐
                                                                       │ Express.js API  │
                                                                       │ (Node.js)       │
                                                                       └────────┬────────┘
                                                                                │
                                                                                │
                                                                                ▼
                                                                       ┌─────────────────┐
                                                                       │ MongoDB Atlas   │
                                                                       └─────────────────┘
```

## Project Structure

```
MedRec/
├── Backend/                 # Node.js + Express API
│   ├── App.js              # Main server entry point
│   ├── config/db.js        # MongoDB connection
│   ├── models/             # Mongoose schemas (User, Allergy, etc.)
│   ├── routes/             # API route handlers
│   ├── services/           # Business logic (notifications)
│   └── package.json
│
├── Frontend/               # React + Vite web app
│   ├── src/
│   │   ├── App.jsx         # Main app with routing
│   │   ├── main.jsx        # React entry point
│   │   └── styles.css      # Global styles
│   ├── index.html
│   ├── vite.config.js
│   └── package.json
│
├── Firmware/               # ESP32 Arduino sketch
│   └── MedRec_Reader.ino   # RC522 RFID reader firmware
│
├── Python/                 # Serial-to-browser bridge
│   ├── rfid_bridge.py      # Reads serial, opens browser
│   └── requirements.txt
│
├── uploads/                # Uploaded medical reports (PDFs, images)
├── .env.example            # Environment variable template
├── .gitignore
├── package.json            # Root workspace scripts
└── README.md
```

## Quick Start

### Prerequisites

- Node.js 18+
- Python 3.8+
- MongoDB Atlas cluster (or local MongoDB)
- ESP32 dev board + RC522 RFID module

### 1. Install Dependencies

```bash
# From project root
npm run install:all
```

### 2. Configure Environment

```bash
cp .env.example .env
# Edit .env with your MongoDB connection string
```

### 3. Start Backend

```bash
npm run dev:backend
# API runs on http://localhost:5000
```

### 4. Start Frontend

```bash
npm run dev:frontend
# Opens on http://localhost:5173
```

### 5. Flash ESP32

1. Open `Firmware/MedRec_Reader.ino` in Arduino IDE
2. Install libraries: `MFRC522`, `ArduinoJson`
3. Update WiFi credentials and API base URL
4. Upload to ESP32

### 6. Run Python Bridge

```bash
cd Python
pip install -r requirements.txt
python rfid_bridge.py
# Or specify port: python rfid_bridge.py --port COM3
```

## How It Works

1. **User taps RFID card** on the RC522 reader
2. **ESP32 reads the card UID** and sends it via Serial to the Python script
3. **Python script** receives the UID and opens the browser to `http://localhost:5173/record/<UID>`
4. **React frontend** fetches the patient record from the API: `GET /api/records/user/card/<UID>`
5. **Express API** queries MongoDB and returns the full patient record with all populated data
6. **Frontend displays** the medical record with critical alerts, medications, history, and emergency contacts

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/records/user/card/:cardId` | Get patient by RFID card ID |
| GET | `/api/records/user/:userId/profile` | Get patient by MongoDB ID |
| POST | `/api/records/visitor` | Log a visitor access |
| GET | `/api/records/visitors/:userId` | Get visitor history |
| POST | `/api/auth/signup` | Register new user |
| POST | `/api/auth/login` | Login (returns JWT) |
| POST | `/api/records/medical-history/:userId` | Add medical history |
| POST | `/api/records/allergy/:userId` | Add allergy |
| POST | `/api/records/surgery/:userId` | Add surgery |
| POST | `/api/records/medication/:userId` | Add medication |
| GET | `/api/health` | Health check |

## Hardware Wiring (ESP32 ↔ RC522)

| RC522 Pin | ESP32 Pin |
|-----------|-----------|
| SDA (SS)  | GPIO 5    |
| SCK       | GPIO 18   |
| MOSI      | GPIO 23   |
| MISO      | GPIO 19   |
| RST       | GPIO 0    |
| GND       | GND       |
| 3.3V      | 3.3V      |

## License

ISC
