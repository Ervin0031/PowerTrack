"""add user fitness profile and weight logs

Revision ID: c5d9e2f0a3b1
Revises: b4c8d1e9f2a0
Create Date: 2026-09-11 10:50:00.000000+00:00

"""

from alembic import op
import sqlalchemy as sa
import sqlmodel

revision = "c5d9e2f0a3b1"
down_revision = "b4c8d1e9f2a0"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "user_profiles",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column(
            "gender", sqlmodel.sql.sqltypes.AutoString(length=20), nullable=False
        ),
        sa.Column("birth_year", sa.Integer(), nullable=False),
        sa.Column("height_cm", sa.Float(), nullable=False),
        sa.Column("weight_kg", sa.Float(), nullable=False),
        sa.Column("goal", sqlmodel.sql.sqltypes.AutoString(length=32), nullable=False),
        sa.Column(
            "experience", sqlmodel.sql.sqltypes.AutoString(length=32), nullable=False
        ),
        sa.Column("injury_tags", sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column("weekly_days", sa.Integer(), nullable=True),
        sa.Column("session_minutes", sa.Integer(), nullable=True),
        sa.Column("equipment", sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column("preferences", sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_user_profiles_user_id"), "user_profiles", ["user_id"], unique=True
    )

    op.create_table(
        "weight_logs",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("weight_kg", sa.Float(), nullable=False),
        sa.Column("recorded_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_weight_logs_user_id"), "weight_logs", ["user_id"], unique=False
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_weight_logs_user_id"), table_name="weight_logs")
    op.drop_table("weight_logs")
    op.drop_index(op.f("ix_user_profiles_user_id"), table_name="user_profiles")
    op.drop_table("user_profiles")
