import json

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from incidents.models import Incident, PoliceOfficer


class MobileDashboardSyncTests(TestCase):
    def setUp(self):
        self.password = "safe-test-password"
        self.officer_user = get_user_model().objects.create_user(
            username="mobile-sync-dispatch",
            password=self.password,
        )
        PoliceOfficer.objects.create(
            user=self.officer_user,
            full_name="Officer Mobile Sync",
            badge_number="TZ-MOBILE-SYNC-1",
            rank=PoliceOfficer.Rank.SERGEANT,
            station="Central Police Station",
        )

    def test_mobile_report_appears_on_dashboard_and_receives_status_updates(self):
        anonymous_token = "mobile-device-status-token"
        create_response = self.client.post(
            reverse("incident-create"),
            data=json.dumps(
                {
                    "anonymous_token": anonymous_token,
                    "category": "HARASSMENT",
                    "severity": "HIGH",
                    "description": "Unsafe approach near the bus stop.",
                    "latitude": "-6.816000",
                    "longitude": "39.280000",
                }
            ),
            content_type="application/json",
        )

        self.assertEqual(create_response.status_code, 201)
        incident_id = create_response.json()["id"]
        self.assertEqual(create_response.json()["status"], Incident.Status.REPORTED)
        self.assertEqual(create_response.json()["anonymous_token"], anonymous_token)

        login_response = self.client.post(
            reverse("police-login"),
            data=json.dumps(
                {
                    "username": self.officer_user.username,
                    "password": self.password,
                }
            ),
            content_type="application/json",
        )
        self.assertEqual(login_response.status_code, 200)

        dashboard_response = self.client.get(reverse("police-incident-list"))
        self.assertEqual(dashboard_response.status_code, 200)
        self.assertEqual(dashboard_response.json()[0]["id"], incident_id)
        self.assertEqual(dashboard_response.json()[0]["source"], "CITIZEN_APP")

        update_response = self.client.patch(
            reverse("police-incident-detail", args=[incident_id]),
            data=json.dumps(
                {
                    "status": Incident.Status.DISPATCHED,
                    "assigned_unit": "Patrol Unit 4",
                    "police_notes": "Unit is on its way.",
                }
            ),
            content_type="application/json",
        )
        self.assertEqual(update_response.status_code, 200)
        self.assertEqual(update_response.json()["status"], Incident.Status.DISPATCHED)

        mobile_status_response = self.client.get(
            reverse("incident-status", args=[anonymous_token])
        )
        self.assertEqual(mobile_status_response.status_code, 200)
        mobile_incident = mobile_status_response.json()[0]
        self.assertEqual(mobile_incident["id"], incident_id)
        self.assertEqual(mobile_incident["status"], Incident.Status.DISPATCHED)
        self.assertNotIn("assigned_unit", mobile_incident)
        self.assertNotIn("police_notes", mobile_incident)

