from dataclasses import dataclass

from django.db import transaction
from django.db.models import Avg

from incidents.models import Hotspot, Incident


LOCATION_DECIMAL_PLACES = 3
AUTOMATIC_RADIUS_METERS = 100
LOW_RISK_REPORT_THRESHOLD = 5
HIGH_RISK_REPORT_THRESHOLD = 10


@dataclass(frozen=True)
class AutomaticHotspotChange:
    hotspot: Hotspot
    event: str


def _location_cell(latitude: float, longitude: float) -> tuple[str, float, float]:
    cell_latitude = round(latitude, LOCATION_DECIMAL_PLACES)
    cell_longitude = round(longitude, LOCATION_DECIMAL_PLACES)
    key = f"{cell_latitude:.3f}:{cell_longitude:.3f}"
    return key, cell_latitude, cell_longitude


def update_automatic_hotspot_for_incident(
    incident: Incident,
) -> AutomaticHotspotChange | None:
    """Create or update the automatic risk zone for an incident's ~100 m cell."""
    location_key, cell_latitude, cell_longitude = _location_cell(
        incident.latitude,
        incident.longitude,
    )
    half_cell = 0.5 * (10**-LOCATION_DECIMAL_PLACES)
    incidents = Incident.objects.filter(
        latitude__gte=cell_latitude - half_cell,
        latitude__lt=cell_latitude + half_cell,
        longitude__gte=cell_longitude - half_cell,
        longitude__lt=cell_longitude + half_cell,
    )
    incident_count = incidents.count()
    if incident_count <= LOW_RISK_REPORT_THRESHOLD:
        return None

    risk_level = (
        Hotspot.RiskLevel.HIGH
        if incident_count > HIGH_RISK_REPORT_THRESHOLD
        else Hotspot.RiskLevel.LOW
    )
    center = incidents.aggregate(
        latitude=Avg("latitude"),
        longitude=Avg("longitude"),
    )

    with transaction.atomic():
        hotspot = (
            Hotspot.objects.select_for_update()
            .filter(location_key=location_key, source=Hotspot.Source.AUTOMATIC)
            .first()
        )
        if hotspot is not None and not hotspot.active:
            # A police deletion is an intentional override of automation.
            return None

        created = hotspot is None
        if created:
            hotspot = Hotspot(
                title="Automatically detected risk zone",
                source=Hotspot.Source.AUTOMATIC,
                location_key=location_key,
                radius_meters=AUTOMATIC_RADIUS_METERS,
                notes="Generated from repeated incident reports in this location.",
            )

        hotspot.center_latitude = center["latitude"] or incident.latitude
        hotspot.center_longitude = center["longitude"] or incident.longitude
        hotspot.incident_count = incident_count
        hotspot.risk_level = risk_level
        hotspot.active = True
        hotspot.save()

    return AutomaticHotspotChange(
        hotspot=hotspot,
        event="hotspot.created" if created else "hotspot.updated",
    )
