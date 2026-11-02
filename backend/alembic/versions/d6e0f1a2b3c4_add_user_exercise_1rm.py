"""add user exercise estimated 1RM

Revision ID: d6e0f1a2b3c4
Revises: c5d9e2f0a3b1
Create Date: 2026-09-11 11:05:00.000000+00:00

"""

from alembic import op
import sqlalchemy as sa
import sqlmodel

revision = "d6e0f1a2b3c4"
down_revision = "c5d9e2f0a3b1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "user_exercise_1rm",
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("exercise_id", sa.Integer(), nullable=False),
        sa.Column("estimated_kg", sa.Float(), nullable=False),
        sa.Column("samples", sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["exercise_id"], ["exercises.id"]),
        sa.PrimaryKeyConstraint("user_id", "exercise_id"),
    )


def downgrade() -> None:
    op.drop_table("user_exercise_1rm")
