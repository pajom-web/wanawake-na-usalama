#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <stdlib.h>
#include <string.h>

// Board: ESP32 NodeMCU-32
// GPS wiring: GPS TX -> GPIO16, GPS RX -> GPIO17, VCC -> 3V3, GND -> GND.
// Button wiring: one button leg -> GPIO4, other leg -> GND. The code uses INPUT_PULLUP.

const char* wifiSsid = "Pajom";
const char* wifiPassword = "sijaweka"; 

// Use this computer's WiFi/LAN IP, not localhost. Check with `ipconfig`.
const char* apiUrl = "http://10.19.105.170:8000/api/iot/danger-alerts/";
const char* apiKey = "dev-iot-sos-key";
const char* deviceId = "esp32-node-001";

const int buttonPin = 4;
const int statusLedPin = 2;
const int gpsRxPin = 16;
const int gpsTxPin = 17;
const uint32_t gpsBaud = 9600;
const uint32_t debounceMs = 80;
const uint32_t sendCooldownMs = 10000;
const uint32_t pressRetryMs = 1000;
const uint32_t maxGpsAgeMs = 15000;
const uint32_t diagnosticsIntervalMs = 5000;
const size_t nmeaBufferSize = 128;

struct GpsFix {
  bool valid;
  double latitude;
  double longitude;
  bool hasDateTime;
  int year;
  int month;
  int day;
  int hour;
  int minute;
  int second;
  uint32_t lastFixAt;
  uint32_t charsProcessed;
};

GpsFix gpsFix = {
  false,
  0.0,
  0.0,
  false,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
  0,
};
HardwareSerial gpsSerial(2);
char nmeaBuffer[nmeaBufferSize];
size_t nmeaLength = 0;

int lastButtonReading = HIGH;
int stableButtonState = HIGH;
uint32_t lastDebounceAt = 0;
uint32_t lastSendAt = 0;
uint32_t lastPressAttemptAt = 0;
uint32_t lastDiagnosticsAt = 0;
uint32_t lastDiagnosticsGpsChars = 0;
uint32_t lastGpsSentenceAt = 0;
int lastGpsFixQuality = -1;
int lastGpsSatellites = -1;
char lastRmcStatus = '-';
bool alertPending = false;

bool sendDangerAlert();
bool ensureWifi();
String gpsTimestampIso();
void blinkStatus(int count, int delayMs);
void printDiagnostics();
void processGpsChar(char value);
void parseNmeaSentence(const char* sentence);
int splitNmeaFields(char* sentence, char* fields[], int maxFields);
bool isSentenceType(const char* sentenceId, const char* type);
bool parseNmeaCoordinate(const char* raw, const char* hemisphere, double& decimalDegrees);
void parseRmcDateTime(const char* rawTime, const char* rawDate);

void setup() {
  pinMode(buttonPin, INPUT_PULLUP);
  pinMode(statusLedPin, OUTPUT);
  digitalWrite(statusLedPin, LOW);

  Serial.begin(115200);
  delay(1000);
  gpsSerial.begin(gpsBaud, SERIAL_8N1, gpsRxPin, gpsTxPin);

  Serial.println("ESP32 danger button starting");
  Serial.print("Alert endpoint: ");
  Serial.println(apiUrl);
  ensureWifi();
  printDiagnostics();
}

void loop() {
  while (gpsSerial.available() > 0) {
    processGpsChar((char)gpsSerial.read());
  }

  int reading = digitalRead(buttonPin);
  if (reading != lastButtonReading) {
    lastDebounceAt = millis();
    Serial.print("Button raw state changed: ");
    Serial.println(reading == LOW ? "PRESSED" : "RELEASED");
  }

  if ((millis() - lastDebounceAt) > debounceMs && reading != stableButtonState) {
    stableButtonState = reading;
    Serial.print("Button stable state: ");
    Serial.println(stableButtonState == LOW ? "PRESSED" : "RELEASED");

    if (stableButtonState == LOW) {
      alertPending = true;
      lastPressAttemptAt = 0;
      Serial.println("Button press detected. Alert queued.");
    }
  }

  lastButtonReading = reading;

  if (alertPending && millis() - lastPressAttemptAt > pressRetryMs) {
    lastPressAttemptAt = millis();
    Serial.println("Alert pending. Trying to send...");
    if (sendDangerAlert()) {
      alertPending = false;
      Serial.println("Alert delivered to dashboard.");
    }
  }

  if (millis() - lastDiagnosticsAt > diagnosticsIntervalMs) {
    printDiagnostics();
    lastDiagnosticsAt = millis();
  }
}

bool sendDangerAlert() {
  if (lastSendAt > 0 && millis() - lastSendAt < sendCooldownMs) {
    Serial.println("Alert ignored during cooldown");
    return true;
  }

  if (!gpsFix.valid || millis() - gpsFix.lastFixAt > maxGpsAgeMs) {
    Serial.println("No fresh GPS fix. Alert not sent.");
    Serial.println("Keep the GPS antenna outside or near a window until diagnostics show fix: valid.");
    blinkStatus(4, 120);
    return false;
  }

  if (!ensureWifi()) {
    Serial.println("WiFi unavailable. Alert not sent.");
    blinkStatus(5, 120);
    return false;
  }

  double latitude = gpsFix.latitude;
  double longitude = gpsFix.longitude;
  String pressedAt = gpsTimestampIso();

  String payload = String("{\"device_id\":\"") + deviceId + "\","
      + "\"latitude\":" + String(latitude, 6) + ","
      + "\"longitude\":" + String(longitude, 6) + ","
      + "\"description\":\"ESP32 danger button pressed\"";
  if (pressedAt.length() > 0) {
    payload += String(",\"pressed_at\":\"") + pressedAt + "\"";
  }
  payload += "}";

  Serial.print("Alert POST URL: ");
  Serial.println(apiUrl);
  Serial.print("Alert payload: ");
  Serial.println(payload);

  WiFiClient client;
  HTTPClient http;
  http.begin(client, apiUrl);
  http.setTimeout(8000);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("X-IOT-API-KEY", apiKey);

  int statusCode = http.POST(payload);
  String responseBody = http.getString();
  http.end();

  Serial.print("Alert POST status: ");
  Serial.println(statusCode);
  Serial.println(responseBody);

  if (statusCode <= 0) {
    Serial.print("Backend unreachable: ");
    Serial.println(http.errorToString(statusCode));
    Serial.println("Run Django with: python manage.py runserver 0.0.0.0:8000");
    Serial.println("Also allow port 8000 through Windows Firewall if needed.");
  }

  if (statusCode >= 200 && statusCode < 300) {
    lastSendAt = millis();
    blinkStatus(2, 180);
    return true;
  } else {
    blinkStatus(6, 120);
    return false;
  }
}

bool ensureWifi() {
  if (WiFi.status() == WL_CONNECTED) {
    return true;
  }

  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  WiFi.begin(wifiSsid, wifiPassword);
  Serial.print("Connecting to WiFi");

  uint32_t startedAt = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - startedAt < 20000) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("WiFi connected. IP: ");
    Serial.println(WiFi.localIP());
    return true;
  }
  return false;
}

String gpsTimestampIso() {
  if (!gpsFix.hasDateTime) {
    return "";
  }

  char buffer[25];
  snprintf(
    buffer,
    sizeof(buffer),
    "%04d-%02d-%02dT%02d:%02d:%02dZ",
    gpsFix.year,
    gpsFix.month,
    gpsFix.day,
    gpsFix.hour,
    gpsFix.minute,
    gpsFix.second
  );
  return String(buffer);
}

void blinkStatus(int count, int delayMs) {
  for (int i = 0; i < count; i++) {
    digitalWrite(statusLedPin, HIGH);
    delay(delayMs);
    digitalWrite(statusLedPin, LOW);
    delay(delayMs);
  }
}

void printDiagnostics() {
  Serial.println("--- diagnostics ---");
  Serial.print("WiFi: ");
  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("connected, IP ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("not connected");
  }

  Serial.print("Button GPIO");
  Serial.print(buttonPin);
  Serial.print(": ");
  Serial.println(digitalRead(buttonPin) == LOW ? "PRESSED" : "RELEASED");

  Serial.print("GPS chars: ");
  Serial.print(gpsFix.charsProcessed);
  Serial.print(", fix: ");
  Serial.print(gpsFix.valid ? "valid" : "invalid");
  Serial.print(", age ms: ");
  Serial.println(gpsFix.valid ? millis() - gpsFix.lastFixAt : 0);
  if (gpsFix.valid) {
    Serial.print("GPS lat/lon: ");
    Serial.print(gpsFix.latitude, 6);
    Serial.print(", ");
    Serial.println(gpsFix.longitude, 6);
  }
  Serial.print("GPS stream: ");
  Serial.println(gpsFix.charsProcessed == lastDiagnosticsGpsChars ? "no new data" : "receiving");
  Serial.print("GPS quality: ");
  Serial.print(lastGpsFixQuality);
  Serial.print(", satellites: ");
  Serial.print(lastGpsSatellites);
  Serial.print(", RMC status: ");
  Serial.println(lastRmcStatus);
  if (lastGpsSentenceAt > 0) {
    Serial.print("Last GPS sentence age ms: ");
    Serial.println(millis() - lastGpsSentenceAt);
  }
  Serial.print("Alert pending: ");
  Serial.println(alertPending ? "yes" : "no");
  lastDiagnosticsGpsChars = gpsFix.charsProcessed;
  Serial.println("-------------------");
}

void processGpsChar(char value) {
  gpsFix.charsProcessed++;

  if (value == '$') {
    nmeaLength = 0;
  }

  if (value == '\n' || value == '\r') {
    if (nmeaLength > 0) {
      nmeaBuffer[nmeaLength] = '\0';
      parseNmeaSentence(nmeaBuffer);
      nmeaLength = 0;
    }
    return;
  }

  if (nmeaLength < nmeaBufferSize - 1) {
    nmeaBuffer[nmeaLength++] = value;
  } else {
    nmeaLength = 0;
  }
}

void parseNmeaSentence(const char* sentence) {
  char copy[nmeaBufferSize];
  strncpy(copy, sentence, sizeof(copy));
  copy[sizeof(copy) - 1] = '\0';

  char* fields[20];
  int fieldCount = splitNmeaFields(copy, fields, 20);
  if (fieldCount == 0) {
    return;
  }
  lastGpsSentenceAt = millis();

  if (isSentenceType(fields[0], "RMC")) {
    if (fieldCount >= 3 && fields[2][0] != '\0') {
      lastRmcStatus = fields[2][0];
    }

    if (fieldCount < 10 || fields[2][0] != 'A') {
      return;
    }

    double latitude = 0.0;
    double longitude = 0.0;
    if (!parseNmeaCoordinate(fields[3], fields[4], latitude) ||
        !parseNmeaCoordinate(fields[5], fields[6], longitude)) {
      return;
    }

    gpsFix.valid = true;
    gpsFix.latitude = latitude;
    gpsFix.longitude = longitude;
    gpsFix.lastFixAt = millis();
    parseRmcDateTime(fields[1], fields[9]);
    return;
  }

  if (isSentenceType(fields[0], "GGA")) {
    if (fieldCount >= 8) {
      lastGpsFixQuality = atoi(fields[6]);
      lastGpsSatellites = atoi(fields[7]);
    }

    if (fieldCount < 7 || atoi(fields[6]) <= 0) {
      return;
    }

    double latitude = 0.0;
    double longitude = 0.0;
    if (!parseNmeaCoordinate(fields[2], fields[3], latitude) ||
        !parseNmeaCoordinate(fields[4], fields[5], longitude)) {
      return;
    }

    gpsFix.valid = true;
    gpsFix.latitude = latitude;
    gpsFix.longitude = longitude;
    gpsFix.lastFixAt = millis();
  }
}

int splitNmeaFields(char* sentence, char* fields[], int maxFields) {
  int count = 0;
  fields[count++] = sentence;

  for (char* cursor = sentence; *cursor != '\0' && count < maxFields; cursor++) {
    if (*cursor == ',') {
      *cursor = '\0';
      fields[count++] = cursor + 1;
    } else if (*cursor == '*') {
      *cursor = '\0';
      break;
    }
  }

  return count;
}

bool isSentenceType(const char* sentenceId, const char* type) {
  return strlen(sentenceId) >= 6 && strcmp(sentenceId + 3, type) == 0;
}

bool parseNmeaCoordinate(const char* raw, const char* hemisphere, double& decimalDegrees) {
  if (raw == nullptr || raw[0] == '\0' || hemisphere == nullptr || hemisphere[0] == '\0') {
    return false;
  }

  double value = atof(raw);
  int degrees = (int)(value / 100);
  double minutes = value - (degrees * 100);
  decimalDegrees = degrees + (minutes / 60.0);

  if (hemisphere[0] == 'S' || hemisphere[0] == 'W') {
    decimalDegrees *= -1.0;
  }

  return true;
}

void parseRmcDateTime(const char* rawTime, const char* rawDate) {
  if (rawTime == nullptr || rawDate == nullptr || strlen(rawTime) < 6 || strlen(rawDate) < 6) {
    gpsFix.hasDateTime = false;
    return;
  }

  gpsFix.hour = (rawTime[0] - '0') * 10 + (rawTime[1] - '0');
  gpsFix.minute = (rawTime[2] - '0') * 10 + (rawTime[3] - '0');
  gpsFix.second = (rawTime[4] - '0') * 10 + (rawTime[5] - '0');
  gpsFix.day = (rawDate[0] - '0') * 10 + (rawDate[1] - '0');
  gpsFix.month = (rawDate[2] - '0') * 10 + (rawDate[3] - '0');

  int twoDigitYear = (rawDate[4] - '0') * 10 + (rawDate[5] - '0');
  gpsFix.year = twoDigitYear >= 80 ? 1900 + twoDigitYear : 2000 + twoDigitYear;
  gpsFix.hasDateTime = true;
}
