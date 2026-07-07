from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework import status
from rest_framework.test import APIClient

from .models import Hotspot, IncidentReport, PoliceOfficer


class PoliceDashboardIntegrationTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = get_user_model().objects.create_user(
            username="officer",
            password="test-password-123",
            email="officer@example.com",
        )
        self.profile = PoliceOfficer.objects.create(
            user=self.user,
            full_name="Officer Asha Field",
            badge_number="TZ-001",
            rank=PoliceOfficer.Rank.INSPECTOR,
            station="Central Police Station",
            unit="Central Police Dispatch",
            active=True,
        )

    def test_mobile_report_flows_to_police_dashboard_and_status_updates_return(self):
        create_response = self.client.post(
            "/api/incidents/",
            {
                "anonymous_token": "mobile-device-token",
                "category": "harassment",
                "risk_level": "critical",
                "title": "Harassment",
                "description": "Unsafe approach near the station.",
                "latitude": "-6.816000",
                "longitude": "39.280000",
            },
            format="json",
        )

        self.assertEqual(create_response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(create_response.data["category"], "HARASSMENT")
        self.assertEqual(create_response.data["status"], "REPORTED")
        self.assertEqual(create_response.data["anonymous_token"], "mobile-device-token")

        incident_id = create_response.data["id"]
        status_response = self.client.get("/api/incidents/status/mobile-device-token/")
        self.assertEqual(status_response.status_code, status.HTTP_200_OK)
        self.assertEqual(status_response.data[0]["status"], "REPORTED")

        login_response = self.client.post(
            "/api/police/login/",
            {"username": "officer", "password": "test-password-123"},
            format="json",
        )
        self.assertEqual(login_response.status_code, status.HTTP_200_OK)
        self.assertEqual(login_response.data["badge_number"], "TZ-001")

        police_list = self.client.get("/api/police/incidents/")
        self.assertEqual(police_list.status_code, status.HTTP_200_OK)
        self.assertEqual(police_list.data[0]["id"], incident_id)

        patch_response = self.client.patch(
            f"/api/police/incidents/{incident_id}/",
            {"status": "DISPATCHED"},
            format="json",
        )
        self.assertEqual(patch_response.status_code, status.HTTP_200_OK)
        self.assertEqual(patch_response.data["status"], "DISPATCHED")

        updated_status = self.client.get("/api/incidents/status/mobile-device-token/")
        self.assertEqual(updated_status.data[0]["status"], "DISPATCHED")

    def test_hotspots_support_dashboard_list_and_mobile_cluster_modes(self):
        Hotspot.objects.create(
            title="Market gate",
            center_latitude=-6.816,
            center_longitude=39.28,
            radius_meters=250,
            risk_level=Hotspot.RiskLevel.HIGH,
        )
        IncidentReport.objects.create(
            anonymous_token="cluster-token",
            category=IncidentReport.Category.HARASSMENT,
            risk_level=IncidentReport.RiskLevel.HIGH,
            severity=IncidentReport.DashboardSeverity.HIGH,
            title="Harassment",
            latitude="-6.816000",
            longitude="39.280000",
        )

        dashboard_response = self.client.get("/api/hotspots/")
        self.assertEqual(dashboard_response.status_code, status.HTTP_200_OK)
        self.assertEqual(dashboard_response.data[0]["title"], "Market gate")

        mobile_response = self.client.get(
            "/api/hotspots/",
            {"latitude": "-6.816000", "longitude": "39.280000", "radius_km": "3"},
        )
        self.assertEqual(mobile_response.status_code, status.HTTP_200_OK)
        self.assertIn("hotspots", mobile_response.data)
        self.assertEqual(mobile_response.data["hotspots"][0]["risk_level"], "high")
