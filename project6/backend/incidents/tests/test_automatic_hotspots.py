import json

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from incidents.models import Hotspot, PoliceOfficer


class AutomaticHotspotTests(TestCase):
    latitude = -6.8161
    longitude = 39.2801

    def setUp(self):
        self.police_user = get_user_model().objects.create_user(
            username="automatic-hotspot-officer",
            password="safe-test-password",
        )
        PoliceOfficer.objects.create(
            user=self.police_user,
            full_name="Automatic Hotspot Officer",
            badge_number="TZ-AUTO-HOTSPOT-1",
            rank=PoliceOfficer.Rank.SERGEANT,
            station="Central Police Station",
        )

    def _report_incident(self, number: int):
        return self.client.post(
            reverse("incident-create"),
            data=json.dumps(
                {
                    "anonymous_token": f"automatic-location-{number}",
                    "category": "HARASSMENT",
                    "severity": "HIGH",
                    "latitude": self.latitude,
                    "longitude": self.longitude,
                }
            ),
            content_type="application/json",
        )

    def test_six_reports_create_low_risk_zone_and_eleven_upgrade_it_to_high(self):
        for number in range(1, 6):
            self.assertEqual(self._report_incident(number).status_code, 201)
        self.assertFalse(Hotspot.objects.exists())

        self.assertEqual(self._report_incident(6).status_code, 201)
        hotspot = Hotspot.objects.get()
        self.assertEqual(hotspot.source, Hotspot.Source.AUTOMATIC)
        self.assertEqual(hotspot.incident_count, 6)
        self.assertEqual(hotspot.risk_level, Hotspot.RiskLevel.LOW)

        for number in range(7, 11):
            self.assertEqual(self._report_incident(number).status_code, 201)
        hotspot.refresh_from_db()
        self.assertEqual(hotspot.incident_count, 10)
        self.assertEqual(hotspot.risk_level, Hotspot.RiskLevel.LOW)

        self.assertEqual(self._report_incident(11).status_code, 201)
        hotspot.refresh_from_db()
        self.assertEqual(hotspot.incident_count, 11)
        self.assertEqual(hotspot.risk_level, Hotspot.RiskLevel.HIGH)

        public_response = self.client.get(reverse("hotspot-list"))
        self.assertEqual(public_response.status_code, 200)
        self.assertEqual(public_response.json()[0]["source"], "AUTOMATIC")
        self.assertEqual(public_response.json()[0]["incident_count"], 11)
        self.assertEqual(public_response.json()[0]["risk_level"], "HIGH")

    def test_police_can_delete_automatic_zone_without_it_reappearing(self):
        for number in range(1, 7):
            self.assertEqual(self._report_incident(number).status_code, 201)
        hotspot = Hotspot.objects.get()

        self.client.force_login(self.police_user)
        response = self.client.delete(
            reverse("police-hotspot-detail", args=[hotspot.id])
        )
        self.assertEqual(response.status_code, 204)

        hotspot.refresh_from_db()
        self.assertFalse(hotspot.active)

        self.assertEqual(self._report_incident(7).status_code, 201)
        hotspot.refresh_from_db()
        self.assertFalse(hotspot.active)
        self.assertEqual(self.client.get(reverse("hotspot-list")).json(), [])

    def test_police_created_zone_is_marked_as_manual_and_can_be_deleted(self):
        self.client.force_login(self.police_user)
        create_response = self.client.post(
            reverse("police-hotspot-list"),
            data=json.dumps(
                {
                    "title": "Officer identified area",
                    "center_latitude": self.latitude,
                    "center_longitude": self.longitude,
                    "radius_meters": 200,
                    "risk_level": "HIGH",
                    "active": True,
                }
            ),
            content_type="application/json",
        )
        self.assertEqual(create_response.status_code, 201)
        self.assertEqual(create_response.json()["source"], "MANUAL")
        self.assertEqual(create_response.json()["incident_count"], 0)

        delete_response = self.client.delete(
            reverse(
                "police-hotspot-detail",
                args=[create_response.json()["id"]],
            )
        )
        self.assertEqual(delete_response.status_code, 204)
        self.assertFalse(
            Hotspot.objects.get(pk=create_response.json()["id"]).active
        )
