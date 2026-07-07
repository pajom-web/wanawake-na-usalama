from django.conf import settings
from django.http import HttpResponse


class SimpleCorsMiddleware:
    """Small CORS layer to keep the stack lightweight and dependency-free."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.method == "OPTIONS":
            response = HttpResponse()
        else:
            response = self.get_response(request)

        origin = request.headers.get("Origin")
        if origin and origin in settings.CORS_ALLOWED_ORIGINS:
            response["Access-Control-Allow-Origin"] = origin
            response["Access-Control-Allow-Credentials"] = "true"
            response["Access-Control-Allow-Headers"] = (
                "content-type, authorization, x-csrftoken"
            )
            response["Access-Control-Allow-Methods"] = (
                "GET, POST, PATCH, PUT, DELETE, OPTIONS"
            )
        return response
