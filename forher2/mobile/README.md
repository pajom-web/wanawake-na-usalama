# SafeRoute Mobile

Flutter client for the gender-sensitive safety app. The app uses Riverpod,
`flutter_map`, anonymous report tracking, the shared `project6/backend` REST
API, and the public hotspot WebSocket channel. Reports submitted here appear in
the police dashboard, and incident status is refreshed automatically every 15
seconds from that same backend.

## Local Backend

```powershell
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api --dart-define=WS_BASE_URL=ws://127.0.0.1:8000
```

For Android emulators, use `10.0.2.2` instead of `127.0.0.1`.
For a physical phone, use your computer's LAN IP address for both values.
