from django.urls import path

from .consumers import CitizenHotspotConsumer, LiveLocationConsumer, PoliceAlertConsumer

websocket_urlpatterns = [
    path("ws/live-location/", LiveLocationConsumer.as_asgi()),
    path("ws/police/alerts/", PoliceAlertConsumer.as_asgi()),
    path("ws/citizen/hotspots/", CitizenHotspotConsumer.as_asgi()),
]
