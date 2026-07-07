# Real-Time Gender-Sensitive Safety Mobility System

Lightweight local development implementation with the single shared Django
Channels backend used by both the SafeRoute mobile app in `../forher2/mobile`
and this police/citizen Flutter Web UI. It provides SQLite storage, anonymous
citizen reporting, authenticated dispatch operations, live WebSocket alerting,
dispatch-managed risk areas and patrol assets. ESP32 danger-button devices post
GPS-backed SOS alerts into the same police dashboard feed.

## Architecture

- Backend: Django, Django REST Framework, Django Channels, SQLite
- Realtime: in-memory Channels layer, no Redis
- Background work: native Python thread queue, no Celery
- Frontend: Flutter Web, Riverpod, flutter_map with OpenStreetMap tiles
- Emergency calls: Twilio integration stub, enabled by environment variables
- IoT: ESP32 NodeMCU-32 + GPS module + button posting keyed JSON alerts
- Environment: native local development, no Docker

## Run Backend

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver 8000
```

If your Django runserver does not expose WebSockets, run the ASGI app directly:

```powershell
daphne -b 127.0.0.1 -p 8000 safety_mobility.asgi:application
```

Copy `backend/.env.example` into your shell environment if you want to enable
Twilio. With `TWILIO_ENABLED=False`, the worker logs emergency-call jobs only.
Set `IOT_DEVICE_API_KEY` to the same value used in the ESP32 sketch before
running the backend.

## Run Frontend

```powershell
cd frontend
flutter pub get
flutter run -d chrome --web-port 3000 `
  --dart-define=API_BASE_URL=http://localhost:8000 `
  --dart-define=WS_BASE_URL=ws://localhost:8000
```

## Run Mobile Against The Same Backend

Keep the backend above running on port 8000, then start the mobile app without
starting another Django service:

```powershell
cd ..\forher2\mobile
flutter run `
  --dart-define=API_BASE_URL=http://127.0.0.1:8000/api `
  --dart-define=WS_BASE_URL=ws://127.0.0.1:8000
```

Mobile reports are created in this backend's `db.sqlite3`, appear in the police
incident queue, and are tracked by anonymous token. The mobile incident history
polls every 15 seconds so police status changes are shown automatically.

The first screen is the anonymous citizen portal. To register police login
credentials, sign in at `http://localhost:8000/admin/` with a Django
superuser, open **Police officers**, and add the officer's username, password,
badge, rank, station, unit, and contact information. Only active registered
police officers can sign in through the Flutter Dispatch tab.

The Flutter top bar includes:

- A language menu for English or Swahili
- An appearance menu for dark or light theme

Both choices are stored in the browser and restored on the next visit.

## Key Backend Routes

- `POST /api/incidents/` anonymous citizen SOS report
- `POST /api/iot/danger-alerts/` ESP32 danger-button GPS alert
- `GET /api/incidents/status/<anonymous_token>/` citizen report tracking
- `GET /api/hotspots/` public read-only active low/high risk areas
- `POST /api/police/login/` police session login
- `POST /api/police/logout/` police session logout
- `GET /api/police/incidents/` police incident feed
- `PATCH /api/police/incidents/<id>/` police status update
- `GET|POST /api/police/hotspots/` police hotspot management
- `PATCH|DELETE /api/police/hotspots/<id>/` update/deactivate hotspot
- `GET|POST /api/police/patrol-assets/` dispatch patrol-asset management
- `PATCH|DELETE /api/police/patrol-assets/<id>/` move/update/deactivate patrol asset
- `ws://localhost:8000/ws/police/alerts/` authenticated live police stream
- `ws://localhost:8000/ws/citizen/hotspots/` public hotspot update stream

## Notes

- Coordinates are stored as plain `FloatField` values for SQLite simplicity.
- Citizen identity is a browser local storage token, not a user account.
- Police APIs and police WebSockets require a valid Django session cookie.
- Citizens have a read-only, pan-and-zoom map containing dispatch-published
  low/high risk areas.
- Citizens can track whether their reports are acknowledged, dispatched, or
  resolved without seeing private police notes.
- Dispatch is the only web role allowed to change risk areas or patrol assets.
- IoT devices send `device_id`, `latitude`, `longitude`, and optional
  `pressed_at` with the `X-IOT-API-KEY` header. Police see the alert source,
  press time, and location live on the dashboard.
