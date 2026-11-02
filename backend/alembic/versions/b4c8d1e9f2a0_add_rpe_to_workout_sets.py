"""add rpe to workout sets

Revision ID: b4c8d1e9f2a0
Revises: e7e7e402e566
Create Date: 2026-09-10 19:00:00.000000+00:00

"""

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision = "b4c8d1e9f2a0"
down_revision = "e738a2e88265"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "workout_sets",
        sa.Column("rpe", sa.Float(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("workout_sets", "rpe")
