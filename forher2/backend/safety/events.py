from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

from .serializers import (
    DashboardIncidentSerializer,
    HotspotSerializer,
    PatrolAssetSerializer,
    PublicHotspotSerializer,
)


def broadcast_incident_created(incident) -> None:
    _group_send(
        "police_alerts",
        {
            "type": "broadcast.incident",
            "event": "incident.created",
            "incident": DashboardIncidentSerializer(incident).data,
        },
    )


def broadcast_incident_updated(incident) -> None:
    _group_send(
        "police_alerts",
        {
            "type": "broadcast.incident",
            "event": "incident.updated",
            "incident": DashboardIncidentSerializer(incident).data,
        },
    )


def broadcast_hotspot_changed(hotspot, event: str) -> None:
    _group_send(
        "citizen_hotspots",
        {
            "type": "broadcast.hotspot",
            "event": event,
            "hotspot": PublicHotspotSerializer(hotspot).data,
        },
    )
    _group_send(
        "police_alerts",
        {
            "type": "broadcast.hotspot",
            "event": event,
            "hotspot": HotspotSerializer(hotspot).data,
        },
    )


def broadcast_patrol_asset_changed(asset, event: str) -> None:
    _group_send(
        "police_alerts",
        {
            "type": "broadcast.patrol_asset",
            "event": event,
            "patrol_asset": PatrolAssetSerializer(asset).data,
        },
    )


def _group_send(group: str, message: dict) -> None:
    channel_layer = get_channel_layer()
    if not channel_layer:
        return
    async_to_sync(channel_layer.group_send)(group, message)
