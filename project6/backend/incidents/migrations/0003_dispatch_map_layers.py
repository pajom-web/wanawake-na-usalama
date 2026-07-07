import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


def normalize_hotspot_risk_levels(apps, schema_editor):
    hotspot = apps.get_model("incidents", "Hotspot")
    hotspot.objects.filter(risk_level="MEDIUM").update(risk_level="LOW")
    hotspot.objects.filter(risk_level="CRITICAL").update(risk_level="HIGH")


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("incidents", "0002_policeofficer"),
    ]

    operations = [
        migrations.RunPython(normalize_hotspot_risk_levels, migrations.RunPython.noop),
        migrations.AlterField(
            model_name="hotspot",
            name="risk_level",
            field=models.CharField(
                choices=[("LOW", "Low"), ("HIGH", "High")],
                default="HIGH",
                max_length=24,
            ),
        ),
        migrations.CreateModel(
            name="PatrolAsset",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                ("name", models.CharField(max_length=120, unique=True)),
                ("latitude", models.FloatField()),
                ("longitude", models.FloatField()),
                (
                    "status",
                    models.CharField(
                        choices=[
                            ("AVAILABLE", "Available"),
                            ("DEPLOYED", "Deployed"),
                            ("OFFLINE", "Offline"),
                        ],
                        default="AVAILABLE",
                        max_length=24,
                    ),
                ),
                ("active", models.BooleanField(default=True)),
                ("notes", models.TextField(blank=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "updated_by",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="updated_patrol_assets",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={"ordering": ["name"]},
        ),
        migrations.AddIndex(
            model_name="patrolasset",
            index=models.Index(
                fields=["active", "status"],
                name="incidents_p_active_a82f80_idx",
            ),
        ),
        migrations.AddIndex(
            model_name="patrolasset",
            index=models.Index(
                fields=["latitude", "longitude"],
                name="incidents_p_latitud_e24ea0_idx",
            ),
        ),
    ]
