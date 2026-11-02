"""add set_kind to workout sets

Revision ID: c1d2e3f4a5b6
Revises: a1b2c3d4e5f7
Create Date: 2026-10-15 12:00:00.000000+00:00

"""

from alembic import op
import sqlalchemy as sa

revision = "c1d2e3f4a5b6"
down_revision = "a1b2c3d4e5f7"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "workout_sets",
        sa.Column(
            "set_kind",
            sa.String(length=20),
            nullable=False,
            server_default="working",
        ),
    )


def downgrade() -> None:
    op.drop_column("workout_sets", "set_kind")
