import json

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse

from incidents.models import Hotspot, Incident, PatrolAsset, PoliceOfficer


class PoliceAuthenticationTests(TestCase):
    def setUp(self):
        self.password = "safe-test-password"
        self.user = get_user_model().objects.create_user(
            username="police-test",
            password=self.password,
        )
        self.officer = PoliceOfficer.objects.create(
            user=self.user,
            full_name="Officer Asha Nyerere",
            badge_number="TZ-POL-1042",
            rank=PoliceOfficer.Rank.INSPECTOR,
            station="Central Police Station",
            unit="Mobility Response",
            phone_number="+255700000001",
        )

    def test_valid_login_creates_session_for_dashboard_requests(self):
        response = self.client.post(
            reverse("police-login"),
            {"username": self.user.username, "password": self.password},
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["id"], self.user.id)
        self.assertEqual(response.json()["full_name"], self.officer.full_name)
        self.assertEqual(response.json()["badge_number"], self.officer.badge_number)
        self.assertEqual(response.json()["rank_display"], "Inspector")
        self.assertEqual(response.json()["station"], self.officer.station)

        me_response = self.client.get(reverse("police-me"))
        incidents_response = self.client.get(reverse("police-incident-list"))

        self.assertEqual(me_response.status_code, 200)
        self.assertEqual(me_response.json()["id"], self.user.id)
        self.assertEqual(incidents_response.status_code, 200)

    def test_invalid_login_does_not_authenticate_dashboard_requests(self):
        response = self.client.post(
            reverse("police-login"),
            {"username": self.user.username, "password": "wrong-password"},
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 401)
        self.assertEqual(self.client.get(reverse("police-me")).status_code, 403)
        self.assertEqual(
            self.client.get(reverse("police-incident-list")).status_code,
            403,
        )
        self.assertEqual(
            self.client.get(reverse("police-hotspot-list")).status_code,
            403,
        )

    def test_unregistered_django_user_cannot_login_as_police(self):
        user = get_user_model().objects.create_user(
            username="ordinary-user",
            password=self.password,
        )

        response = self.client.post(
            reverse("police-login"),
            {"username": user.username, "password": self.password},
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 401)

    def test_inactive_police_profile_cannot_login(self):
        self.officer.active = False
        self.officer.save(update_fields=["active"])

        response = self.client.post(
            reverse("police-login"),
            {"username": self.user.username, "password": self.password},
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 401)


class PoliceOfficerAdminTests(TestCase):
    def setUp(self):
        self.admin_user = get_user_model().objects.create_superuser(
            username="admin-user",
            email="admin@example.com",
            password="admin-safe-password",
        )
        self.client.force_login(self.admin_user)

    def test_admin_can_register_police_credentials_and_information(self):
        response = self.client.post(
            reverse("admin:incidents_policeofficer_add"),
            {
                "username": "registered-officer",
                "email": "officer@example.com",
                "password1": "registered-safe-password",
                "password2": "registered-safe-password",
                "full_name": "Officer Neema Hassan",
                "badge_number": "TZ-POL-2204",
                "rank": PoliceOfficer.Rank.SERGEANT,
                "station": "University District Station",
                "unit": "Safe Transit Unit",
                "phone_number": "+255700000220",
                "active": "on",
                "_save": "Save",
            },
        )

        self.assertEqual(response.status_code, 302)
        officer = PoliceOfficer.objects.select_related("user").get(
            badge_number="TZ-POL-2204"
        )
        self.assertEqual(officer.user.username, "registered-officer")
        self.assertEqual(officer.full_name, "Officer Neema Hassan")
        self.assertEqual(officer.station, "University District Station")
        self.assertTrue(officer.user.check_password("registered-safe-password"))

        login_response = self.client.post(
            reverse("police-login"),
            {
                "username": "registered-officer",
                "password": "registered-safe-password",
            },
            content_type="application/json",
        )
        self.assertEqual(login_response.status_code, 200)
        self.assertEqual(login_response.json()["badge_number"], "TZ-POL-2204")


class DispatchMapAuthorityTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(
            username="dispatch-map-test",
            password="safe-test-password",
        )
        PoliceOfficer.objects.create(
            user=self.user,
            full_name="Dispatch Officer",
            badge_number="TZ-DISPATCH-1",
            rank=PoliceOfficer.Rank.SERGEANT,
            station="Central Police Station",
        )

    def test_citizen_can_only_read_public_low_and_high_risk_areas(self):
        low = Hotspot.objects.create(
            title="Low risk area",
            center_latitude=-6.8,
            center_longitude=39.2,
            radius_meters=200,
            risk_level=Hotspot.RiskLevel.LOW,
            created_by=self.user,
        )
        high = Hotspot.objects.create(
            title="High risk area",
            center_latitude=-6.81,
            center_longitude=39.21,
            radius_meters=300,
            risk_level=Hotspot.RiskLevel.HIGH,
            created_by=self.user,
        )
        Hotspot.objects.create(
            title="Inactive area",
            center_latitude=-6.82,
            center_longitude=39.22,
            radius_meters=300,
            risk_level=Hotspot.RiskLevel.HIGH,
            active=False,
            created_by=self.user,
        )

        response = self.client.get(reverse("hotspot-list"))

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            {item["id"] for item in response.json()},
            {low.id, high.id},
        )
        self.assertEqual(
            {item["risk_level"] for item in response.json()},
            {"LOW", "HIGH"},
        )
        self.assertEqual(
            self.client.post(
                reverse("hotspot-list"),
                {},
                content_type="application/json",
            ).status_code,
            405,
        )

    def test_citizen_cannot_use_dispatch_map_mutation_endpoints(self):
        hotspot = Hotspot.objects.create(
            title="Protected area",
            center_latitude=-6.8,
            center_longitude=39.2,
            radius_meters=200,
            risk_level=Hotspot.RiskLevel.HIGH,
            created_by=self.user,
        )
        asset = PatrolAsset.objects.create(
            name="Unit 12",
            latitude=-6.8,
            longitude=39.2,
            updated_by=self.user,
        )

        self.assertEqual(
            self.client.post(
                reverse("police-hotspot-list"),
                {},
                content_type="application/json",
            ).status_code,
            403,
        )
        self.assertEqual(
            self.client.patch(
                reverse("police-hotspot-detail", args=[hotspot.id]),
                json.dumps({"risk_level": "LOW"}),
                content_type="application/json",
            ).status_code,
            403,
        )
        self.assertEqual(
            self.client.get(reverse("police-patrol-asset-list")).status_code,
            403,
        )
        self.assertEqual(
            self.client.patch(
                reverse("police-patrol-asset-detail", args=[asset.id]),
                json.dumps({"latitude": -6.9}),
                content_type="application/json",
            ).status_code,
            403,
        )

    def test_dispatch_can_manage_only_low_or_high_risk_areas(self):
        self.client.force_login(self.user)

        create_response = self.client.post(
            reverse("police-hotspot-list"),
            {
                "title": "Dispatch high risk area",
                "center_latitude": -6.8,
                "center_longitude": 39.2,
                "radius_meters": 250,
                "risk_level": "HIGH",
                "active": True,
            },
            content_type="application/json",
        )
        invalid_response = self.client.post(
            reverse("police-hotspot-list"),
            {
                "title": "Invalid critical area",
                "center_latitude": -6.8,
                "center_longitude": 39.2,
                "radius_meters": 250,
                "risk_level": "CRITICAL",
                "active": True,
            },
            content_type="application/json",
        )
        hotspot_id = create_response.json()["id"]
        update_response = self.client.patch(
            reverse("police-hotspot-detail", args=[hotspot_id]),
            json.dumps({"risk_level": "LOW"}),
            content_type="application/json",
        )

        self.assertEqual(create_response.status_code, 201)
        self.assertEqual(invalid_response.status_code, 400)
        self.assertEqual(update_response.status_code, 200)
        self.assertEqual(update_response.json()["risk_level"], "LOW")

    def test_dispatch_can_create_move_and_deactivate_patrol_assets(self):
        self.client.force_login(self.user)

        create_response = self.client.post(
            reverse("police-patrol-asset-list"),
            {
                "name": "Patrol Unit Alpha",
                "latitude": -6.8,
                "longitude": 39.2,
                "status": "AVAILABLE",
                "active": True,
            },
            content_type="application/json",
        )
        asset_id = create_response.json()["id"]
        move_response = self.client.patch(
            reverse("police-patrol-asset-detail", args=[asset_id]),
            json.dumps(
                {
                    "latitude": -6.9,
                    "longitude": 39.3,
                    "status": "DEPLOYED",
                }
            ),
            content_type="application/json",
        )
        deactivate_response = self.client.delete(
            reverse("police-patrol-asset-detail", args=[asset_id])
        )

        self.assertEqual(create_response.status_code, 201)
        self.assertEqual(move_response.status_code, 200)
        self.assertEqual(move_response.json()["status"], "DEPLOYED")
        self.assertEqual(deactivate_response.status_code, 204)
        self.assertFalse(PatrolAsset.objects.get(pk=asset_id).active)

    def test_citizen_can_track_dispatch_incident_status_updates(self):
        incident = Incident.objects.create(
            anonymous_token="citizen-status-token",
            latitude=-6.8,
            longitude=39.2,
            assigned_unit="Sensitive unit",
            police_notes="Sensitive police notes",
        )
        self.client.force_login(self.user)

        for expected_status in [
            Incident.Status.ACKNOWLEDGED,
            Incident.Status.DISPATCHED,
            Incident.Status.RESOLVED,
        ]:
            update_response = self.client.patch(
                reverse("police-incident-detail", args=[incident.id]),
                json.dumps({"status": expected_status}),
                content_type="application/json",
            )
            public_response = self.client.get(
                reverse("incident-status", args=[incident.anonymous_token])
            )

            self.assertEqual(update_response.status_code, 200)
            self.assertEqual(public_response.status_code, 200)
            self.assertEqual(public_response.json()[0]["status"], expected_status)
            self.assertNotIn("assigned_unit", public_response.json()[0])
            self.assertNotIn("police_notes", public_response.json()[0])
            self.assertNotIn("solved_by_name", public_response.json()[0])
            self.assertNotIn("solved_by_station", public_response.json()[0])

    def test_central_police_can_see_resolution_audit_details(self):
        field_user = get_user_model().objects.create_user(
            username="field-resolver",
            password="safe-test-password",
        )
        field_officer = PoliceOfficer.objects.create(
            user=field_user,
            full_name="Officer Joseph Field",
            badge_number="TZ-FIELD-22",
            rank=PoliceOfficer.Rank.SERGEANT,
            station="North District Station",
        )
        incident = Incident.objects.create(
            anonymous_token="resolution-audit-token",
            latitude=-6.8,
            longitude=39.2,
        )

        self.client.force_login(field_user)
        field_response = self.client.patch(
            reverse("police-incident-detail", args=[incident.id]),
            json.dumps({"status": Incident.Status.RESOLVED}),
            content_type="application/json",
        )

        incident.refresh_from_db()
        self.assertEqual(field_response.status_code, 200)
        self.assertNotIn("solved_by_name", field_response.json())
        self.assertEqual(incident.solved_by, field_user)
        self.assertEqual(incident.solved_by_name, field_officer.full_name)
        self.assertEqual(incident.solved_by_badge_number, field_officer.badge_number)
        self.assertEqual(incident.solved_by_station, field_officer.station)
        self.assertIsNotNone(incident.solved_at)

        self.client.force_login(self.user)
        central_response = self.client.get(reverse("police-incident-list"))
        payload = central_response.json()[0]

        self.assertEqual(central_response.status_code, 200)
        self.assertEqual(payload["id"], str(incident.id))
        self.assertEqual(payload["solved_by_name"], field_officer.full_name)
        self.assertEqual(payload["solved_by_badge_number"], field_officer.badge_number)
        self.assertEqual(payload["solved_by_station"], field_officer.station)
        self.assertIsNotNone(payload["solved_at"])

    def test_non_central_police_cannot_see_resolution_audit_details(self):
        incident = Incident.objects.create(
            anonymous_token="hidden-resolution-audit-token",
            latitude=-6.8,
            longitude=39.2,
            status=Incident.Status.RESOLVED,
            solved_by=self.user,
            solved_by_name="Dispatch Officer",
            solved_by_badge_number="TZ-DISPATCH-1",
            solved_by_station="Central Police Station",
        )
        field_user = get_user_model().objects.create_user(
            username="field-viewer",
            password="safe-test-password",
        )
        PoliceOfficer.objects.create(
            user=field_user,
            full_name="Officer Field Viewer",
            badge_number="TZ-FIELD-23",
            rank=PoliceOfficer.Rank.SERGEANT,
            station="North District Station",
        )

        self.client.force_login(field_user)
        response = self.client.get(reverse("police-incident-detail", args=[incident.id]))

        self.assertEqual(response.status_code, 200)
        self.assertNotIn("solved_by_name", response.json())
        self.assertNotIn("solved_by_badge_number", response.json())
        self.assertNotIn("solved_by_station", response.json())
        self.assertNotIn("solved_at", response.json())
