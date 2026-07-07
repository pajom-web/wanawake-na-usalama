from collections import defaultdict

from django.db import migrations, models


def create_hotspots_for_existing_incidents(apps, schema_editor):
    Incident = apps.get_model("incidents", "Incident")
    Hotspot = apps.get_model("incidents", "Hotspot")
    cells = defaultdict(list)

    for incident in Incident.objects.all().iterator():
        cell_latitude = round(incident.latitude, 3)
        cell_longitude = round(incident.longitude, 3)
        location_key = f"{cell_latitude:.3f}:{cell_longitude:.3f}"
        cells[location_key].append((incident.latitude, incident.longitude))

    for location_key, coordinates in cells.items():
        incident_count = len(coordinates)
        if incident_count <= 5:
            continue
        Hotspot.objects.create(
            title="Automatically detected risk zone",
            center_latitude=sum(point[0] for point in coordinates) / incident_count,
            center_longitude=sum(point[1] for point in coordinates) / incident_count,
            radius_meters=100,
            risk_level="HIGH" if incident_count > 10 else "LOW",
            source="AUTOMATIC",
            incident_count=incident_count,
            location_key=location_key,
            notes="Generated from repeated incident reports in this location.",
        )


class Migration(migrations.Migration):
    dependencies = [("incidents", "0007_safety_tip")]

    operations = [
        migrations.AddField(
            model_name="hotspot",
            name="incident_count",
            field=models.PositiveIntegerField(default=0),
        ),
        migrations.AddField(
            model_name="hotspot",
            name="location_key",
            field=models.CharField(
                blank=True,
                editable=False,
                max_length=64,
                null=True,
                unique=True,
            ),
        ),
        migrations.AddField(
            model_name="hotspot",
            name="source",
            field=models.CharField(
                choices=[
                    ("MANUAL", "Police added"),
                    ("AUTOMATIC", "Automatically detected"),
                ],
                db_index=True,
                default="MANUAL",
                max_length=24,
            ),
        ),
        migrations.RunPython(
            create_hotspots_for_existing_incidents,
            migrations.RunPython.noop,
        ),
    ]
