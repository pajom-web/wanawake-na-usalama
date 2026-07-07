import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("incidents", "0001_initial"),
    ]

    operations = [
        migrations.CreateModel(
            name="PoliceOfficer",
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
                ("full_name", models.CharField(max_length=160)),
                ("badge_number", models.CharField(max_length=40, unique=True)),
                (
                    "rank",
                    models.CharField(
                        choices=[
                            ("CONSTABLE", "Constable"),
                            ("SERGEANT", "Sergeant"),
                            ("INSPECTOR", "Inspector"),
                            ("SUPERINTENDENT", "Superintendent"),
                            ("COMMANDER", "Commander"),
                        ],
                        default="CONSTABLE",
                        max_length=32,
                    ),
                ),
                ("station", models.CharField(max_length=160)),
                ("unit", models.CharField(blank=True, max_length=120)),
                ("phone_number", models.CharField(blank=True, max_length=32)),
                ("active", models.BooleanField(default=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "user",
                    models.OneToOneField(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="police_profile",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "ordering": ["full_name", "badge_number"],
            },
        ),
    ]
