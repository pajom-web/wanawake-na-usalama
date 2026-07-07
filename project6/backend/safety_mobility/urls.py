from django.contrib import admin
from django.urls import path

from incidents import views

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/health/", views.HealthView.as_view(), name="health"),
    path("api/auth/register/", views.MobileRegistrationView.as_view(), name="mobile-register"),
    path("api/auth/login/", views.MobileLoginView.as_view(), name="mobile-login"),
    path("api/auth/me/", views.MobileMeView.as_view(), name="mobile-me"),
    path("api/auth/logout/", views.MobileLogoutView.as_view(), name="mobile-logout"),
    path("api/incidents/", views.PublicIncidentCreateView.as_view(), name="incident-create"),
    path(
        "api/iot/danger-alerts/",
        views.IotDangerAlertView.as_view(),
        name="iot-danger-alert",
    ),
    path(
        "api/incidents/status/<str:anonymous_token>/",
        views.PublicIncidentStatusView.as_view(),
        name="incident-status",
    ),
    path("api/hotspots/", views.PublicHotspotListView.as_view(), name="hotspot-list"),
    path(
        "api/safety-tips/",
        views.MobileSafetyTipListView.as_view(),
        name="safety-tip-list",
    ),
    path("api/police/login/", views.PoliceLoginView.as_view(), name="police-login"),
    path("api/police/logout/", views.PoliceLogoutView.as_view(), name="police-logout"),
    path("api/police/me/", views.PoliceMeView.as_view(), name="police-me"),
    path(
        "api/police/incidents/",
        views.PoliceIncidentListView.as_view(),
        name="police-incident-list",
    ),
    path(
        "api/police/incidents/<uuid:pk>/",
        views.PoliceIncidentDetailView.as_view(),
        name="police-incident-detail",
    ),
    path(
        "api/police/hotspots/",
        views.PoliceHotspotListCreateView.as_view(),
        name="police-hotspot-list",
    ),
    path(
        "api/police/hotspots/<int:pk>/",
        views.PoliceHotspotDetailView.as_view(),
        name="police-hotspot-detail",
    ),
    path(
        "api/police/patrol-assets/",
        views.PolicePatrolAssetListCreateView.as_view(),
        name="police-patrol-asset-list",
    ),
    path(
        "api/police/patrol-assets/<int:pk>/",
        views.PolicePatrolAssetDetailView.as_view(),
        name="police-patrol-asset-detail",
    ),
    path(
        "api/police/safety-tips/",
        views.PoliceSafetyTipListCreateView.as_view(),
        name="police-safety-tip-list",
    ),
    path(
        "api/police/safety-tips/<int:pk>/",
        views.PoliceSafetyTipDetailView.as_view(),
        name="police-safety-tip-detail",
    ),
]
