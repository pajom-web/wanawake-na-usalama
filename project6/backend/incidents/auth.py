from rest_framework.authentication import SessionAuthentication


class CsrfExemptSessionAuthentication(SessionAuthentication):
    """Allow same-origin/session police APIs without a separate CSRF bootstrap."""

    def enforce_csrf(self, request):
        return None
