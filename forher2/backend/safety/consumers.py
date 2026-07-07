import json
from decimal import Decimal, InvalidOperation
from urllib.parse import parse_qs

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer, AsyncWebsocketConsumer
from rest_framework.authtoken.models import Token

from .models import LiveTrackingSession


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
        await self.send_json({"event": event["event"], "incident": event["incident"]})

    async def broadcast_hotspot(self, event):
        await self.send_json({"event": event["event"], "hotspot": event["hotspot"]})

    async def broadcast_patrol_asset(self, event):
        await self.send_json(
            {"event": event["event"], "patrol_asset": event["patrol_asset"]}
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
        await self.send_json({"event": event["event"], "hotspot": event["hotspot"]})


class LiveLocationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        params = parse_qs(self.scope["query_string"].decode("utf-8"))
        token_key = first(params.get("token"))
        session_token = first(params.get("session"))

        if not token_key or not session_token:
            await self.close(code=4401)
            return

        self.user = await self.get_user(token_key)
        self.session = await self.get_session(session_token, self.user.id if self.user else None)
        if not self.user or not self.session:
            await self.close(code=4401)
            return

        self.session_group = self.session.group_name
        self.user_group = f"user_{self.user.id}"
        await self.channel_layer.group_add(self.session_group, self.channel_name)
        await self.channel_layer.group_add(self.user_group, self.channel_name)
        await self.accept()
        await self.send_json(
            {
                "type": "session.connected",
                "session": str(self.session.session_token),
            }
        )

    async def disconnect(self, close_code):
        if hasattr(self, "session_group"):
            await self.channel_layer.group_discard(self.session_group, self.channel_name)
        if hasattr(self, "user_group"):
            await self.channel_layer.group_discard(self.user_group, self.channel_name)

    async def receive(self, text_data=None, bytes_data=None):
        try:
            payload = json.loads(text_data or "{}")
        except json.JSONDecodeError:
            await self.send_json({"type": "error", "detail": "Invalid JSON payload."})
            return

        message_type = payload.get("type")
        if message_type == "location.update":
            await self.handle_location_update(payload)
            return
        if message_type == "session.end":
            await self.end_session()
            return
        if message_type == "ping":
            await self.send_json({"type": "pong"})
            return
        await self.send_json({"type": "error", "detail": "Unsupported message type."})

    async def handle_location_update(self, payload):
        latitude = payload.get("latitude")
        longitude = payload.get("longitude")
        try:
            lat_decimal = Decimal(str(latitude)).quantize(Decimal("0.000001"))
            lng_decimal = Decimal(str(longitude)).quantize(Decimal("0.000001"))
        except (InvalidOperation, TypeError):
            await self.send_json({"type": "error", "detail": "Invalid coordinates."})
            return

        if not Decimal("-90") <= lat_decimal <= Decimal("90"):
            await self.send_json({"type": "error", "detail": "Latitude must be between -90 and 90."})
            return
        if not Decimal("-180") <= lng_decimal <= Decimal("180"):
            await self.send_json({"type": "error", "detail": "Longitude must be between -180 and 180."})
            return

        session_is_active = await self.update_session_location(lat_decimal, lng_decimal)
        if not session_is_active:
            await self.send_json({"type": "session.revoked", "reason": "inactive"})
            await self.close(code=4403)
            return

        await self.channel_layer.group_send(
            self.session_group,
            {
                "type": "location.broadcast",
                "latitude": float(lat_decimal),
                "longitude": float(lng_decimal),
                "accuracy": payload.get("accuracy"),
                "speed": payload.get("speed"),
                "heading": payload.get("heading"),
                "sent_at": payload.get("sent_at"),
            },
        )

    async def end_session(self):
        await self.mark_session_ended()
        await self.channel_layer.group_send(
            self.session_group,
            {"type": "tracking.revoked", "reason": "ended_by_owner"},
        )

    async def location_broadcast(self, event):
        await self.send_json(
            {
                "type": "location.update",
                "latitude": event["latitude"],
                "longitude": event["longitude"],
                "accuracy": event.get("accuracy"),
                "speed": event.get("speed"),
                "heading": event.get("heading"),
                "sent_at": event.get("sent_at"),
            }
        )

    async def tracking_revoked(self, event):
        await self.send_json({"type": "session.revoked", "reason": event.get("reason", "revoked")})
        await self.close(code=4403)

    async def force_disconnect(self, event):
        await self.send_json({"type": "session.revoked", "reason": event.get("reason", "forced")})
        await self.close(code=4403)

    async def send_json(self, payload):
        await self.send(text_data=json.dumps(payload))

    @database_sync_to_async
    def get_user(self, token_key):
        token = Token.objects.select_related("user").filter(key=token_key, user__is_active=True).first()
        return token.user if token else None

    @database_sync_to_async
    def get_session(self, session_token, user_id):
        return (
            LiveTrackingSession.objects.filter(
                session_token=session_token,
                owner_id=user_id,
                status=LiveTrackingSession.Status.ACTIVE,
            )
            .select_related("owner")
            .first()
        )

    @database_sync_to_async
    def update_session_location(self, latitude, longitude):
        session = LiveTrackingSession.objects.filter(
            pk=self.session.pk,
            owner_id=self.user.id,
            status=LiveTrackingSession.Status.ACTIVE,
        ).first()
        if not session:
            return False
        session.touch_location(latitude, longitude)
        return True

    @database_sync_to_async
    def mark_session_ended(self):
        session = LiveTrackingSession.objects.filter(
            pk=self.session.pk,
            owner_id=self.user.id,
            status=LiveTrackingSession.Status.ACTIVE,
        ).first()
        if session:
            session.end()


def first(values):
    return values[0] if values else None
