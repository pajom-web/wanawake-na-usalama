# Safety Mobility Flutter Web

Flutter Web interface for the safety mobility system.

- Citizen portal: anonymous SOS, automatically refreshed report-status tracking,
  and a read-only pan-and-zoom low/high risk-area map
- Police dashboard: session login, live alert feed, incident status workflow,
  and exclusive map management for low/high risk areas and patrol assets
- Localization: English and Swahili selectable from the top bar
- Appearance: persistent dark and light tactical themes

Run locally:

```powershell
flutter pub get
flutter run -d chrome --web-port 3000 `
  --dart-define=API_BASE_URL=http://localhost:8000 `
  --dart-define=WS_BASE_URL=ws://localhost:8000
```
