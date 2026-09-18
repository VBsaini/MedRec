#include <SPI.h>
#include <MFRC522.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// ================= CONFIGURATION =================
// WiFi credentials
const char* ssid          = "YOUR_WIFI_SSID";
const char* password       = "YOUR_WIFI_PASSWORD";

// Backend API base URL (your PC's IP where Node.js runs)
const char* apiBase        = "http://192.168.1.100:3000/api/records/user/card/";

// RC522 Pinout (ESP32 default SPI: SCK=18, MISO=19, MOSI=23)
#define SS_PIN   5    // SDA/SS
#define RST_PIN   0   // RST

// Built-in LED for status feedback
#define LED_PIN  2

// Debounce interval (ms) — ignore re-taps within this window
#define DEBOUNCE_MS 3000

// =================================================

MFRC522 rfid(SS_PIN, RST_PIN);
unsigned long lastTap = 0;
String lastUID = "";

void blinkLED(int times, int duration = 150) {
  for (int i = 0; i < times; i++) {
    digitalWrite(LED_PIN, HIGH);
    delay(duration);
    digitalWrite(LED_PIN, LOW);
    delay(duration);
  }
}

String readCardUID() {
  String uid = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) uid += "0";
    uid += String(rfid.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();
  return uid;
}

void openRecord(String uid) {
  HTTPClient http;
  String url = String(apiBase) + uid;
  
  Serial.println("Fetching: " + url);
  http.begin(url);
  int code = http.GET();

  if (code == 200) {
    String payload = http.getString();
    Serial.println("RECORD_FOUND:" + uid);
    blinkLED(2);  // Success indicator
  } 
  else if (code == 404) {
    Serial.println("NO_RECORD:" + uid);
    blinkLED(5, 100);  // Error: card not registered
  }
  else {
    Serial.println("HTTP_ERROR:" + String(code));
    blinkLED(3, 300);  // Connection error
  }

  http.end();
}

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // Initialize RFID
  SPI.begin();
  rfid.PCD_Init();
  Serial.println("RC522 RFID Reader initialized");

  // Connect to WiFi
  Serial.print("Connecting to WiFi");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected. IP: " + WiFi.localIP().toString());
  blinkLED(3);
}

void loop() {
  // Look for new card
  if (!rfid.PICC_IsNewCardPresent()) return;
  if (!rfid.PICC_ReadCardSerial())   return;

  String uid = readCardUID();

  // Debounce: skip if same card tapped too quickly
  unsigned long now = millis();
  if (uid == lastUID && (now - lastTap) < DEBOUNCE_MS) {
    rfid.PICC_HaltA();
    return;
  }

  lastUID  = uid;
  lastTap  = now;

  Serial.println("Card tapped: " + uid);
  openRecord(uid);

  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
}
