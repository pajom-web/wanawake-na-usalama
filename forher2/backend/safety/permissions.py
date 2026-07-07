from rest_framework.permissions import BasePermission


class IsActivePoliceOfficer(BasePermission):
    message = "An active registered police account is required."

    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated or not user.is_active:
            return False
        profile = getattr(user, "police_profile", None)
        return profile is not None and profile.active
