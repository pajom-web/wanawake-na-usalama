from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import django.utils.timezone


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("incidents", "0006_incident_resolution_audit"),
    ]

    operations = [
        migrations.CreateModel(
            name="SafetyTip",
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
                ("title", models.CharField(max_length=140)),
                ("body", models.TextField()),
                ("category", models.CharField(blank=True, max_length=80)),
                ("is_active", models.BooleanField(default=True)),
                ("display_order", models.PositiveIntegerField(default=0)),
                ("published_at", models.DateTimeField(default=django.utils.timezone.now)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "updated_by",
                    models.ForeignKey(
                        blank=True,
                        null=True,
                        on_delete=django.db.models.deletion.SET_NULL,
                        related_name="updated_safety_tips",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={"ordering": ["display_order", "-published_at"]},
        ),
        migrations.AddIndex(
            model_name="safetytip",
            index=models.Index(
                fields=["is_active", "display_order", "published_at"],
                name="inc_tip_active_order_idx",
            ),
        ),
    ]
