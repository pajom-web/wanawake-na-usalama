import secrets
from decimal import Decimal, InvalidOperation

from django.contrib.auth import authenticate, get_user_model
from django.db import transaction
from rest_framework import serializers
from rest_framework.authtoken.models import Token

from .models import (
    EmergencyContact,
    Hotspot,
    IncidentReport,
    LiveTrackingSession,
    PatrolAsset,
    PoliceOfficer,
    SafetyTip,
    SharedRoute,
    UserProfile,
)

User = get_user_model()

DASHBOARD_TO_MOBILE_CATEGORY = {
    "SOS": IncidentReport.Category.OTHER,
    "HARASSMENT": IncidentReport.Category.HARASSMENT,
    "STALKING": IncidentReport.Category.SUSPICIOUS_ACTIVITY,
    "MEDICAL": IncidentReport.Category.OTHER,
    "OTHER": IncidentReport.Category.OTHER,
}

MOBILE_TO_DASHBOARD_CATEGORY = {
    IncidentReport.Category.HARASSMENT: "HARASSMENT",
    IncidentReport.Category.SUSPICIOUS_ACTIVITY: "STALKING",
    IncidentReport.Category.POOR_LIGHTING: "OTHER",
    IncidentReport.Category.UNSAFE_STREET: "OTHER",
    IncidentReport.Category.DESERTED_AREA: "OTHER",
    IncidentReport.Category.OTHER: "OTHER",
}

DASHBOARD_CATEGORY_TITLES = {
    "SOS": "Emergency SOS Alert",
    "HARASSMENT": "Harassment Report",
    "STALKING": "Stalking Concerns",
    "MEDICAL": "Medical Assistance",
    "OTHER": "Safety Report",
}

RISK_TO_SEVERITY = {
    IncidentReport.RiskLevel.LOW: IncidentReport.DashboardSeverity.LOW,
    IncidentReport.RiskLevel.MODERATE: IncidentReport.DashboardSeverity.MEDIUM,
    IncidentReport.RiskLevel.HIGH: IncidentReport.DashboardSeverity.HIGH,
    IncidentReport.RiskLevel.CRITICAL: IncidentReport.DashboardSeverity.CRITICAL,
}

SEVERITY_TO_RISK = {
    IncidentReport.DashboardSeverity.LOW: IncidentReport.RiskLevel.LOW,
    IncidentReport.DashboardSeverity.MEDIUM: IncidentReport.RiskLevel.MODERATE,
    IncidentReport.DashboardSeverity.HIGH: IncidentReport.RiskLevel.HIGH,
    IncidentReport.DashboardSeverity.CRITICAL: IncidentReport.RiskLevel.CRITICAL,
}


def validate_lat_lng(latitude: Decimal, longitude: Decimal) -> None:
    if latitude < Decimal("-90") or latitude > Decimal("90"):
        raise serializers.ValidationError({"latitude": "Latitude must be between -90 and 90."})
    if longitude < Decimal("-180") or longitude > Decimal("180"):
        raise serializers.ValidationError({"longitude": "Longitude must be between -180 and 180."})


def normalize_mobile_category(value: object) -> str:
    text = str(value or "").strip()
    if text in IncidentReport.Category.values:
        return text
    return DASHBOARD_TO_MOBILE_CATEGORY.get(text.upper(), IncidentReport.Category.OTHER)


def dashboard_category(value: object) -> str:
    text = str(value or "").strip()
    if text.upper() in DASHBOARD_TO_MOBILE_CATEGORY:
        return text.upper()
    return MOBILE_TO_DASHBOARD_CATEGORY.get(text, "OTHER")


def normalize_severity(value: object, fallback_risk: object = None) -> str:
    text = str(value or "").strip().upper()
    if text in IncidentReport.DashboardSeverity.values:
        return text
    risk = str(fallback_risk or "").strip().lower()
    return RISK_TO_SEVERITY.get(risk, IncidentReport.DashboardSeverity.CRITICAL)


def risk_from_severity(value: object, fallback: object = None) -> str:
    severity = normalize_severity(value, fallback)
    return SEVERITY_TO_RISK.get(severity, IncidentReport.RiskLevel.MODERATE)


def validate_latitude(value: float) -> float:
    if value < -90 or value > 90:
        raise serializers.ValidationError("Latitude must be between -90 and 90.")
    return value


def validate_longitude(value: float) -> float:
    if value < -180 or value > 180:
        raise serializers.ValidationError("Longitude must be between -180 and 180.")
    return value


class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = ["display_name", "phone_number", "preferred_city", "is_safety_verified"]
        read_only_fields = ["is_safety_verified"]


class RegistrationSerializer(serializers.Serializer):
    username = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, min_length=8)
    display_name = serializers.CharField(max_length=120)
    phone_number = serializers.CharField(max_length=32, allow_blank=True, required=False)

    def validate_username(self, value: str) -> str:
        if User.objects.filter(username__iexact=value).exists():
            raise serializers.ValidationError("This username is already registered.")
        return value

    def validate_email(self, value: str) -> str:
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError("This email is already registered.")
        return value

    @transaction.atomic
    def create(self, validated_data):
        phone_number = validated_data.pop("phone_number", "")
        display_name = validated_data.pop("display_name")
        user = User.objects.create_user(**validated_data)
        UserProfile.objects.create(
            user=user,
            display_name=display_name,
            phone_number=phone_number,
        )
        Token.objects.get_or_create(user=user)
        return user


class LoginSerializer(serializers.Serializer):
    username = serializers.CharField()
    password = serializers.CharField(write_only=True)

    def validate(self, attrs):
        user = authenticate(
            request=self.context.get("request"),
            username=attrs["username"],
            password=attrs["password"],
        )
        if not user:
            raise serializers.ValidationError("Invalid credentials.")
        if not user.is_active:
            raise serializers.ValidationError("This account is disabled.")
        attrs["user"] = user
        return attrs


class AuthResponseSerializer(serializers.Serializer):
    token = serializers.CharField()
    user_id = serializers.IntegerField()
    username = serializers.CharField()
    display_name = serializers.CharField()


class PoliceOfficerSessionSerializer(serializers.ModelSerializer):
    id = serializers.IntegerField(source="user.id", read_only=True)
    username = serializers.CharField(source="user.username", read_only=True)
    email = serializers.EmailField(source="user.email", read_only=True)
    is_staff = serializers.BooleanField(source="user.is_staff", read_only=True)
    rank_display = serializers.CharField(source="get_rank_display", read_only=True)
    can_view_resolution_details = serializers.BooleanField(read_only=True)

    class Meta:
        model = PoliceOfficer
        fields = [
            "id",
            "username",
            "email",
            "is_staff",
            "full_name",
            "badge_number",
            "rank",
            "rank_display",
            "station",
            "unit",
            "phone_number",
            "active",
            "can_view_resolution_details",
        ]


class IncidentReportSerializer(serializers.ModelSerializer):
    reporter = serializers.StringRelatedField(read_only=True)

    class Meta:
        model = IncidentReport
        fields = [
            "id",
            "reporter",
            "anonymous_token",
            "category",
            "risk_level",
            "status",
            "severity",
            "title",
            "description",
            "reporter_phone",
            "latitude",
            "longitude",
            "occurred_at",
            "is_verified",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "reporter",
            "anonymous_token",
            "status",
            "severity",
            "is_verified",
            "created_at",
            "updated_at",
        ]

    def validate(self, attrs):
        validate_lat_lng(attrs["latitude"], attrs["longitude"])
        return attrs

    def create(self, validated_data):
        if not validated_data.get("anonymous_token"):
            validated_data["anonymous_token"] = secrets.token_urlsafe(32)
        validated_data["severity"] = RISK_TO_SEVERITY.get(
            validated_data.get("risk_level"),
            IncidentReport.DashboardSeverity.MEDIUM,
        )
        return IncidentReport.objects.create(
            reporter=self.context["request"].user,
            **validated_data,
        )


class DashboardIncidentCreateSerializer(serializers.ModelSerializer):
    category = serializers.CharField(required=False, allow_blank=True)
    severity = serializers.CharField(required=False, allow_blank=True)
    risk_level = serializers.CharField(required=False, allow_blank=True, write_only=True)
    title = serializers.CharField(required=False, allow_blank=True, write_only=True)
    latitude = serializers.DecimalField(max_digits=9, decimal_places=6)
    longitude = serializers.DecimalField(max_digits=9, decimal_places=6)

    class Meta:
        model = IncidentReport
        fields = [
            "anonymous_token",
            "category",
            "severity",
            "risk_level",
            "title",
            "latitude",
            "longitude",
            "description",
            "reporter_phone",
        ]

    def validate(self, attrs):
        validate_lat_lng(attrs["latitude"], attrs["longitude"])
        raw_category = attrs.get("category") or IncidentReport.Category.OTHER
        category = normalize_mobile_category(raw_category)
        severity = normalize_severity(attrs.get("severity"), attrs.get("risk_level"))
        attrs["category"] = category
        attrs["severity"] = severity
        attrs["risk_level"] = risk_from_severity(severity, attrs.get("risk_level"))
        attrs["title"] = attrs.get("title") or DASHBOARD_CATEGORY_TITLES.get(
            dashboard_category(raw_category),
            "Safety Report",
        )
        if not attrs.get("anonymous_token"):
            attrs["anonymous_token"] = secrets.token_urlsafe(32)
        return attrs

    def create(self, validated_data):
        request = self.context.get("request")
        user = getattr(request, "user", None)
        if user and user.is_authenticated:
            validated_data["reporter"] = user
        return IncidentReport.objects.create(**validated_data)


class DashboardIncidentSerializer(serializers.ModelSerializer):
    central_only_fields = {
        "solved_by_name",
        "solved_by_badge_number",
        "solved_by_station",
        "solved_at",
    }

    id = serializers.SerializerMethodField()
    category = serializers.SerializerMethodField()
    severity = serializers.SerializerMethodField()

    class Meta:
        model = IncidentReport
        fields = [
            "id",
            "anonymous_token",
            "category",
            "status",
            "severity",
            "latitude",
            "longitude",
            "description",
            "reporter_phone",
            "assigned_unit",
            "police_notes",
            "solved_by_name",
            "solved_by_badge_number",
            "solved_by_station",
            "solved_at",
            "source",
            "device_id",
            "pressed_at",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "anonymous_token",
            "source",
            "device_id",
            "pressed_at",
            "solved_by_name",
            "solved_by_badge_number",
            "solved_by_station",
            "solved_at",
            "created_at",
            "updated_at",
        ]

    def get_id(self, obj):
        return str(obj.id)

    def get_category(self, obj):
        return dashboard_category(obj.category)

    def get_severity(self, obj):
        return obj.severity or RISK_TO_SEVERITY.get(
            obj.risk_level,
            IncidentReport.DashboardSeverity.MEDIUM,
        )

    def to_representation(self, instance):
        data = super().to_representation(instance)
        if not self._can_view_resolution_details():
            for field in self.central_only_fields:
                data.pop(field, None)
        return data

    def _can_view_resolution_details(self) -> bool:
        request = self.context.get("request")
        user = getattr(request, "user", None)
        profile = getattr(user, "police_profile", None)
        return bool(profile is not None and profile.active and profile.can_view_resolution_details)


class PublicIncidentStatusSerializer(DashboardIncidentSerializer):
    class Meta(DashboardIncidentSerializer.Meta):
        fields = [
            "id",
            "category",
            "severity",
            "status",
            "latitude",
            "longitude",
            "description",
            "source",
            "pressed_at",
            "created_at",
            "updated_at",
        ]


class SafetyTipSerializer(serializers.ModelSerializer):
    class Meta:
        model = SafetyTip
        fields = [
            "id",
            "title",
            "body",
            "category",
            "published_at",
            "updated_at",
        ]
        read_only_fields = fields


class EmergencyContactSerializer(serializers.ModelSerializer):
    class Meta:
        model = EmergencyContact
        fields = [
            "id",
            "name",
            "relationship",
            "phone_number",
            "email",
            "share_token",
            "is_active",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "share_token", "created_at", "updated_at"]


class SharedRouteSerializer(serializers.ModelSerializer):
    contact_id = serializers.PrimaryKeyRelatedField(
        source="contact",
        queryset=EmergencyContact.objects.none(),
        required=False,
        allow_null=True,
    )

    class Meta:
        model = SharedRoute
        fields = [
            "id",
            "contact_id",
            "name",
            "nodes",
            "status",
            "share_token",
            "starts_at",
            "expires_at",
            "revoked_at",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "status", "share_token", "revoked_at", "created_at", "updated_at"]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")
        if request and request.user.is_authenticated:
            self.fields["contact_id"].queryset = EmergencyContact.objects.filter(owner=request.user)

    def validate_nodes(self, value):
        if not isinstance(value, list) or len(value) < 2:
            raise serializers.ValidationError("Provide at least two coordinate nodes.")
        cleaned = []
        for index, node in enumerate(value):
            if not isinstance(node, dict):
                raise serializers.ValidationError(f"Node {index} must be an object.")
            lat = node.get("latitude", node.get("lat"))
            lng = node.get("longitude", node.get("lng"))
            try:
                latitude = Decimal(str(lat)).quantize(Decimal("0.000001"))
                longitude = Decimal(str(lng)).quantize(Decimal("0.000001"))
            except (InvalidOperation, TypeError):
                raise serializers.ValidationError(f"Node {index} has invalid coordinates.") from None
            validate_lat_lng(latitude, longitude)
            cleaned.append({"latitude": float(latitude), "longitude": float(longitude)})
        return cleaned

    def create(self, validated_data):
        return SharedRoute.objects.create(owner=self.context["request"].user, **validated_data)


class LiveTrackingSessionSerializer(serializers.ModelSerializer):
    contact_id = serializers.PrimaryKeyRelatedField(
        source="contact",
        queryset=EmergencyContact.objects.none(),
        required=False,
        allow_null=True,
    )
    route_id = serializers.PrimaryKeyRelatedField(
        source="route",
        queryset=SharedRoute.objects.none(),
        required=False,
        allow_null=True,
    )

    class Meta:
        model = LiveTrackingSession
        fields = [
            "id",
            "contact_id",
            "route_id",
            "session_token",
            "status",
            "last_latitude",
            "last_longitude",
            "started_at",
            "ended_at",
            "revoked_at",
            "metadata",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "session_token",
            "status",
            "last_latitude",
            "last_longitude",
            "started_at",
            "ended_at",
            "revoked_at",
            "created_at",
            "updated_at",
        ]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get("request")
        if request and request.user.is_authenticated:
            self.fields["contact_id"].queryset = EmergencyContact.objects.filter(owner=request.user)
            self.fields["route_id"].queryset = SharedRoute.objects.filter(owner=request.user)

    def create(self, validated_data):
        return LiveTrackingSession.objects.create(owner=self.context["request"].user, **validated_data)


class PublicHotspotSerializer(serializers.ModelSerializer):
    class Meta:
        model = Hotspot
        fields = [
            "id",
            "title",
            "center_latitude",
            "center_longitude",
            "radius_meters",
            "risk_level",
            "notes",
            "expires_at",
            "created_at",
            "updated_at",
        ]


class HotspotSerializer(serializers.ModelSerializer):
    center_latitude = serializers.FloatField(validators=[validate_latitude])
    center_longitude = serializers.FloatField(validators=[validate_longitude])

    class Meta:
        model = Hotspot
        fields = [
            "id",
            "title",
            "center_latitude",
            "center_longitude",
            "radius_meters",
            "risk_level",
            "active",
            "notes",
            "expires_at",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]

    def validate_radius_meters(self, value: int) -> int:
        if value < 25 or value > 10000:
            raise serializers.ValidationError("Radius must be between 25 and 10000 meters.")
        return value


class PatrolAssetSerializer(serializers.ModelSerializer):
    latitude = serializers.FloatField(validators=[validate_latitude])
    longitude = serializers.FloatField(validators=[validate_longitude])

    class Meta:
        model = PatrolAsset
        fields = [
            "id",
            "name",
            "latitude",
            "longitude",
            "status",
            "active",
            "notes",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]
