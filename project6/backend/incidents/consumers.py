from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer


@database_sync_to_async
def is_active_police_officer(user):
    if not user or not user.is_authenticated or not user.is_active:
        return False
    profile = getattr(user, "police_profile", None)
    return profile is not None and profile.active


class PoliceAlertConsumer(AsyncJsonWebsocketConsumer):
    async def connect(self):
        user = self.scope.get("user")
        if not await is_active_police_officer(user):
            await self.close(code=4401)
            return

        await self.channel_layer.group_add("police_alerts", self.channel_name)
        await self.accept()
        await self.send_json({"event": "connected", "channel": "police_alerts"})

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard("police_alerts", self.channel_name)

    async def receive_json(self, content, **kwargs):
        if content.get("event") == "ping":
            await self.send_json({"event": "pong"})

    async def broadcast_incident(self, event):
        await self.send_json(
            {
                "event": event["event"],
                "incident": event["incident"],
            }
        )

    async def broadcast_hotspot(self, event):
        await self.send_json(
            {
                "event": event["event"],
                "hotspot": event["hotspot"],
            }
        )

    async def broadcast_patrol_asset(self, event):
        await self.send_json(
            {
                "event": event["event"],
                "patrol_asset": event["patrol_asset"],
            }
        )


class CitizenHotspotConsumer(AsyncJsonWebsocketConsumer):
    async def connect(self):
        await self.channel_layer.group_add("citizen_hotspots", self.channel_name)
        await self.accept()
        await self.send_json({"event": "connected", "channel": "citizen_hotspots"})

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard("citizen_hotspots", self.channel_name)

    async def receive_json(self, content, **kwargs):
        if content.get("event") == "ping":
            await self.send_json({"event": "pong"})

    async def broadcast_hotspot(self, event):
        await self.send_json(
            {
                "event": event["event"],
                "hotspot": event["hotspot"],
            }
        )
