import importlib.util
import os
import sys
import types
import unittest
from pathlib import Path
from unittest.mock import patch


_MODULE_PATH = Path(__file__).parents[1] / "chembience" / "django_superuser.py"
_SPEC = importlib.util.spec_from_file_location("django_superuser", _MODULE_PATH)
assert _SPEC is not None and _SPEC.loader is not None
_MODULE = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(_MODULE)
configuration = _MODULE.configuration
ensure_superuser = _MODULE.ensure_superuser


class ConfigurationTests(unittest.TestCase):
    def test_accepts_non_placeholder_credentials(self):
        self.assertEqual(
            configuration(
                {
                    "DJANGO_SUPERUSER_USERNAME": "admin",
                    "DJANGO_SUPERUSER_EMAIL": "admin@example.org",
                    "DJANGO_SUPERUSER_PASSWORD": "correct-horse-battery-staple",
                }
            ),
            ("admin", "admin@example.org", "correct-horse-battery-staple"),
        )

    def test_rejects_missing_or_placeholder_password(self):
        base = {
            "DJANGO_SUPERUSER_USERNAME": "admin",
            "DJANGO_SUPERUSER_EMAIL": "admin@example.org",
        }
        for password in ("", "change-me-immediately", "secure-password-here"):
            with self.subTest(password=password):
                with self.assertRaises(SystemExit):
                    configuration({**base, "DJANGO_SUPERUSER_PASSWORD": password})

    def test_rejects_missing_username_or_email(self):
        for values in (
            {"DJANGO_SUPERUSER_EMAIL": "admin@example.org", "DJANGO_SUPERUSER_PASSWORD": "valid"},
            {"DJANGO_SUPERUSER_USERNAME": "admin", "DJANGO_SUPERUSER_PASSWORD": "valid"},
        ):
            with self.subTest(values=values):
                with self.assertRaises(SystemExit):
                    configuration(values)

    def test_creates_and_updates_a_superuser(self):
        class User:
            email = ""
            is_staff = False
            is_superuser = False

            def set_password(self, password):
                self.password = password

            def save(self):
                self.saved = True

        class Manager:
            def __init__(self):
                self.user = User()
                self.created = True

            def get_or_create(self, **kwargs):
                self.lookup = kwargs
                result = (self.user, self.created)
                self.created = False
                return result

        manager = Manager()
        user_model = type(
            "UserModel",
            (),
            {
                "USERNAME_FIELD": "username",
                "_default_manager": manager,
                "_meta": types.SimpleNamespace(fields=[types.SimpleNamespace(name="email")]),
            },
        )
        django = types.ModuleType("django")
        django.setup = lambda: None
        contrib = types.ModuleType("django.contrib")
        auth = types.ModuleType("django.contrib.auth")
        auth.get_user_model = lambda: user_model
        credentials = {
            "DJANGO_SUPERUSER_USERNAME": "admin",
            "DJANGO_SUPERUSER_EMAIL": "admin@example.org",
            "DJANGO_SUPERUSER_PASSWORD": "first-password",
        }

        with patch.dict(
            sys.modules,
            {"django": django, "django.contrib": contrib, "django.contrib.auth": auth},
        ), patch.dict(os.environ, credentials, clear=True):
            self.assertTrue(ensure_superuser())
            self.assertFalse(ensure_superuser())

        self.assertEqual(manager.lookup["username"], "admin")
        self.assertEqual(manager.user.email, "admin@example.org")
        self.assertEqual(manager.user.password, "first-password")
        self.assertTrue(manager.user.is_staff)
        self.assertTrue(manager.user.is_superuser)
