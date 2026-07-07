from collections import Counter, defaultdict
from decimal import Decimal, InvalidOperation
from math import asin, cos, radians, sin, sqrt

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.contrib.auth import authenticate, login, logout
from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
from rest_framework import generics, status, viewsets
from rest_framework.authtoken.models import Token
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .events import (
    broadcast_hotspot_changed,
    broadcast_incident_created,
    broadcast_incident_updated,
    broadcast_patrol_asset_changed,
)
from .models import (
    EmergencyContact,
    Hotspot,
    IncidentReport,
    LiveTrackingSession,
    PatrolAsset,
    SafetyTip,
    SharedRoute,
)
from .permissions import IsActivePoliceOfficer
from .serializers import (
    DashboardIncidentCreateSerializer,
    DashboardIncidentSerializer,
    EmergencyContactSerializer,
    HotspotSerializer,
    IncidentReportSerializer,
    LiveTrackingSessionSerializer,
    LoginSerializer,
    PatrolAssetSerializer,
    PoliceOfficerSessionSerializer,
    PublicHotspotSerializer,
    PublicIncidentStatusSerializer,
    RegistrationSerializer,
    SafetyTipSerializer,
    SharedRouteSerializer,
)

RISK_WEIGHTS = {
    IncidentReport.RiskLevel.LOW: 1,
    IncidentReport.RiskLevel.MODERATE: 2,
    IncidentReport.RiskLevel.HIGH: 4,
    IncidentReport.RiskLevel.CRITICAL: 6,
}


def auth_payload(user):
    token, _ = Token.objects.get_or_create(user=user)
    profile = getattr(user, "profile", None)
    return {
        "token": token.key,
        "user_id": user.id,
        "username": user.get_username(),
        "display_name": profile.display_name if profile else user.get_username(),
    }


class HealthView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        return Response({"status": "ok", "service": "forher-safety"})


class RegistrationView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegistrationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(auth_payload(user), status=status.HTTP_201_CREATED)


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        return Response(auth_payload(serializer.validated_data["user"]))


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    @transaction.atomic
    def post(self, request):
        user = request.user
        live_sessions = list(
            LiveTrackingSession.objects.select_for_update().filter(
                owner=user,
                status=LiveTrackingSession.Status.ACTIVE,
            )
        )
        active_routes = SharedRoute.objects.select_for_update().filter(
            owner=user,
            status=SharedRoute.Status.ACTIVE,
        )
        for session in live_sessions:
            session.revoke()
        for route in active_routes:
            route.revoke()
        Token.objects.filter(user=user).delete()

        channel_layer = get_channel_layer()
        if channel_layer:
            async_to_sync(channel_layer.group_send)(
                f"user_{user.id}",
                {"type": "force.disconnect", "reason": "logout"},
            )
            for session in live_sessions:
                async_to_sync(channel_layer.group_send)(
                    session.group_name,
                    {"type": "tracking.revoked", "reason": "logout"},
                )
        return Response({"detail": "Logged out and revoked active tracking links."})


class IncidentListCreateView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        if not request.user.is_authenticated:
            return Response(
                {"detail": "Authentication credentials were not provided."},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        queryset = IncidentReport.objects.filter(reporter=request.user).order_by("-occurred_at")
        serializer = IncidentReportSerializer(
            queryset,
            many=True,
            context={"request": request},
        )
        return Response(serializer.data)

    def post(self, request):
        serializer = DashboardIncidentCreateSerializer(
            data=request.data,
            context={"request": request},
        )
        serializer.is_valid(raise_exception=True)
        incident = serializer.save()
        broadcast_incident_created(incident)
        return Response(
            DashboardIncidentSerializer(incident, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class PublicIncidentStatusView(generics.ListAPIView):
    serializer_class = PublicIncidentStatusSerializer
    permission_classes = [AllowAny]

    def get_queryset(self):
        return IncidentReport.objects.filter(
            anonymous_token=self.kwargs["anonymous_token"]
        ).order_by("-created_at")[:10]


class SafetyTipListView(generics.ListAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = SafetyTipSerializer

    def get_queryset(self):
        return SafetyTip.objects.filter(is_active=True)


class HotspotFetchView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        has_coordinates = any(
            key in request.query_params
            for key in ("latitude", "lat", "longitude", "lng")
        )
        if not has_coordinates:
            now = timezone.now()
            queryset = (
                Hotspot.objects.filter(active=True, risk_level__in=[Hotspot.RiskLevel.LOW, Hotspot.RiskLevel.HIGH])
                .filter(Q(expires_at__isnull=True) | Q(expires_at__gt=now))
                .order_by("-created_at")
            )
            return Response(PublicHotspotSerializer(queryset, many=True).data)

        try:
            latitude = Decimal(str(request.query_params.get("latitude", request.query_params.get("lat"))))
            longitude = Decimal(str(request.query_params.get("longitude", request.query_params.get("lng"))))
            radius_km = Decimal(str(request.query_params.get("radius_km", "3")))
            days = int(request.query_params.get("days", "30"))
        except (InvalidOperation, TypeError, ValueError):
            return Response(
                {"detail": "latitude, longitude, radius_km, and days must be valid numbers."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not Decimal("-90") <= latitude <= Decimal("90"):
            return Response({"detail": "Latitude must be between -90 and 90."}, status=400)
        if not Decimal("-180") <= longitude <= Decimal("180"):
            return Response({"detail": "Longitude must be between -180 and 180."}, status=400)
        if radius_km <= 0 or radius_km > Decimal("25"):
            return Response({"detail": "radius_km must be between 0 and 25."}, status=400)

        lat_float = float(latitude)
        lng_float = float(longitude)
        radius_float = float(radius_km)
        lat_delta = radius_float / 110.574
        lng_delta = radius_float / max(111.320 * cos(radians(lat_float)), 0.001)
        min_lat = Decimal(str(lat_float - lat_delta)).quantize(Decimal("0.000001"))
        max_lat = Decimal(str(lat_float + lat_delta)).quantize(Decimal("0.000001"))
        min_lng = Decimal(str(lng_float - lng_delta)).quantize(Decimal("0.000001"))
        max_lng = Decimal(str(lng_float + lng_delta)).quantize(Decimal("0.000001"))

        candidates = IncidentReport.objects.filter(
            latitude__gte=min_lat,
            latitude__lte=max_lat,
            longitude__gte=min_lng,
            longitude__lte=max_lng,
            occurred_at__gte=timezone.now() - timezone.timedelta(days=days),
        ).only("id", "category", "risk_level", "latitude", "longitude", "occurred_at")

        grouped = defaultdict(
            lambda: {
                "latitude_total": 0.0,
                "longitude_total": 0.0,
                "incident_count": 0,
                "risk_score": 0,
                "categories": Counter(),
                "levels": Counter(),
            }
        )

        for incident in candidates:
            incident_lat = float(incident.latitude)
            incident_lng = float(incident.longitude)
            distance = haversine_km(lat_float, lng_float, incident_lat, incident_lng)
            if distance > radius_float:
                continue
            bucket_key = (round(incident_lat, 3), round(incident_lng, 3))
            bucket = grouped[bucket_key]
            bucket["latitude_total"] += incident_lat
            bucket["longitude_total"] += incident_lng
            bucket["incident_count"] += 1
            bucket["risk_score"] += RISK_WEIGHTS.get(incident.risk_level, 1)
            bucket["categories"][incident.category] += 1
            bucket["levels"][incident.risk_level] += 1

        hotspots = []
        for bucket in grouped.values():
            count = bucket["incident_count"]
            dominant_level = bucket["levels"].most_common(1)[0][0]
            hotspots.append(
                {
                    "latitude": round(bucket["latitude_total"] / count, 6),
                    "longitude": round(bucket["longitude_total"] / count, 6),
                    "incident_count": count,
                    "risk_score": bucket["risk_score"],
                    "dominant_category": bucket["categories"].most_common(1)[0][0],
                    "risk_level": dominant_level,
                }
            )

        hotspots.sort(key=lambda item: (item["risk_score"], item["incident_count"]), reverse=True)
        return Response(
            {
                "center": {"latitude": float(latitude), "longitude": float(longitude)},
                "radius_km": float(radius_km),
                "bounding_box": {
                    "min_latitude": float(min_lat),
                    "max_latitude": float(max_lat),
                    "min_longitude": float(min_lng),
                    "max_longitude": float(max_lng),
                },
                "hotspots": hotspots,
            }
        )


def haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    radius = 6371.0088
    d_lat = radians(lat2 - lat1)
    d_lng = radians(lng2 - lng1)
    start_lat = radians(lat1)
    end_lat = radians(lat2)
    value = sin(d_lat / 2) ** 2 + cos(start_lat) * cos(end_lat) * sin(d_lng / 2) ** 2
    return 2 * radius * asin(sqrt(value))


class EmergencyContactViewSet(viewsets.ModelViewSet):
    serializer_class = EmergencyContactSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return EmergencyContact.objects.filter(owner=self.request.user).order_by("name")

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)


class SharedRouteViewSet(viewsets.ModelViewSet):
    serializer_class = SharedRouteSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return SharedRoute.objects.filter(owner=self.request.user).order_by("-created_at")

    def destroy(self, request, *args, **kwargs):
        route = self.get_object()
        route.revoke()
        return Response({"detail": "Route sharing link revoked."})


class LiveTrackingSessionViewSet(viewsets.ModelViewSet):
    serializer_class = LiveTrackingSessionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return LiveTrackingSession.objects.filter(owner=self.request.user).order_by("-created_at")

    def destroy(self, request, *args, **kwargs):
        session = self.get_object()
        session.revoke()
        channel_layer = get_channel_layer()
        if channel_layer:
            async_to_sync(channel_layer.group_send)(
                session.group_name,
                {"type": "tracking.revoked", "reason": "revoked_by_owner"},
            )
        return Response({"detail": "Live tracking session revoked."})


@method_decorator(csrf_exempt, name="dispatch")
class PoliceLoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        username = request.data.get("username", "")
        password = request.data.get("password", "")
        user = authenticate(request, username=username, password=password)
        profile = getattr(user, "police_profile", None) if user else None
        if user is None or profile is None or not profile.active:
            logout(request)
            return Response(
                {"detail": "Invalid police username or password."},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        login(request, user)
        return Response(PoliceOfficerSessionSerializer(profile).data)


@method_decorator(csrf_exempt, name="dispatch")
class PoliceLogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        logout(request)
        return Response({"detail": "Logged out."})


class PoliceMeView(APIView):
    permission_classes = [IsActivePoliceOfficer]

    def get(self, request):
        return Response(PoliceOfficerSessionSerializer(request.user.police_profile).data)


class PoliceIncidentListView(generics.ListAPIView):
    serializer_class = DashboardIncidentSerializer
    permission_classes = [IsActivePoliceOfficer]

    def get_queryset(self):
        queryset = IncidentReport.objects.all().order_by("-created_at")
        status_filter = self.request.query_params.get("status")
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        return queryset


class PoliceIncidentDetailView(generics.RetrieveUpdateAPIView):
    queryset = IncidentReport.objects.all()
    serializer_class = DashboardIncidentSerializer
    permission_classes = [IsActivePoliceOfficer]
    http_method_names = ["get", "patch", "put"]

    def perform_update(self, serializer):
        previous_status = serializer.instance.status
        next_status = serializer.validated_data.get("status", previous_status)
        profile = self.request.user.police_profile

        if (
            previous_status != IncidentReport.DashboardStatus.RESOLVED
            and next_status == IncidentReport.DashboardStatus.RESOLVED
        ):
            incident = serializer.save(
                solved_by=self.request.user,
                solved_by_name=profile.full_name,
                solved_by_badge_number=profile.badge_number,
                solved_by_station=profile.station,
                solved_at=timezone.now(),
                is_verified=True,
            )
        elif (
            previous_status == IncidentReport.DashboardStatus.RESOLVED
            and next_status != IncidentReport.DashboardStatus.RESOLVED
        ):
            incident = serializer.save(
                solved_by=None,
                solved_by_name="",
                solved_by_badge_number="",
                solved_by_station="",
                solved_at=None,
                is_verified=False,
            )
        else:
            incident = serializer.save()
        broadcast_incident_updated(incident)


class PoliceHotspotListCreateView(generics.ListCreateAPIView):
    serializer_class = HotspotSerializer
    permission_classes = [IsActivePoliceOfficer]

    def get_queryset(self):
        return Hotspot.objects.filter(active=True).order_by("-created_at")

    def perform_create(self, serializer):
        hotspot = serializer.save(created_by=self.request.user)
        broadcast_hotspot_changed(hotspot, "hotspot.created")


class PoliceHotspotDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Hotspot.objects.all()
    serializer_class = HotspotSerializer
    permission_classes = [IsActivePoliceOfficer]
    http_method_names = ["get", "patch", "put", "delete"]

    def perform_update(self, serializer):
        hotspot = serializer.save()
        broadcast_hotspot_changed(hotspot, "hotspot.updated")

    def perform_destroy(self, instance):
        instance.active = False
        instance.save(update_fields=["active", "updated_at"])
        broadcast_hotspot_changed(instance, "hotspot.deactivated")


class PolicePatrolAssetListCreateView(generics.ListCreateAPIView):
    serializer_class = PatrolAssetSerializer
    permission_classes = [IsActivePoliceOfficer]

    def get_queryset(self):
        return PatrolAsset.objects.filter(active=True).order_by("name")

    def perform_create(self, serializer):
        asset = serializer.save(updated_by=self.request.user)
        broadcast_patrol_asset_changed(asset, "patrol_asset.created")


class PolicePatrolAssetDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = PatrolAsset.objects.all()
    serializer_class = PatrolAssetSerializer
    permission_classes = [IsActivePoliceOfficer]
    http_method_names = ["get", "patch", "put", "delete"]

    def perform_update(self, serializer):
        asset = serializer.save(updated_by=self.request.user)
        broadcast_patrol_asset_changed(asset, "patrol_asset.updated")

    def perform_destroy(self, instance):
        instance.active = False
        instance.updated_by = self.request.user
        instance.save(update_fields=["active", "updated_by", "updated_at"])
        broadcast_patrol_asset_changed(instance, "patrol_asset.deactivated")
