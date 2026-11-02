"""add coach message trace

Revision ID: b3c4d5e6f7a8
Revises: a2b3c4d5e6f7
Create Date: 2026-10-16 21:00:00.000000+00:00

"""

from alembic import op
import sqlalchemy as sa

revision = "b3c4d5e6f7a8"
down_revision = "a2b3c4d5e6f7"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("coach_messages", sa.Column("trace_json", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("coach_messages", "trace_json")
