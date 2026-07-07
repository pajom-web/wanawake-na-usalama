import json

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse


class MobileUserAuthenticationTests(TestCase):
    def test_registered_password_is_hashed_and_required_for_login(self):
        password = "Exact-Mobile-Password-482!"
        register_response = self.client.post(
            reverse("mobile-register"),
            data=json.dumps(
                {
                    "username": "mobile-user",
                    "email": "mobile@example.com",
                    "password": password,
                    "display_name": "Mobile User",
                }
            ),
            content_type="application/json",
        )

        self.assertEqual(register_response.status_code, 201)
        user = get_user_model().objects.get(username="mobile-user")
        self.assertNotEqual(user.password, password)
        self.assertTrue(user.check_password(password))

        wrong_password_response = self.client.post(
            reverse("mobile-login"),
            data=json.dumps(
                {
                    "username": "mobile-user",
                    "password": "exact-mobile-password-482!",
                }
            ),
            content_type="application/json",
        )
        self.assertEqual(wrong_password_response.status_code, 401)

        correct_password_response = self.client.post(
            reverse("mobile-login"),
            data=json.dumps(
                {"username": "mobile-user", "password": password}
            ),
            content_type="application/json",
        )
        self.assertEqual(correct_password_response.status_code, 200)
        self.assertEqual(
            correct_password_response.json()["token"],
            register_response.json()["token"],
        )

    def test_token_can_restore_session_and_is_revoked_on_logout(self):
        register_response = self.client.post(
            reverse("mobile-register"),
            data=json.dumps(
                {
                    "username": "restore-user",
                    "email": "restore@example.com",
                    "password": "Restore-Mobile-Password-917!",
                    "display_name": "Restore User",
                }
            ),
            content_type="application/json",
        )
        token = register_response.json()["token"]
        authorization = {"HTTP_AUTHORIZATION": f"Token {token}"}

        me_response = self.client.get(reverse("mobile-me"), **authorization)
        self.assertEqual(me_response.status_code, 200)
        self.assertEqual(me_response.json()["display_name"], "Restore User")

        logout_response = self.client.post(
            reverse("mobile-logout"),
            data="{}",
            content_type="application/json",
            **authorization,
        )
        self.assertEqual(logout_response.status_code, 200)
        self.assertEqual(
            self.client.get(reverse("mobile-me"), **authorization).status_code,
            401,
        )
