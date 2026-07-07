from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import (
    EmergencyContactViewSet,
    HealthView,
    HotspotFetchView,
    IncidentListCreateView,
    LiveTrackingSessionViewSet,
    LoginView,
    LogoutView,
    PoliceHotspotDetailView,
    PoliceHotspotListCreateView,
    PoliceIncidentDetailView,
    PoliceIncidentListView,
    PoliceLoginView,
    PoliceLogoutView,
    PoliceMeView,
    PolicePatrolAssetDetailView,
    PolicePatrolAssetListCreateView,
    PublicIncidentStatusView,
    RegistrationView,
    SafetyTipListView,
    SharedRouteViewSet,
)

router = DefaultRouter()
router.register("contacts", EmergencyContactViewSet, basename="contacts")
router.register("routes", SharedRouteViewSet, basename="routes")
router.register("tracking-sessions", LiveTrackingSessionViewSet, basename="tracking-sessions")

urlpatterns = [
    path("health/", HealthView.as_view(), name="health"),
    path("auth/register/", RegistrationView.as_view(), name="register"),
    path("auth/login/", LoginView.as_view(), name="login"),
    path("auth/logout/", LogoutView.as_view(), name="logout"),
    path("incidents/", IncidentListCreateView.as_view(), name="incidents"),
    path(
        "incidents/status/<str:anonymous_token>/",
        PublicIncidentStatusView.as_view(),
        name="incident-status",
    ),
    path("hotspots/", HotspotFetchView.as_view(), name="hotspots"),
    path("police/login/", PoliceLoginView.as_view(), name="police-login"),
    path("police/logout/", PoliceLogoutView.as_view(), name="police-logout"),
    path("police/me/", PoliceMeView.as_view(), name="police-me"),
    path("police/incidents/", PoliceIncidentListView.as_view(), name="police-incident-list"),
    path(
        "police/incidents/<str:pk>/",
        PoliceIncidentDetailView.as_view(),
        name="police-incident-detail",
    ),
    path("police/hotspots/", PoliceHotspotListCreateView.as_view(), name="police-hotspot-list"),
    path(
        "police/hotspots/<int:pk>/",
        PoliceHotspotDetailView.as_view(),
        name="police-hotspot-detail",
    ),
    path(
        "police/patrol-assets/",
        PolicePatrolAssetListCreateView.as_view(),
        name="police-patrol-asset-list",
    ),
    path(
        "police/patrol-assets/<int:pk>/",
        PolicePatrolAssetDetailView.as_view(),
        name="police-patrol-asset-detail",
    ),
    path("safety-tips/", SafetyTipListView.as_view(), name="safety-tips"),
    path("", include(router.urls)),
]
