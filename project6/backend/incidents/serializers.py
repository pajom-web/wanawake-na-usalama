import secrets

from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.utils import timezone
from rest_framework import serializers

from incidents.models import Hotspot, Incident, PatrolAsset, PoliceOfficer, SafetyTip


class MobileRegistrationSerializer(serializers.Serializer):
    username = serializers.CharField(max_length=150)
    email = serializers.EmailField()
    password = serializers.CharField(
        write_only=True,
        trim_whitespace=False,
        min_length=8,
    )
    display_name = serializers.CharField(max_length=150, required=False, allow_blank=True)

    def validate_username(self, value: str) -> str:
        username = value.strip()
        if get_user_model().objects.filter(username__iexact=username).exists():
            raise serializers.ValidationError("That username is already registered.")
        return username

    def validate_email(self, value: str) -> str:
        email = value.strip().lower()
        if get_user_model().objects.filter(email__iexact=email).exists():
            raise serializers.ValidationError("That email address is already registered.")
        return email

    def validate(self, attrs):
        user = get_user_model()(
            username=attrs["username"],
            email=attrs["email"],
            first_name=attrs.get("display_name", "").strip(),
        )
        try:
            validate_password(attrs["password"], user=user)
        except DjangoValidationError as exc:
            raise serializers.ValidationError({"password": list(exc.messages)}) from exc
        return attrs

    def create(self, validated_data):
        display_name = validated_data.pop("display_name", "").strip()
        return get_user_model().objects.create_user(
            first_name=display_name,
            **validated_data,
        )


def validate_latitude(value: float) -> float:
    if value < -90 or value > 90:
        raise serializers.ValidationError("Latitude must be between -90 and 90.")
    return value


def validate_longitude(value: float) -> float:
    if value < -180 or value > 180:
        raise serializers.ValidationError("Longitude must be between -180 and 180.")
    return value


class PoliceOfficerSessionSerializer(serializers.ModelSerializer):
    id = serializers.IntegerField(source="user.id", read_only=True)
    username = serializers.CharField(source="user.username", read_only=True)
    email = serializers.EmailField(source="user.email", read_only=True)
    is_staff = serializers.BooleanField(source="user.is_staff", read_only=True)
    rank_display = serializers.CharField(source="get_rank_display", read_only=True)
    can_view_resolution_details = serializers.BooleanField(read_only=True)
    can_manage_safety_tips = serializers.BooleanField(read_only=True)

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
            "can_manage_safety_tips",
        ]


class IncidentCreateSerializer(serializers.ModelSerializer):
    anonymous_token = serializers.CharField(required=False, allow_blank=True)
    latitude = serializers.FloatField(validators=[validate_latitude])
    longitude = serializers.FloatField(validators=[validate_longitude])

    class Meta:
        model = Incident
        fields = [
            "id",
            "anonymous_token",
            "category",
            "severity",
            "latitude",
            "longitude",
            "description",
            "reporter_phone",
            "status",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "status", "created_at", "updated_at"]

    def create(self, validated_data):
        token = validated_data.get("anonymous_token")
        if not token:
            validated_data["anonymous_token"] = secrets.token_urlsafe(32)
        return super().create(validated_data)


class IotDangerAlertSerializer(serializers.Serializer):
    device_id = serializers.CharField(max_length=80)
    latitude = serializers.FloatField(validators=[validate_latitude])
    longitude = serializers.FloatField(validators=[validate_longitude])
    pressed_at = serializers.DateTimeField(required=False, allow_null=True)
    description = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=500,
    )

    def validate_device_id(self, value: str) -> str:
        value = value.strip()
        if not value:
            raise serializers.ValidationError("Device ID is required.")
        return value

    def create(self, validated_data):
        device_id = validated_data["device_id"]
        description = validated_data.get("description", "").strip()
        if not description:
            description = "IoT panic button pressed."

        return Incident.objects.create(
            anonymous_token=f"iot-{secrets.token_urlsafe(24)}",
            category=Incident.Category.SOS,
            severity=Incident.Severity.CRITICAL,
            latitude=validated_data["latitude"],
            longitude=validated_data["longitude"],
            description=description,
            source=Incident.Source.IOT_BUTTON,
            device_id=device_id,
            pressed_at=validated_data.get("pressed_at") or timezone.now(),
        )


class PublicIncidentStatusSerializer(serializers.ModelSerializer):
    class Meta:
        model = Incident
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


class IncidentSerializer(serializers.ModelSerializer):
    central_only_fields = {
        "solved_by_name",
        "solved_by_badge_number",
        "solved_by_station",
        "solved_at",
    }

    class Meta:
        model = Incident
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
        return bool(
            profile is not None and profile.active and profile.can_view_resolution_details
        )


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
            "source",
            "incident_count",
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
            "source",
            "incident_count",
            "active",
            "notes",
            "expires_at",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "source",
            "incident_count",
            "created_at",
            "updated_at",
        ]

    def validate_radius_meters(self, value: int) -> int:
        if value < 25 or value > 10000:
            raise serializers.ValidationError(
                "Radius must be between 25 and 10000 meters."
            )
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


class SafetyTipSerializer(serializers.ModelSerializer):
    class Meta:
        model = SafetyTip
        fields = [
            "id",
            "title",
            "body",
            "category",
            "is_active",
            "display_order",
            "published_at",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "published_at", "created_at", "updated_at"]
