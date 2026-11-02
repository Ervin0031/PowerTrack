"""add user recovery factors

Revision ID: e8a1b2c3d4e5
Revises: d6e0f1a2b3c4
Create Date: 2026-09-11 16:30:00.000000+00:00

"""

from alembic import op
import sqlalchemy as sa
import sqlmodel

revision = "e8a1b2c3d4e5"
down_revision = "d6e0f1a2b3c4"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "user_recovery_factors",
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("muscle_group_id", sa.Integer(), nullable=False),
        sa.Column("factor", sa.Float(), nullable=False),
        sa.Column("observations", sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column("last_effective_at", sa.DateTime(), nullable=True),
        sa.Column("last_effective_1rm", sa.Float(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("user_id", "muscle_group_id"),
    )


def downgrade() -> None:
    op.drop_table("user_recovery_factors")
