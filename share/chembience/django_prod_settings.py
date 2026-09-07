"""Production-only settings layered over a generated Chembience Django app.

The production Compose bundle sets ``DJANGO_SETTINGS_MODULE`` to this module.
Keeping the CSRF and proxy policy here means existing applications gain the
setting when they prepare a new production image; their project source does not
need to be rewritten merely to adopt a new core release.
"""

import os

from src.settings import *  # noqa: F403


CSRF_TRUSTED_ORIGINS = [
    origin.strip()
    for origin in os.environ.get("DJANGO_CSRF_TRUSTED_ORIGINS", "").split(",")
    if origin.strip()
]

if os.environ.get("DJANGO_TRUST_X_FORWARDED_PROTO", "False").lower() in (
    "1",
    "true",
    "yes",
    "on",
):
    SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
