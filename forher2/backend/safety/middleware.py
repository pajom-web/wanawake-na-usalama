from django.conf import settings
from django.http import HttpResponse


class LocalCorsMiddleware:
    """Small local CORS helper for the self-contained dev stack.

    Native mobile clients do not need CORS, but Flutter web previews do. This
    keeps local testing portable without adding another backend dependency.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.method == "OPTIONS":
            response = HttpResponse(status=204)
        else:
            response = self.get_response(request)

        origin = request.headers.get("Origin")
        if origin and self._origin_allowed(origin):
            response["Access-Control-Allow-Origin"] = origin
            response["Access-Control-Allow-Credentials"] = "true"
            response["Access-Control-Allow-Headers"] = (
                "authorization, content-type, x-requested-with"
            )
            response["Access-Control-Allow-Methods"] = (
                "GET, POST, PUT, PATCH, DELETE, OPTIONS"
            )
        return response

    def _origin_allowed(self, origin: str) -> bool:
        configured = getattr(settings, "CORS_ALLOWED_ORIGINS", [])
        if origin in configured:
            return True
        if not settings.DEBUG:
            return False
        return origin.startswith("http://127.0.0.1:") or origin.startswith(
            "http://localhost:"
        )
