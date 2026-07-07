import django.utils.timezone
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("safety", "0001_initial"),
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
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("title", models.CharField(max_length=140)),
                ("body", models.TextField()),
                ("category", models.CharField(blank=True, max_length=80)),
                ("is_active", models.BooleanField(default=True)),
                ("display_order", models.PositiveIntegerField(default=0)),
                ("published_at", models.DateTimeField(default=django.utils.timezone.now)),
            ],
            options={
                "ordering": ["display_order", "-published_at"],
            },
        ),
        migrations.AddIndex(
            model_name="safetytip",
            index=models.Index(
                fields=["is_active", "display_order", "published_at"],
                name="safety_safe_is_acti_53aef6_idx",
            ),
        ),
    ]
