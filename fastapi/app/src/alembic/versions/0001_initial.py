"""Create the initial molecule schema.

Revision ID: 0001_initial
Revises:
"""

from alembic import op
import sqlalchemy as sa
from razi.rdkit_postgresql.types import Mol


revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None


def _ensure_index(inspector, name, columns, unique=False):
    indexes = {item["name"]: item for item in inspector.get_indexes("molecules")}
    existing = indexes.get(name)
    if existing is None:
        op.create_index(name, "molecules", columns, unique=unique)
        return
    if list(existing["column_names"]) != columns or bool(existing["unique"]) != unique:
        raise RuntimeError(f"Existing index {name!r} does not match the expected schema")


def upgrade():
    op.execute("CREATE EXTENSION IF NOT EXISTS rdkit")
    bind = op.get_bind()
    inspector = sa.inspect(bind)

    if not inspector.has_table("molecules"):
        op.create_table(
            "molecules",
            sa.Column("id", sa.Integer(), nullable=False),
            sa.Column("smiles", sa.String(), nullable=True),
            sa.Column("m", Mol(), nullable=True),
            sa.PrimaryKeyConstraint("id"),
        )
        inspector = sa.inspect(bind)
    else:
        columns = {item["name"] for item in inspector.get_columns("molecules")}
        missing = {"id", "smiles", "m"} - columns
        if missing:
            raise RuntimeError(
                "Cannot baseline existing molecules table; missing columns: "
                + ", ".join(sorted(missing))
            )

    _ensure_index(inspector, "ix_molecules_id", ["id"])
    _ensure_index(inspector, "ix_molecules_m", ["m"])
    _ensure_index(inspector, "ix_molecules_smiles", ["smiles"], unique=True)


def downgrade():
    op.drop_index("ix_molecules_smiles", table_name="molecules")
    op.drop_index("ix_molecules_m", table_name="molecules")
    op.drop_index("ix_molecules_id", table_name="molecules")
    op.drop_table("molecules")
