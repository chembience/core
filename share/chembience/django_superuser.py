"""Create or update the configured Django superuser in a prepared app."""

from __future__ import annotations

import os
from collections.abc import Mapping


_INSECURE_PASSWORDS = {
    "change-me-immediately",
    "secure-password-here",
    "CHANGE_ME_BEFORE_RUNNING",
    "django-insecure-default-change-me-in-production",
}


def configuration(environ: Mapping[str, str] | None = None) -> tuple[str, str, str]:
    """Return validated administrator credentials without exposing the password."""

    values = os.environ if environ is None else environ
    username = values.get("DJANGO_SUPERUSER_USERNAME", "").strip()
    email = values.get("DJANGO_SUPERUSER_EMAIL", "").strip()
    password = values.get("DJANGO_SUPERUSER_PASSWORD", "")

    if not username:
        raise SystemExit("DJANGO_SUPERUSER_USERNAME must be set in production")
    if not email:
        raise SystemExit("DJANGO_SUPERUSER_EMAIL must be set in production")
    if not password or password.strip() in _INSECURE_PASSWORDS:
        raise SystemExit(
            "DJANGO_SUPERUSER_PASSWORD must be set to a non-placeholder value in production"
        )
    return username, email, password


def ensure_superuser() -> bool:
    """Create/update the configured superuser and return whether it was created."""

    username, email, password = configuration()

    import django
    from django.contrib.auth import get_user_model

    django.setup()
    user_model = get_user_model()
    lookup = {user_model.USERNAME_FIELD: username}
    defaults: dict[str, object] = {"is_staff": True, "is_superuser": True}
    if any(field.name == "email" for field in user_model._meta.fields):
        defaults["email"] = email

    user, created = user_model._default_manager.get_or_create(**lookup, defaults=defaults)
    if hasattr(user, "email"):
        user.email = email
    user.is_staff = True
    user.is_superuser = True
    user.set_password(password)
    user.save()
    return created


def main() -> None:
    created = ensure_superuser()
    print("Superuser created" if created else "Superuser updated")


if __name__ == "__main__":  # pragma: no cover - exercised by container command
    main()
