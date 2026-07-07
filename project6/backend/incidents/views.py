from hmac import compare_digest

from django.conf import settings
from django.contrib.auth import authenticate, login, logout
from django.db.models import Q
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from rest_framework import generics, permissions, status
from rest_framework.authentication import TokenAuthentication
from rest_framework.authtoken.models import Token
from rest_framework.response import Response
from rest_framework.views import APIView

from incidents.events import (
    broadcast_hotspot_changed,
    broadcast_incident_created,
    broadcast_incident_updated,
    broadcast_patrol_asset_changed,
)
from incidents.hotspots import update_automatic_hotspot_for_incident
from incidents.models import Hotspot, Incident, PatrolAsset, SafetyTip
from incidents.permissions import IsActivePoliceOfficer, IsCentralPoliceOfficer
from incidents.serializers import (
    HotspotSerializer,
    IncidentCreateSerializer,
    IncidentSerializer,
    IotDangerAlertSerializer,
    MobileRegistrationSerializer,
    PatrolAssetSerializer,
    PoliceOfficerSessionSerializer,
    PublicHotspotSerializer,
    PublicIncidentStatusSerializer,
    SafetyTipSerializer,
)
from incidents.tasks import VoiceCallJob, enqueue_voice_call


def mobile_auth_payload(user, token: Token) -> dict[str, object]:
    return {
        "token": token.key,
        "user_id": user.pk,
        "username": user.username,
        "email": user.email,
        "display_name": user.first_name or user.username,
    }


@method_decorator(csrf_exempt, name="dispatch")
class MobileRegistrationView(APIView):
    authentication_classes = []
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        serializer = MobileRegistrationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        token = Token.objects.create(user=user)
        return Response(mobile_auth_payload(user, token), status=status.HTTP_201_CREATED)


@method_decorator(csrf_exempt, name="dispatch")
class MobileLoginView(APIView):
    authentication_classes = []
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        username = str(request.data.get("username", "")).strip()
        password = request.data.get("password", "")
        user = authenticate(request, username=username, password=password)
        if user is None or not user.is_active:
            return Response(
                {"detail": "Invalid username or password."},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        token, _ = Token.objects.get_or_create(user=user)
        return Response(mobile_auth_payload(user, token))


class MobileMeView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        return Response(mobile_auth_payload(request.user, request.auth))


class MobileLogoutView(APIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        request.auth.delete()
        return Response({"detail": "Logged out."})


class HealthView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        return Response({"status": "ok", "service": "safety-mobility"})


class PublicIncidentCreateView(generics.CreateAPIView):
    serializer_class = IncidentCreateSerializer
    permission_classes = [permissions.AllowAny]

    def perform_create(self, serializer):
        incident = serializer.save()
        broadcast_incident_created(incident)
        hotspot_change = update_automatic_hotspot_for_incident(incident)
        if hotspot_change is not None:
            broadcast_hotspot_changed(hotspot_change.hotspot, hotspot_change.event)
        enqueue_voice_call(
            VoiceCallJob(
                incident_id=str(incident.id),
                latitude=incident.latitude,
                longitude=incident.longitude,
                reporter_phone=incident.reporter_phone,
            )
        )


@method_decorator(csrf_exempt, name="dispatch")
class IotDangerAlertView(APIView):
    authentication_classes = []
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        expected_key = settings.IOT_DEVICE_API_KEY
        provided_key = request.headers.get("X-IOT-API-KEY", "")
        if not expected_key or not compare_digest(provided_key, expected_key):
            return Response(
                {"detail": "Invalid IoT API key."},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = IotDangerAlertSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        incident = serializer.save()
        broadcast_incident_created(incident)
        hotspot_change = update_automatic_hotspot_for_incident(incident)
        if hotspot_change is not None:
            broadcast_hotspot_changed(hotspot_change.hotspot, hotspot_change.event)
        enqueue_voice_call(
            VoiceCallJob(
                incident_id=str(incident.id),
                latitude=incident.latitude,
                longitude=incident.longitude,
                reporter_phone=incident.reporter_phone,
            )
        )
        return Response(IncidentSerializer(incident).data, status=status.HTTP_201_CREATED)


class PublicIncidentStatusView(generics.ListAPIView):
    serializer_class = PublicIncidentStatusSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        return Incident.objects.filter(
            anonymous_token=self.kwargs["anonymous_token"]
        ).order_by("-created_at")[:10]


class PublicHotspotListView(generics.ListAPIView):
    serializer_class = PublicHotspotSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        now = timezone.now()
        return (
            Hotspot.objects.filter(
                active=True,
                risk_level__in=[
                    Hotspot.RiskLevel.LOW,
                    Hotspot.RiskLevel.HIGH,
                ],
            )
            .filter(Q(expires_at__isnull=True) | Q(expires_at__gt=now))
        )


class MobileSafetyTipListView(generics.ListAPIView):
    authentication_classes = [TokenAuthentication]
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = SafetyTipSerializer

    def get_queryset(self):
        return SafetyTip.objects.filter(is_active=True)


@method_decorator(csrf_exempt, name="dispatch")
class PoliceLoginView(APIView):
    permission_classes = [permissions.AllowAny]

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
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        logout(request)
        return Response({"detail": "Logged out."})


class PoliceMeView(APIView):
    permission_classes = [IsActivePoliceOfficer]

    def get(self, request):
        return Response(PoliceOfficerSessionSerializer(request.user.police_profile).data)


class PoliceIncidentListView(generics.ListAPIView):
    serializer_class = IncidentSerializer
    permission_classes = [IsActivePoliceOfficer]

    def get_queryset(self):
        queryset = Incident.objects.all()
        status_filter = self.request.query_params.get("status")
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        return queryset


class PoliceIncidentDetailView(generics.RetrieveUpdateAPIView):
    queryset = Incident.objects.all()
    serializer_class = IncidentSerializer
    permission_classes = [IsActivePoliceOfficer]
    http_method_names = ["get", "patch", "put"]

    def perform_update(self, serializer):
        previous_status = serializer.instance.status
        next_status = serializer.validated_data.get("status", previous_status)
        profile = self.request.user.police_profile

        if (
            previous_status != Incident.Status.RESOLVED
            and next_status == Incident.Status.RESOLVED
        ):
            incident = serializer.save(
                solved_by=self.request.user,
                solved_by_name=profile.full_name,
                solved_by_badge_number=profile.badge_number,
                solved_by_station=profile.station,
                solved_at=timezone.now(),
            )
        elif (
            previous_status == Incident.Status.RESOLVED
            and next_status != Incident.Status.RESOLVED
        ):
            incident = serializer.save(
                solved_by=None,
                solved_by_name="",
                solved_by_badge_number="",
                solved_by_station="",
                solved_at=None,
            )
        else:
            incident = serializer.save()
        broadcast_incident_updated(incident)


class PoliceHotspotListCreateView(generics.ListCreateAPIView):
    serializer_class = HotspotSerializer
    permission_classes = [IsActivePoliceOfficer]

    def get_queryset(self):
        return Hotspot.objects.filter(active=True)

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
        return PatrolAsset.objects.filter(active=True)

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


class PoliceSafetyTipListCreateView(generics.ListCreateAPIView):
    serializer_class = SafetyTipSerializer
    permission_classes = [IsCentralPoliceOfficer]

    def get_queryset(self):
        return SafetyTip.objects.filter(is_active=True)

    def perform_create(self, serializer):
        serializer.save(updated_by=self.request.user)


class PoliceSafetyTipDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = SafetyTip.objects.all()
    serializer_class = SafetyTipSerializer
    permission_classes = [IsCentralPoliceOfficer]
    http_method_names = ["get", "patch", "put", "delete"]

    def perform_update(self, serializer):
        serializer.save(updated_by=self.request.user)

    def perform_destroy(self, instance):
        instance.is_active = False
        instance.updated_by = self.request.user
        instance.save(update_fields=["is_active", "updated_by", "updated_at"])
