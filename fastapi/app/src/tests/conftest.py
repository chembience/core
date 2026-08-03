import re
import uuid
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

from chembience.db import SQLALCHEMY_DATABASE_URL


TEST_DATABASE_PREFIX = "chembience_test_"


def _test_database_name():
    return f"{TEST_DATABASE_PREFIX}{uuid.uuid4().hex}"


def _quoted_test_database(name):
    if not name.startswith(TEST_DATABASE_PREFIX) or not re.fullmatch(r"[a-z0-9_]+", name):
        raise RuntimeError(f"Refusing to manage unsafe test database name: {name!r}")
    return f'"{name}"'


@pytest.fixture(scope="session")
def migrated_test_engine():
    database_name = _test_database_name()
    quoted_database = _quoted_test_database(database_name)
    admin_engine = create_engine(
        SQLALCHEMY_DATABASE_URL.set(database="postgres"),
        isolation_level="AUTOCOMMIT",
    )
    test_engine = None
    database_created = False

    try:
        with admin_engine.connect() as connection:
            connection.exec_driver_sql(f"CREATE DATABASE {quoted_database}")
        database_created = True

        test_engine = create_engine(SQLALCHEMY_DATABASE_URL.set(database=database_name))
        alembic_config = Config(str(Path(__file__).resolve().parents[1] / "alembic.ini"))
        with test_engine.connect() as connection:
            alembic_config.attributes["connection"] = connection
            command.upgrade(alembic_config, "head")

        yield test_engine
    finally:
        if test_engine is not None:
            test_engine.dispose()
        if database_created:
            with admin_engine.connect() as connection:
                connection.execute(
                    text(
                        "SELECT pg_terminate_backend(pid) FROM pg_stat_activity "
                        "WHERE datname = :database_name AND pid <> pg_backend_pid()"
                    ),
                    {"database_name": database_name},
                )
                connection.exec_driver_sql(f"DROP DATABASE IF EXISTS {quoted_database}")
        admin_engine.dispose()


@pytest.fixture(scope="session")
def db_session(migrated_test_engine):
    session = sessionmaker(bind=migrated_test_engine)()
    try:
        yield session
    finally:
        session.close()
