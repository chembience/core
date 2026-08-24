import os
from pathlib import Path

from setuptools import setup, find_packages


def read_version() -> str:
    """Read the release version from the source tree or a core-image copy."""
    for version_file in (Path(__file__).resolve().parents[1] / "VERSION", Path("/opt/VERSION")):
        if version_file.is_file():
            value = version_file.read_text(encoding="utf-8").strip()
            if value:
                return value
    return os.environ.get("CHEMBIENCE_VERSION", "0.0.0+unknown")


VERSION = read_version()

setup(
    name="chembience",
    version=VERSION,
    packages=find_packages(),
    install_requires=[
        "sqlalchemy",
        "psycopg2-binary",
    ],
)
