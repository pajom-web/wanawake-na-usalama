import json
from datetime import datetime, timezone as datetime_timezone

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.urls import reverse
from django.utils import timezone

from incidents.models import Incident, PoliceOfficer


@override_settings(IOT_DEVICE_API_KEY="test-device-key")
class IotDangerAlertTests(TestCase):
    def setUp(self):
        self.police_user = get_user_model().objects.create_user(
            username="iot-dispatch",
            password="safe-test-password",
        )
        PoliceOfficer.objects.create(
            user=self.police_user,
            full_name="IoT Dispatch Officer",
            badge_number="TZ-IOT-1",
            rank=PoliceOfficer.Rank.SERGEANT,
            station="Central Police Station",
        )

    def test_iot_button_alert_creates_police_dashboard_incident(self):
        response = self._post_iot_alert(
            {
                "device_id": "esp32-node-001",
                "latitude": -6.7924,
                "longitude": 39.2083,
                "pressed_at": "2026-06-14T09:20:30Z",
            }
        )

        self.assertEqual(response.status_code, 201)
        payload = response.json()
        self.assertEqual(payload["source"], Incident.Source.IOT_BUTTON)
        self.assertEqual(payload["device_id"], "esp32-node-001")
        self.assertEqual(payload["latitude"], -6.7924)
        self.assertEqual(payload["longitude"], 39.2083)

        incident = Incident.objects.get(pk=payload["id"])
        self.assertEqual(incident.category, Incident.Category.SOS)
        self.assertEqual(incident.severity, Incident.Severity.CRITICAL)
        self.assertEqual(incident.status, Incident.Status.REPORTED)
        self.assertEqual(incident.source, Incident.Source.IOT_BUTTON)
        self.assertEqual(incident.device_id, "esp32-node-001")
        self.assertEqual(
            incident.pressed_at,
            datetime(2026, 6, 14, 9, 20, 30, tzinfo=datetime_timezone.utc),
        )

        self.client.force_login(self.police_user)
        police_response = self.client.get(reverse("police-incident-list"))

        self.assertEqual(police_response.status_code, 200)
        self.assertEqual(police_response.json()[0]["id"], payload["id"])
        self.assertEqual(police_response.json()[0]["source"], "IOT_BUTTON")
        self.assertEqual(police_response.json()[0]["device_id"], "esp32-node-001")

    def test_iot_alert_rejects_missing_api_key(self):
        response = self.client.post(
            reverse("iot-danger-alert"),
            data=json.dumps(
                {
                    "device_id": "esp32-node-001",
                    "latitude": -6.7924,
                    "longitude": 39.2083,
                }
            ),
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 403)
        self.assertEqual(Incident.objects.count(), 0)

    def test_iot_alert_uses_server_time_when_pressed_time_missing(self):
        before = timezone.now()
        response = self._post_iot_alert(
            {
                "device_id": "esp32-node-002",
                "latitude": -6.8,
                "longitude": 39.2,
            }
        )
        after = timezone.now()

        self.assertEqual(response.status_code, 201)
        incident = Incident.objects.get(pk=response.json()["id"])
        self.assertIsNotNone(incident.pressed_at)
        self.assertGreaterEqual(incident.pressed_at, before)
        self.assertLessEqual(incident.pressed_at, after)

    def test_iot_alert_rejects_invalid_gps_coordinates(self):
        response = self._post_iot_alert(
            {
                "device_id": "esp32-node-001",
                "latitude": 123.0,
                "longitude": 39.2083,
            }
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn("latitude", response.json())
        self.assertEqual(Incident.objects.count(), 0)

    def _post_iot_alert(self, payload):
        return self.client.post(
            reverse("iot-danger-alert"),
            data=json.dumps(payload),
            content_type="application/json",
            HTTP_X_IOT_API_KEY="test-device-key",
        )
