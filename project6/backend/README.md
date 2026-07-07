# Safety Mobility Backend

Django backend for anonymous citizen SOS reports, ESP32 danger-button alerts,
and authenticated dispatch operations.

## Setup

```powershell
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
python manage.py migrate
python manage.py createsuperuser
python manage.py runserver 8000
```

For IoT devices, set a shared API key before starting the backend:

```powershell
$env:IOT_DEVICE_API_KEY="dev-iot-sos-key"
```

## Register Police Officers

1. Sign in to `http://localhost:8000/admin/` with a Django superuser.
2. Open **Police officers** and choose **Add police officer**.
3. Enter the officer's Flutter login username and password together with their
   full name, badge number, rank, station, unit, phone number, and active status.

The password is hashed by Django. Only active officers registered here can use
the police login form or access police APIs and WebSockets.

## IoT Danger Button

ESP32 devices post GPS-backed alerts to:

```text
POST /api/iot/danger-alerts/
X-IOT-API-KEY: dev-iot-sos-key
```

Payload:

```json
{
  "device_id": "esp32-node-001",
  "latitude": -6.7924,
  "longitude": 39.2083,
  "pressed_at": "2026-06-14T09:20:30Z"
}
```

`pressed_at` is optional. When it is missing, the server records the current
server time. Accepted alerts are stored as `IOT_BUTTON` incidents and broadcast
to the police dashboard WebSocket feed.

## Map Authority

- Citizens can only read active low/high risk areas from `/api/hotspots/`.
- Authenticated dispatch users can create, update, and deactivate low/high risk
  areas and patrol assets.
- Patrol assets are never included in the public citizen feed.

## Realtime Channels

The project uses Django Channels with `InMemoryChannelLayer`, so it needs no
Redis. Use a single backend process in local development.

WebSocket routes:

- `/ws/police/alerts/` authenticated police stream
- `/ws/citizen/hotspots/` public hotspot update stream

## Twilio Worker

The app starts a native daemon thread in `IncidentsConfig.ready()`. SOS creation
enqueues a voice-call job. With `TWILIO_ENABLED=False`, jobs are logged as stubs.
