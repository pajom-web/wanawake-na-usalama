# Generated manually for the lightweight safety mobility system.
import uuid

import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="Incident",
            fields=[
                ("id", models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False)),
                ("anonymous_token", models.CharField(db_index=True, max_length=80)),
                ("category", models.CharField(choices=[("SOS", "SOS"), ("HARASSMENT", "Harassment"), ("STALKING", "Stalking"), ("MEDICAL", "Medical"), ("OTHER", "Other")], default="SOS", max_length=24)),
                ("status", models.CharField(choices=[("REPORTED", "Reported"), ("ACKNOWLEDGED", "Acknowledged"), ("DISPATCHED", "Dispatched"), ("RESOLVED", "Resolved"), ("FALSE_ALARM", "False alarm")], default="REPORTED", max_length=24)),
                ("severity", models.CharField(choices=[("LOW", "Low"), ("MEDIUM", "Medium"), ("HIGH", "High"), ("CRITICAL", "Critical")], default="CRITICAL", max_length=24)),
                ("latitude", models.FloatField()),
                ("longitude", models.FloatField()),
                ("description", models.TextField(blank=True)),
                ("reporter_phone", models.CharField(blank=True, max_length=32)),
                ("assigned_unit", models.CharField(blank=True, max_length=120)),
                ("police_notes", models.TextField(blank=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
            options={
                "ordering": ["-created_at"],
            },
        ),
        migrations.CreateModel(
            name="Hotspot",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("title", models.CharField(max_length=160)),
                ("center_latitude", models.FloatField()),
                ("center_longitude", models.FloatField()),
                ("radius_meters", models.PositiveIntegerField()),
                ("risk_level", models.CharField(choices=[("MEDIUM", "Medium"), ("HIGH", "High"), ("CRITICAL", "Critical")], default="HIGH", max_length=24)),
                ("active", models.BooleanField(default=True)),
                ("notes", models.TextField(blank=True)),
                ("expires_at", models.DateTimeField(blank=True, null=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("created_by", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="created_hotspots", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "ordering": ["-created_at"],
            },
        ),
        migrations.AddIndex(
            model_name="incident",
            index=models.Index(fields=["status", "created_at"], name="incidents_i_status_5d0930_idx"),
        ),
        migrations.AddIndex(
            model_name="incident",
            index=models.Index(fields=["latitude", "longitude"], name="incidents_i_latitud_53102f_idx"),
        ),
        migrations.AddIndex(
            model_name="hotspot",
            index=models.Index(fields=["active", "risk_level"], name="incidents_h_active_dcb693_idx"),
        ),
        migrations.AddIndex(
            model_name="hotspot",
            index=models.Index(fields=["center_latitude", "center_longitude"], name="incidents_h_center__9a49a2_idx"),
        ),
    ]
