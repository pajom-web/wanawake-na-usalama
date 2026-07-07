# ESP32 Danger Button

This folder contains the Arduino sketch for an ESP32 NodeMCU-32 with a GPS
module and a physical panic button.

## Hardware

- ESP32 NodeMCU-32
- GPS module, for example NEO-6M
- Momentary push button
- Jumper wires

Default wiring used by `esp32_danger_button/esp32_danger_button.ino`:

- GPS TX -> ESP32 GPIO16
- GPS RX -> ESP32 GPIO17
- GPS GND -> ESP32 GND
- GPS VCC -> ESP32 3V3 or 5V, depending on your GPS module
- Button leg 1 -> ESP32 GPIO4
- Button leg 2 -> ESP32 GND

## Arduino Setup

1. Install ESP32 board support in Arduino IDE.
2. No extra GPS library is required; the sketch includes a small NMEA parser.
3. Open `esp32_danger_button/esp32_danger_button.ino` directly in Arduino IDE.
   Do not upload a separate GPS test sketch when testing alerts.
4. Set `wifiSsid`, `wifiPassword`, `apiUrl`, `apiKey`, and `deviceId`.
5. Use the backend computer's LAN IP in `apiUrl`, for example
   `http://192.168.1.10:8000/api/iot/danger-alerts/`.

The device queues a button press, waits for a fresh GPS fix, and keeps retrying
until the backend accepts the alert. If the GPS has date/time, the alert
includes `pressed_at` in UTC. If GPS time is unavailable, the backend uses its
server time. Open Serial Monitor at 115200 baud; the alert sketch prints
`ESP32 danger button starting`, the alert endpoint, and diagnostic lines every
few seconds. Before testing the physical button, wait until diagnostics show
`fix: valid`. If `GPS stream` says `receiving` but `fix` stays `invalid`, move
the GPS module outside or near a window until it has satellite lock.

## VS Code Setup

Recommended: install the PlatformIO extension in VS Code, then open
`iot/esp32_danger_button` as the PlatformIO project. The included
`platformio.ini` targets `nodemcu-32s`.

Build from PowerShell:

```powershell
cd iot\esp32_danger_button
pio run
```

Upload to the ESP32 after connecting it by USB:

```powershell
pio run --target upload
```

If you use Arduino IDE or the Arduino VS Code extension instead, install the
ESP32 board package by Espressif.

The workspace also includes `.vscode/c_cpp_properties.json` with common ESP32,
Arduino IDE, and PlatformIO include paths. If VS Code still shows old include
squiggles after installing the board/library, run **C/C++: Reset IntelliSense
Database** and reload the window.

## Backend API

Set the same key on the backend before running Django:

```powershell
$env:IOT_DEVICE_API_KEY="dev-iot-sos-key"
cd backend
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

Manual test:

```powershell
Invoke-RestMethod `
  -Method Post `
  -Uri http://localhost:8000/api/iot/danger-alerts/ `
  -Headers @{"X-IOT-API-KEY"="dev-iot-sos-key"} `
  -ContentType "application/json" `
  -Body '{"device_id":"esp32-node-001","latitude":-6.7924,"longitude":39.2083,"pressed_at":"2026-06-14T09:20:30Z"}'
```

The alert appears in the authenticated police dashboard through the existing
live WebSocket incident feed.
