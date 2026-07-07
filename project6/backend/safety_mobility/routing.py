from django.urls import path

from incidents.consumers import CitizenHotspotConsumer, PoliceAlertConsumer

websocket_urlpatterns = [
    path("ws/police/alerts/", PoliceAlertConsumer.as_asgi()),
    path("ws/citizen/hotspots/", CitizenHotspotConsumer.as_asgi()),
]
