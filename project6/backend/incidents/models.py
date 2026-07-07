import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone


class PoliceOfficer(models.Model):
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
    rank = models.CharField(
        max_length=32,
        choices=Rank.choices,
        default=Rank.CONSTABLE,
    )
    station = models.CharField(max_length=160)
    unit = models.CharField(max_length=120, blank=True)
    phone_number = models.CharField(max_length=32, blank=True)
    active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["full_name", "badge_number"]

    def __str__(self) -> str:
        return f"{self.badge_number} - {self.full_name}"

    @property
    def can_view_resolution_details(self) -> bool:
        station = self.station.casefold()
        unit = self.unit.casefold()
        return "central police" in station or "central police" in unit

    @property
    def can_manage_safety_tips(self) -> bool:
        return self.can_view_resolution_details


class Incident(models.Model):
    class Source(models.TextChoices):
        CITIZEN_APP = "CITIZEN_APP", "Citizen app"
        IOT_BUTTON = "IOT_BUTTON", "IoT panic button"

    class Category(models.TextChoices):
        SOS = "SOS", "SOS"
        HARASSMENT = "HARASSMENT", "Harassment"
        STALKING = "STALKING", "Stalking"
        MEDICAL = "MEDICAL", "Medical"
        OTHER = "OTHER", "Other"

    class Status(models.TextChoices):
        REPORTED = "REPORTED", "Reported"
        ACKNOWLEDGED = "ACKNOWLEDGED", "Acknowledged"
        DISPATCHED = "DISPATCHED", "Dispatched"
        RESOLVED = "RESOLVED", "Resolved"
        FALSE_ALARM = "FALSE_ALARM", "False alarm"

    class Severity(models.TextChoices):
        LOW = "LOW", "Low"
        MEDIUM = "MEDIUM", "Medium"
        HIGH = "HIGH", "High"
        CRITICAL = "CRITICAL", "Critical"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    anonymous_token = models.CharField(max_length=80, db_index=True)
    category = models.CharField(
        max_length=24, choices=Category.choices, default=Category.SOS
    )
    status = models.CharField(
        max_length=24, choices=Status.choices, default=Status.REPORTED
    )
    severity = models.CharField(
        max_length=24, choices=Severity.choices, default=Severity.CRITICAL
    )
    latitude = models.FloatField()
    longitude = models.FloatField()
    description = models.TextField(blank=True)
    reporter_phone = models.CharField(max_length=32, blank=True)
    assigned_unit = models.CharField(max_length=120, blank=True)
    police_notes = models.TextField(blank=True)
    solved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="solved_incidents",
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
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["status", "created_at"]),
            models.Index(fields=["latitude", "longitude"]),
            models.Index(
                fields=["source", "pressed_at"],
                name="inc_i_source_pressed_idx",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.category} {self.status} at {self.latitude}, {self.longitude}"


class Hotspot(models.Model):
    class RiskLevel(models.TextChoices):
        LOW = "LOW", "Low"
        HIGH = "HIGH", "High"

    class Source(models.TextChoices):
        MANUAL = "MANUAL", "Police added"
        AUTOMATIC = "AUTOMATIC", "Automatically detected"

    title = models.CharField(max_length=160)
    center_latitude = models.FloatField()
    center_longitude = models.FloatField()
    radius_meters = models.PositiveIntegerField()
    risk_level = models.CharField(
        max_length=24, choices=RiskLevel.choices, default=RiskLevel.HIGH
    )
    source = models.CharField(
        max_length=24,
        choices=Source.choices,
        default=Source.MANUAL,
        db_index=True,
    )
    incident_count = models.PositiveIntegerField(default=0)
    location_key = models.CharField(
        max_length=64,
        null=True,
        blank=True,
        unique=True,
        editable=False,
    )
    active = models.BooleanField(default=True)
    notes = models.TextField(blank=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="created_hotspots",
    )
    expires_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["active", "risk_level"]),
            models.Index(fields=["center_latitude", "center_longitude"]),
        ]

    def __str__(self) -> str:
        return self.title


class PatrolAsset(models.Model):
    class Status(models.TextChoices):
        AVAILABLE = "AVAILABLE", "Available"
        DEPLOYED = "DEPLOYED", "Deployed"
        OFFLINE = "OFFLINE", "Offline"

    name = models.CharField(max_length=120, unique=True)
    latitude = models.FloatField()
    longitude = models.FloatField()
    status = models.CharField(
        max_length=24,
        choices=Status.choices,
        default=Status.AVAILABLE,
    )
    active = models.BooleanField(default=True)
    notes = models.TextField(blank=True)
    updated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="updated_patrol_assets",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["name"]
        indexes = [
            models.Index(fields=["active", "status"]),
            models.Index(fields=["latitude", "longitude"]),
        ]

    def __str__(self) -> str:
        return self.name


class SafetyTip(models.Model):
    title = models.CharField(max_length=140)
    body = models.TextField()
    category = models.CharField(max_length=80, blank=True)
    is_active = models.BooleanField(default=True)
    display_order = models.PositiveIntegerField(default=0)
    published_at = models.DateTimeField(default=timezone.now)
    updated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="updated_safety_tips",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["display_order", "-published_at"]
        indexes = [
            models.Index(
                fields=["is_active", "display_order", "published_at"],
                name="inc_tip_active_order_idx",
            ),
        ]

    def __str__(self) -> str:
        return self.title
