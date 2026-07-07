from django import forms
from django.contrib import admin
from django.contrib.auth import get_user_model
from django.core.exceptions import ValidationError

from .models import (
    Hotspot,
    IncidentReport,
    PatrolAsset,
    PoliceOfficer,
    SafetyTip,
    UserProfile,
)


class PoliceOfficerAdminForm(forms.ModelForm):
    username = forms.CharField(
        max_length=150,
        help_text="Username the officer enters in the police dashboard.",
    )
    email = forms.EmailField(required=False)
    password1 = forms.CharField(
        label="Password",
        widget=forms.PasswordInput(render_value=False),
        required=False,
        help_text="Required for a new officer. Leave blank to keep the current password.",
    )
    password2 = forms.CharField(
        label="Confirm password",
        widget=forms.PasswordInput(render_value=False),
        required=False,
    )

    class Meta:
        model = PoliceOfficer
        fields = [
            "username",
            "email",
            "password1",
            "password2",
            "full_name",
            "badge_number",
            "rank",
            "station",
            "unit",
            "phone_number",
            "active",
        ]

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        if self.instance.pk:
            self.fields["username"].initial = self.instance.user.username
            self.fields["email"].initial = self.instance.user.email

    def clean_username(self):
        username = self.cleaned_data["username"].strip()
        user_model = get_user_model()
        existing = user_model.objects.filter(username__iexact=username).first()
        if self.instance.pk:
            if existing and existing.pk != self.instance.user_id:
                raise ValidationError("That username is already in use.")
            return username
        if existing:
            if existing.is_staff or existing.is_superuser:
                raise ValidationError("That username belongs to an admin account.")
            if hasattr(existing, "police_profile"):
                raise ValidationError("That police username is already registered.")
        return username

    def clean(self):
        cleaned_data = super().clean()
        password1 = cleaned_data.get("password1")
        password2 = cleaned_data.get("password2")
        if not self.instance.pk and not password1:
            self.add_error("password1", "A password is required for a new officer.")
        if password1 != password2:
            self.add_error("password2", "The passwords do not match.")
        return cleaned_data


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ["user", "display_name", "phone_number", "is_safety_verified", "created_at"]
    search_fields = ["user__username", "display_name", "phone_number"]


@admin.register(PoliceOfficer)
class PoliceOfficerAdmin(admin.ModelAdmin):
    form = PoliceOfficerAdminForm
    fields = (
        "username",
        "email",
        "password1",
        "password2",
        "full_name",
        "badge_number",
        "rank",
        "station",
        "unit",
        "phone_number",
        "active",
    )
    list_display = (
        "badge_number",
        "full_name",
        "username",
        "rank",
        "station",
        "unit",
        "active",
    )
    list_filter = ("active", "rank", "station", "unit")
    search_fields = (
        "badge_number",
        "full_name",
        "station",
        "unit",
        "user__username",
        "user__email",
    )

    @admin.display(ordering="user__username")
    def username(self, obj):
        return obj.user.username

    def save_model(self, request, obj, form, change):
        user_model = get_user_model()
        username = form.cleaned_data["username"]
        if change:
            user = obj.user
        else:
            user = user_model.objects.filter(username__iexact=username).first()
            if user is None:
                user = user_model(username=username)

        user.username = username
        user.email = form.cleaned_data.get("email", "")
        user.is_active = obj.active
        user.is_staff = False
        user.is_superuser = False
        password = form.cleaned_data.get("password1")
        if password:
            user.set_password(password)
        user.save()

        obj.user = user
        super().save_model(request, obj, form, change)


@admin.register(IncidentReport)
class IncidentReportAdmin(admin.ModelAdmin):
    list_display = [
        "id",
        "category",
        "status",
        "severity",
        "risk_level",
        "source",
        "latitude",
        "longitude",
        "occurred_at",
        "is_verified",
    ]
    list_filter = ["status", "severity", "category", "risk_level", "source", "is_verified"]
    search_fields = [
        "anonymous_token",
        "title",
        "description",
        "reporter_phone",
        "device_id",
        "reporter__username",
        "solved_by_name",
        "solved_by_station",
    ]
    readonly_fields = [
        "solved_by",
        "solved_by_name",
        "solved_by_badge_number",
        "solved_by_station",
        "solved_at",
        "created_at",
        "updated_at",
    ]


@admin.register(Hotspot)
class HotspotAdmin(admin.ModelAdmin):
    list_display = [
        "title",
        "risk_level",
        "center_latitude",
        "center_longitude",
        "radius_meters",
        "active",
        "created_at",
    ]
    list_filter = ["risk_level", "active", "created_at"]
    search_fields = ["title", "notes"]
    readonly_fields = ["created_at", "updated_at"]


@admin.register(PatrolAsset)
class PatrolAssetAdmin(admin.ModelAdmin):
    list_display = ["name", "status", "latitude", "longitude", "active", "updated_at"]
    list_filter = ["status", "active", "updated_at"]
    search_fields = ["name", "notes"]
    readonly_fields = ["created_at", "updated_at", "updated_by"]


@admin.register(SafetyTip)
class SafetyTipAdmin(admin.ModelAdmin):
    list_display = ["title", "category", "is_active", "display_order", "published_at"]
    list_filter = ["is_active", "category"]
    search_fields = ["title", "body", "category"]
    ordering = ["display_order", "-published_at"]
