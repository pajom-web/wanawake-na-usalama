import json

from django.contrib import admin
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from rest_framework.authtoken.models import Token

from incidents.models import PoliceOfficer, SafetyTip


class SafetyTipPublishingTests(TestCase):
    def setUp(self):
        user_model = get_user_model()
        self.central_user = user_model.objects.create_user(
            username="central-tips",
            password="safe-test-password",
        )
        PoliceOfficer.objects.create(
            user=self.central_user,
            full_name="Central Publisher",
            badge_number="TZ-CENTRAL-TIPS",
            rank=PoliceOfficer.Rank.INSPECTOR,
            station="Central Police Station",
        )
        self.district_user = user_model.objects.create_user(
            username="district-tips",
            password="safe-test-password",
        )
        PoliceOfficer.objects.create(
            user=self.district_user,
            full_name="District Officer",
            badge_number="TZ-DISTRICT-TIPS",
            rank=PoliceOfficer.Rank.SERGEANT,
            station="North District Station",
        )
        self.mobile_user = user_model.objects.create_user(
            username="mobile-tips",
            password="safe-test-password",
        )
        self.mobile_token = Token.objects.create(user=self.mobile_user)

    def mobile_get(self):
        return self.client.get(
            reverse("safety-tip-list"),
            HTTP_AUTHORIZATION=f"Token {self.mobile_token.key}",
        )

    def test_mobile_receives_only_active_tips_in_display_order(self):
        second = SafetyTip.objects.create(
            title="Second tip",
            body="Second body",
            display_order=2,
        )
        first = SafetyTip.objects.create(
            title="First tip",
            body="First body",
            display_order=1,
        )
        SafetyTip.objects.create(
            title="Hidden tip",
            body="Hidden body",
            display_order=0,
            is_active=False,
        )

        response = self.mobile_get()

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            [item["id"] for item in response.json()],
            [first.id, second.id],
        )
        self.assertEqual(self.client.get(reverse("safety-tip-list")).status_code, 401)

    def test_central_police_can_create_update_and_deactivate_mobile_tips(self):
        self.client.force_login(self.central_user)
        create_response = self.client.post(
            reverse("police-safety-tip-list"),
            {
                "title": "Travel together",
                "body": "Use well-lit routes after dark.",
                "category": "Night travel",
                "display_order": 3,
                "is_active": True,
            },
            content_type="application/json",
        )
        tip_id = create_response.json()["id"]
        update_response = self.client.patch(
            reverse("police-safety-tip-detail", args=[tip_id]),
            json.dumps({"body": "Use busy, well-lit routes after dark."}),
            content_type="application/json",
        )

        self.assertEqual(create_response.status_code, 201)
        self.assertEqual(update_response.status_code, 200)
        self.assertEqual(update_response.json()["body"], "Use busy, well-lit routes after dark.")
        tip = SafetyTip.objects.get(pk=tip_id)
        self.assertEqual(tip.updated_by, self.central_user)

        self.client.logout()
        mobile_response = self.mobile_get()
        self.assertEqual(mobile_response.json()[0]["body"], update_response.json()["body"])

        self.client.force_login(self.central_user)
        delete_response = self.client.delete(
            reverse("police-safety-tip-detail", args=[tip_id])
        )
        self.assertEqual(delete_response.status_code, 204)
        self.client.logout()
        self.assertEqual(self.mobile_get().json(), [])

    def test_non_central_police_cannot_manage_safety_tips(self):
        self.client.force_login(self.district_user)

        response = self.client.post(
            reverse("police-safety-tip-list"),
            {"title": "Blocked", "body": "Not authorized"},
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 403)
        self.assertFalse(SafetyTip.objects.exists())

    def test_safety_tips_are_registered_in_django_admin(self):
        self.assertTrue(admin.site.is_registered(SafetyTip))
