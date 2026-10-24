#include <SPI.h>
#include <MFRC522.h>

// RC522 wiring for the default VSPI pins on a classic ESP32 DevKit.
// Change these constants if your board uses a different SPI pin mapping.
constexpr byte SS_PIN = 5;     // RC522 SDA/SS
constexpr byte RST_PIN = 22;   // RC522 RST
constexpr byte SCK_PIN = 18;
constexpr byte MISO_PIN = 19;
constexpr byte MOSI_PIN = 23;
constexpr byte LED_PIN = 2;    // Set to a different GPIO if your board has no LED here.

constexpr unsigned long DEBOUNCE_MS = 1500;
constexpr unsigned long SERIAL_BAUD = 115200;

MFRC522 rfid(SS_PIN, RST_PIN);
String lastUid;
unsigned long lastTapAt = 0;

String readCardUid() {
  String uid;
  uid.reserve(rfid.uid.size * 2);

  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) uid += '0';
    uid += String(rfid.uid.uidByte[i], HEX);
  }

  uid.toUpperCase();
  return uid;
}

void blinkLed(byte count, unsigned int durationMs = 100) {
  for (byte i = 0; i < count; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(durationMs);
    digitalWrite(LED_PIN, LOW);
    delay(durationMs);
  }
}

void finishCardRead() {
  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
}

void setup() {
  Serial.begin(SERIAL_BAUD);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  SPI.begin(SCK_PIN, MISO_PIN, MOSI_PIN, SS_PIN);
  rfid.PCD_Init();
  delay(4); // Give the RC522 antenna a moment to settle after initialization.

  Serial.println("MEDREC_READER_READY");
}

void loop() {
  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) return;

  const String uid = readCardUid();
  const unsigned long now = millis();
  const bool isDuplicateTap = uid == lastUid && (now - lastTapAt) < DEBOUNCE_MS;

  if (!isDuplicateTap) {
    lastUid = uid;
    lastTapAt = now;

    // Protocol consumed by Python/rfid_bridge.py. Keep this line machine-readable.
    Serial.print("RFID_UID:");
    Serial.println(uid);
    blinkLed(1);
  }

  finishCardRead();
}
