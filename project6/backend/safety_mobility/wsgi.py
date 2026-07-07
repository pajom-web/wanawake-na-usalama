"""WSGI entrypoint for Django management compatibility."""
import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "safety_mobility.settings")

application = get_wsgi_application()
