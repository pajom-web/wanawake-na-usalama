from rest_framework.permissions import BasePermission


class IsActivePoliceOfficer(BasePermission):
    message = "An active registered police account is required."

    def has_permission(self, request, view):
        user = request.user
        if not user or not user.is_authenticated or not user.is_active:
            return False
        profile = getattr(user, "police_profile", None)
        return profile is not None and profile.active


class IsCentralPoliceOfficer(IsActivePoliceOfficer):
    message = "Only an active Central Police account can manage safety tips."

    def has_permission(self, request, view):
        if not super().has_permission(request, view):
            return False
        return request.user.police_profile.can_manage_safety_tips
