import os

from setuptools import setup, find_packages

# Single source of truth: prefer CHEMBIENCE_VERSION env var (set by docker-compose / CI),
# fall back to a sensible default for local installs.
VERSION = os.environ.get("CHEMBIENCE_VERSION", "0.5.0")

setup(
    name="chembience",
    version=VERSION,
    packages=find_packages(),
    install_requires=[
        "sqlalchemy",
        "psycopg2-binary",
    ],
)
