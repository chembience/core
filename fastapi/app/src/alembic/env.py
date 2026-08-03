from logging.config import fileConfig

from alembic import context
from razi.rdkit_postgresql.types import Mol

from chembience.db import Base, SQLALCHEMY_DATABASE_URL, engine
from db import schema  # noqa: F401 - register models with Base.metadata


config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def render_item(item_type, item, autogen_context):
    if item_type == "type" and isinstance(item, Mol):
        autogen_context.imports.add("from razi.rdkit_postgresql.types import Mol")
        return "Mol()"
    return False


def run_migrations_offline():
    url = SQLALCHEMY_DATABASE_URL.render_as_string(hide_password=False)
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
        render_item=render_item,
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online():
    supplied_connection = config.attributes.get("connection")
    if supplied_connection is not None:
        context.configure(
            connection=supplied_connection,
            target_metadata=target_metadata,
            compare_type=True,
            render_item=render_item,
        )
        with context.begin_transaction():
            context.run_migrations()
        return

    with engine.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
            render_item=render_item,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
