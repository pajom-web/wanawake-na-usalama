from decimal import Decimal

from django.conf import settings
import django.core.validators
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("safety", "0002_safetytip"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="PoliceOfficer",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("full_name", models.CharField(max_length=160)),
                ("badge_number", models.CharField(max_length=40, unique=True)),
                ("rank", models.CharField(choices=[("CONSTABLE", "Constable"), ("SERGEANT", "Sergeant"), ("INSPECTOR", "Inspector"), ("SUPERINTENDENT", "Superintendent"), ("COMMANDER", "Commander")], default="CONSTABLE", max_length=32)),
                ("station", models.CharField(max_length=160)),
                ("unit", models.CharField(blank=True, max_length=120)),
                ("phone_number", models.CharField(blank=True, max_length=32)),
                ("active", models.BooleanField(default=True)),
                ("user", models.OneToOneField(on_delete=django.db.models.deletion.CASCADE, related_name="police_profile", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "ordering": ["full_name", "badge_number"],
            },
        ),
        migrations.CreateModel(
            name="Hotspot",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("title", models.CharField(max_length=160)),
                ("center_latitude", models.FloatField()),
                ("center_longitude", models.FloatField()),
                ("radius_meters", models.PositiveIntegerField()),
                ("risk_level", models.CharField(choices=[("LOW", "Low"), ("HIGH", "High")], default="HIGH", max_length=24)),
                ("active", models.BooleanField(default=True)),
                ("notes", models.TextField(blank=True)),
                ("expires_at", models.DateTimeField(null=True, blank=True)),
                ("created_by", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="created_safety_hotspots", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "ordering": ["-created_at"],
            },
        ),
        migrations.CreateModel(
            name="PatrolAsset",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("name", models.CharField(max_length=120, unique=True)),
                ("latitude", models.FloatField()),
                ("longitude", models.FloatField()),
                ("status", models.CharField(choices=[("AVAILABLE", "Available"), ("DEPLOYED", "Deployed"), ("OFFLINE", "Offline")], default="AVAILABLE", max_length=24)),
                ("active", models.BooleanField(default=True)),
                ("notes", models.TextField(blank=True)),
                ("updated_by", models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="updated_patrol_assets", to=settings.AUTH_USER_MODEL)),
            ],
            options={
                "ordering": ["name"],
            },
        ),
        migrations.AddField(
            model_name="incidentreport",
            name="anonymous_token",
            field=models.CharField(blank=True, db_index=True, max_length=80),
        ),
        migrations.AddField(
            model_name="incidentreport",
            name="assigned_unit",
            field=models.CharField(blank=True, max_length=120),
        ),
        migrations.AddField(
            model_name="incidentreport",
            name="device_id",
            field=models.CharField(blank=True, db_index=True, max_length=80),
        ),
        migrations.AddField(
            model_name="incidentreport",
            name="police_notes",
            field=models.TextField(blank=True),
        ),
        migrations.AddField(
            model_name="incidentreport",
            name="pressed_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="incidentreport",
            name="reporter_phone",
            field=models.CharField(blank=True, max_length=32),
        ),
        migrations.AddField(
            model_name="incidentreport",
            name="severity",
            field=models.CharField(choices=[("LOW", "Low"), ("MEDIUM", "Medium"), ("HIGH", "High"), ("CRITICAL", "Critical")], default="MEDIUM", max_length=24),
        ),
        migrations.AddField(
            model_name="incidentreport",
            name="solved_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="incidentreport",
            name="solved_by_badge_number",
            field=models.CharField(blank=True, max_length=40),
        ),
        migrations.AddField(
            model_name="incidentreport",
            name="solved_by_name",
            field=models.CharField(blank=True, max_length=160),
        ),
        migrations.AddField(
            model_name="incidentreport",
            name="solved_by_station",
            field=models.CharField(blank=True, max_length=160),
        ),
        migrations.AddField(
            model_name="incidentreport",
            name="source",
            field=models.CharField(choices=[("CITIZEN_APP", "Citizen app"), ("IOT_BUTTON", "IoT panic button")], db_index=True, default="CITIZEN_APP", max_length=32),
        ),
        migrations.AddField(
            model_name="incidentreport",
            name="status",
            field=models.CharField(choices=[("REPORTED", "Reported"), ("ACKNOWLEDGED", "Acknowledged"), ("DISPATCHED", "Dispatched"), ("RESOLVED", "Resolved"), ("FALSE_ALARM", "False alarm")], default="REPORTED", max_length=24),
        ),
        migrations.AddField(
            model_name="incidentreport",
            name="solved_by",
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name="solved_incident_reports", to=settings.AUTH_USER_MODEL),
        ),
        migrations.AlterField(
            model_name="incidentreport",
            name="latitude",
            field=models.DecimalField(decimal_places=6, max_digits=9, validators=[django.core.validators.MinValueValidator(Decimal("-90.000000")), django.core.validators.MaxValueValidator(Decimal("90.000000"))]),
        ),
        migrations.AlterField(
            model_name="incidentreport",
            name="longitude",
            field=models.DecimalField(decimal_places=6, max_digits=9, validators=[django.core.validators.MinValueValidator(Decimal("-180.000000")), django.core.validators.MaxValueValidator(Decimal("180.000000"))]),
        ),
        migrations.AddIndex(
            model_name="hotspot",
            index=models.Index(fields=["active", "risk_level"], name="safety_hots_active_a53f96_idx"),
        ),
        migrations.AddIndex(
            model_name="hotspot",
            index=models.Index(fields=["center_latitude", "center_longitude"], name="safety_hots_center__cd9a22_idx"),
        ),
        migrations.AddIndex(
            model_name="patrolasset",
            index=models.Index(fields=["active", "status"], name="safety_patr_active_cda8cd_idx"),
        ),
        migrations.AddIndex(
            model_name="patrolasset",
            index=models.Index(fields=["latitude", "longitude"], name="safety_patr_latitud_fdb624_idx"),
        ),
        migrations.AddIndex(
            model_name="incidentreport",
            index=models.Index(fields=["status", "created_at"], name="safety_inci_status_43162d_idx"),
        ),
        migrations.AddIndex(
            model_name="incidentreport",
            index=models.Index(fields=["source", "pressed_at"], name="safety_inci_source_12229e_idx"),
        ),
    ]
