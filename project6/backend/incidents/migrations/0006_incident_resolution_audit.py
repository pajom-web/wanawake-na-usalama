from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ("incidents", "0005_iot_incident_fields"),
    ]

    operations = [
        migrations.AddField(
            model_name="incident",
            name="solved_at",
            field=models.DateTimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name="incident",
            name="solved_by",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="solved_incidents",
                to=settings.AUTH_USER_MODEL,
            ),
        ),
        migrations.AddField(
            model_name="incident",
            name="solved_by_badge_number",
            field=models.CharField(blank=True, max_length=40),
        ),
        migrations.AddField(
            model_name="incident",
            name="solved_by_name",
            field=models.CharField(blank=True, max_length=160),
        ),
        migrations.AddField(
            model_name="incident",
            name="solved_by_station",
            field=models.CharField(blank=True, max_length=160),
        ),
    ]
