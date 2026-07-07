from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

from incidents.serializers import (
    HotspotSerializer,
    IncidentSerializer,
    PatrolAssetSerializer,
    PublicHotspotSerializer,
)


def broadcast_incident_created(incident) -> None:
    channel_layer = get_channel_layer()
    if not channel_layer:
        return
    async_to_sync(channel_layer.group_send)(
        "police_alerts",
        {
            "type": "broadcast.incident",
            "event": "incident.created",
            "incident": IncidentSerializer(incident).data,
        },
    )


def broadcast_incident_updated(incident) -> None:
    channel_layer = get_channel_layer()
    if not channel_layer:
        return
    async_to_sync(channel_layer.group_send)(
        "police_alerts",
        {
            "type": "broadcast.incident",
            "event": "incident.updated",
            "incident": IncidentSerializer(incident).data,
        },
    )


def broadcast_hotspot_changed(hotspot, event: str) -> None:
    channel_layer = get_channel_layer()
    if not channel_layer:
        return

    public_payload = PublicHotspotSerializer(hotspot).data
    police_payload = HotspotSerializer(hotspot).data
    async_to_sync(channel_layer.group_send)(
        "citizen_hotspots",
        {
            "type": "broadcast.hotspot",
            "event": event,
            "hotspot": public_payload,
        },
    )
    async_to_sync(channel_layer.group_send)(
        "police_alerts",
        {
            "type": "broadcast.hotspot",
            "event": event,
            "hotspot": police_payload,
        },
    )


def broadcast_patrol_asset_changed(asset, event: str) -> None:
    channel_layer = get_channel_layer()
    if not channel_layer:
        return

    async_to_sync(channel_layer.group_send)(
        "police_alerts",
        {
            "type": "broadcast.patrol_asset",
            "event": event,
            "patrol_asset": PatrolAssetSerializer(asset).data,
        },
    )
