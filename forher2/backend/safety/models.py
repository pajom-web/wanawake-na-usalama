import uuid
from decimal import Decimal, InvalidOperation

from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils import timezone


LATITUDE_VALIDATORS = [
    MinValueValidator(Decimal("-90.000000")),
    MaxValueValidator(Decimal("90.000000")),
]
LONGITUDE_VALIDATORS = [
    MinValueValidator(Decimal("-180.000000")),
    MaxValueValidator(Decimal("180.000000")),
]


class TimeStampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


class UserProfile(TimeStampedModel):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="profile",
    )
    display_name = models.CharField(max_length=120)
    phone_number = models.CharField(max_length=32, blank=True)
    preferred_city = models.CharField(max_length=120, blank=True)
    is_safety_verified = models.BooleanField(default=False)

    def __str__(self) -> str:
        return self.display_name or self.user.get_username()


class PoliceOfficer(TimeStampedModel):
    class Rank(models.TextChoices):
        CONSTABLE = "CONSTABLE", "Constable"
        SERGEANT = "SERGEANT", "Sergeant"
        INSPECTOR = "INSPECTOR", "Inspector"
        SUPERINTENDENT = "SUPERINTENDENT", "Superintendent"
        COMMANDER = "COMMANDER", "Commander"

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="police_profile",
    )
    full_name = models.CharField(max_length=160)
    badge_number = models.CharField(max_length=40, unique=True)
    rank = models.CharField(max_length=32, choices=Rank.choices, default=Rank.CONSTABLE)
    station = models.CharField(max_length=160)
    unit = models.CharField(max_length=120, blank=True)
    phone_number = models.CharField(max_length=32, blank=True)
    active = models.BooleanField(default=True)

    class Meta:
        ordering = ["full_name", "badge_number"]

    @property
    def can_view_resolution_details(self) -> bool:
        station = self.station.casefold()
        unit = self.unit.casefold()
        return "central police" in station or "central police" in unit

    def __str__(self) -> str:
        return f"{self.badge_number} - {self.full_name}"


class EmergencyContact(TimeStampedModel):
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="emergency_contacts",
    )
    name = models.CharField(max_length=120)
    relationship = models.CharField(max_length=80, blank=True)
    phone_number = models.CharField(max_length=32, blank=True)
    email = models.EmailField(blank=True)
    share_token = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    is_active = models.BooleanField(default=True)

    class Meta:
        indexes = [
            models.Index(fields=["owner", "is_active"]),
            models.Index(fields=["share_token"]),
        ]

    def __str__(self) -> str:
        return f"{self.name} ({self.owner})"


class IncidentReport(TimeStampedModel):
    class Category(models.TextChoices):
        HARASSMENT = "harassment", "Harassment"
        POOR_LIGHTING = "poor_lighting", "Poor lighting"
        UNSAFE_STREET = "unsafe_street", "Unsafe street"
        DESERTED_AREA = "deserted_area", "Deserted area"
        SUSPICIOUS_ACTIVITY = "suspicious_activity", "Suspicious activity"
        OTHER = "other", "Other"

    class RiskLevel(models.TextChoices):
        LOW = "low", "Low"
        MODERATE = "moderate", "Moderate"
        HIGH = "high", "High"
        CRITICAL = "critical", "Critical"

    class DashboardStatus(models.TextChoices):
        REPORTED = "REPORTED", "Reported"
        ACKNOWLEDGED = "ACKNOWLEDGED", "Acknowledged"
        DISPATCHED = "DISPATCHED", "Dispatched"
        RESOLVED = "RESOLVED", "Resolved"
        FALSE_ALARM = "FALSE_ALARM", "False alarm"

    class DashboardSeverity(models.TextChoices):
        LOW = "LOW", "Low"
        MEDIUM = "MEDIUM", "Medium"
        HIGH = "HIGH", "High"
        CRITICAL = "CRITICAL", "Critical"

    class Source(models.TextChoices):
        CITIZEN_APP = "CITIZEN_APP", "Citizen app"
        IOT_BUTTON = "IOT_BUTTON", "IoT panic button"

    reporter = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="incident_reports",
    )
    anonymous_token = models.CharField(max_length=80, blank=True, db_index=True)
    category = models.CharField(max_length=32, choices=Category.choices)
    risk_level = models.CharField(
        max_length=16,
        choices=RiskLevel.choices,
        default=RiskLevel.MODERATE,
    )
    status = models.CharField(
        max_length=24,
        choices=DashboardStatus.choices,
        default=DashboardStatus.REPORTED,
    )
    severity = models.CharField(
        max_length=24,
        choices=DashboardSeverity.choices,
        default=DashboardSeverity.MEDIUM,
    )
    title = models.CharField(max_length=160)
    description = models.TextField(blank=True)
    reporter_phone = models.CharField(max_length=32, blank=True)
    assigned_unit = models.CharField(max_length=120, blank=True)
    police_notes = models.TextField(blank=True)
    solved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="solved_incident_reports",
    )
    solved_by_name = models.CharField(max_length=160, blank=True)
    solved_by_badge_number = models.CharField(max_length=40, blank=True)
    solved_by_station = models.CharField(max_length=160, blank=True)
    solved_at = models.DateTimeField(null=True, blank=True)
    source = models.CharField(
        max_length=32,
        choices=Source.choices,
        default=Source.CITIZEN_APP,
        db_index=True,
    )
    device_id = models.CharField(max_length=80, blank=True, db_index=True)
    pressed_at = models.DateTimeField(null=True, blank=True)
    latitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        validators=LATITUDE_VALIDATORS,
    )
    longitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        validators=LONGITUDE_VALIDATORS,
    )
    occurred_at = models.DateTimeField(default=timezone.now)
    is_verified = models.BooleanField(default=False)

    class Meta:
        ordering = ["-occurred_at"]
        indexes = [
            models.Index(fields=["status", "created_at"]),
            models.Index(fields=["source", "pressed_at"]),
            models.Index(fields=["latitude", "longitude"]),
            models.Index(fields=["category", "occurred_at"]),
            models.Index(fields=["risk_level", "occurred_at"]),
        ]

    def __str__(self) -> str:
        return f"{self.get_category_display()} at {self.latitude},{self.longitude}"


class Hotspot(TimeStampedModel):
    class RiskLevel(models.TextChoices):
        LOW = "LOW", "Low"
        HIGH = "HIGH", "High"

    title = models.CharField(max_length=160)
    center_latitude = models.FloatField()
    center_longitude = models.FloatField()
    radius_meters = models.PositiveIntegerField()
    risk_level = models.CharField(max_length=24, choices=RiskLevel.choices, default=RiskLevel.HIGH)
    active = models.BooleanField(default=True)
    notes = models.TextField(blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="created_safety_hotspots",
    )
    expires_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["active", "risk_level"]),
            models.Index(fields=["center_latitude", "center_longitude"]),
        ]

    def __str__(self) -> str:
        return self.title


class PatrolAsset(TimeStampedModel):
    class Status(models.TextChoices):
        AVAILABLE = "AVAILABLE", "Available"
        DEPLOYED = "DEPLOYED", "Deployed"
        OFFLINE = "OFFLINE", "Offline"

    name = models.CharField(max_length=120, unique=True)
    latitude = models.FloatField()
    longitude = models.FloatField()
    status = models.CharField(max_length=24, choices=Status.choices, default=Status.AVAILABLE)
    active = models.BooleanField(default=True)
    notes = models.TextField(blank=True)
    updated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="updated_patrol_assets",
    )

    class Meta:
        ordering = ["name"]
        indexes = [
            models.Index(fields=["active", "status"]),
            models.Index(fields=["latitude", "longitude"]),
        ]

    def __str__(self) -> str:
        return self.name


class SafetyTip(TimeStampedModel):
    title = models.CharField(max_length=140)
    body = models.TextField()
    category = models.CharField(max_length=80, blank=True)
    is_active = models.BooleanField(default=True)
    display_order = models.PositiveIntegerField(default=0)
    published_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ["display_order", "-published_at"]
        indexes = [
            models.Index(fields=["is_active", "display_order", "published_at"]),
        ]

    def __str__(self) -> str:
        return self.title


class SharedRoute(TimeStampedModel):
    class Status(models.TextChoices):
        ACTIVE = "active", "Active"
        COMPLETED = "completed", "Completed"
        REVOKED = "revoked", "Revoked"
        EXPIRED = "expired", "Expired"

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="shared_routes",
    )
    contact = models.ForeignKey(
        EmergencyContact,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="shared_routes",
    )
    name = models.CharField(max_length=140, blank=True)
    nodes = models.JSONField(
        help_text="Ordered route nodes as [{'latitude': -6.8, 'longitude': 39.2}, ...]."
    )
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.ACTIVE)
    share_token = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    starts_at = models.DateTimeField(default=timezone.now)
    expires_at = models.DateTimeField(null=True, blank=True)
    revoked_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        indexes = [
            models.Index(fields=["owner", "status"]),
            models.Index(fields=["share_token", "status"]),
        ]

    def clean(self) -> None:
        super().clean()
        if not isinstance(self.nodes, list) or len(self.nodes) < 2:
            raise ValidationError({"nodes": "A shared route requires at least two coordinate nodes."})
        for index, node in enumerate(self.nodes):
            if not isinstance(node, dict):
                raise ValidationError({"nodes": f"Node {index} must be an object."})
            lat = node.get("latitude", node.get("lat"))
            lng = node.get("longitude", node.get("lng"))
            try:
                lat_decimal = Decimal(str(lat))
                lng_decimal = Decimal(str(lng))
            except (InvalidOperation, TypeError):
                raise ValidationError({"nodes": f"Node {index} has invalid coordinates."}) from None
            if not Decimal("-90") <= lat_decimal <= Decimal("90"):
                raise ValidationError({"nodes": f"Node {index} latitude is outside -90..90."})
            if not Decimal("-180") <= lng_decimal <= Decimal("180"):
                raise ValidationError({"nodes": f"Node {index} longitude is outside -180..180."})

    def revoke(self) -> None:
        self.status = self.Status.REVOKED
        self.revoked_at = timezone.now()
        self.save(update_fields=["status", "revoked_at", "updated_at"])

    def __str__(self) -> str:
        return self.name or f"Route {self.share_token}"


class LiveTrackingSession(TimeStampedModel):
    class Status(models.TextChoices):
        ACTIVE = "active", "Active"
        ENDED = "ended", "Ended"
        REVOKED = "revoked", "Revoked"

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="live_tracking_sessions",
    )
    contact = models.ForeignKey(
        EmergencyContact,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="live_tracking_sessions",
    )
    route = models.ForeignKey(
        SharedRoute,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="live_tracking_sessions",
    )
    session_token = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.ACTIVE)
    last_latitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        null=True,
        blank=True,
        validators=LATITUDE_VALIDATORS,
    )
    last_longitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        null=True,
        blank=True,
        validators=LONGITUDE_VALIDATORS,
    )
    started_at = models.DateTimeField(default=timezone.now)
    ended_at = models.DateTimeField(null=True, blank=True)
    revoked_at = models.DateTimeField(null=True, blank=True)
    metadata = models.JSONField(default=dict, blank=True)

    class Meta:
        indexes = [
            models.Index(fields=["owner", "status"]),
            models.Index(fields=["session_token", "status"]),
        ]

    @property
    def group_name(self) -> str:
        return f"live_tracking_{self.session_token}"

    def touch_location(self, latitude: Decimal, longitude: Decimal) -> None:
        self.last_latitude = latitude
        self.last_longitude = longitude
        self.save(update_fields=["last_latitude", "last_longitude", "updated_at"])

    def revoke(self) -> None:
        self.status = self.Status.REVOKED
        self.revoked_at = timezone.now()
        self.save(update_fields=["status", "revoked_at", "updated_at"])

    def end(self) -> None:
        self.status = self.Status.ENDED
        self.ended_at = timezone.now()
        self.save(update_fields=["status", "ended_at", "updated_at"])

    def __str__(self) -> str:
        return f"{self.owner} live session {self.session_token}"
