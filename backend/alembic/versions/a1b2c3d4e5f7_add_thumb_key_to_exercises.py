"""add thumb_key to exercises

Revision ID: a1b2c3d4e5f7
Revises: f9b2c3d4e5a6
Create Date: 2026-10-13 12:00:00.000000+00:00

"""

from alembic import op
import sqlalchemy as sa
import sqlmodel

revision = "a1b2c3d4e5f7"
down_revision = "f9b2c3d4e5a6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "exercises",
        sa.Column(
            "thumb_key", sqlmodel.sql.sqltypes.AutoString(length=500), nullable=True
        ),
    )


def downgrade() -> None:
    op.drop_column("exercises", "thumb_key")
