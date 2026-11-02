"""add workout tables

Revision ID: e7e7e402e566
Revises: 473a591c3b9e
Create Date: 2026-08-05 02:51:16.176221+00:00

"""

from alembic import op
import sqlalchemy as sa
import sqlmodel

# revision identifiers, used by Alembic.
revision = "e7e7e402e566"
down_revision = "473a591c3b9e"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "workout_sessions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column(
            "client_uuid", sqlmodel.sql.sqltypes.AutoString(length=36), nullable=False
        ),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column(
            "status", sqlmodel.sql.sqltypes.AutoString(length=20), nullable=False
        ),
        sa.Column("started_at", sa.DateTime(), nullable=False),
        sa.Column("completed_at", sa.DateTime(), nullable=True),
        sa.Column("notes", sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_workout_sessions_client_uuid"),
        "workout_sessions",
        ["client_uuid"],
        unique=True,
    )
    op.create_index(
        op.f("ix_workout_sessions_user_id"),
        "workout_sessions",
        ["user_id"],
        unique=False,
    )
    op.create_table(
        "workout_sets",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column(
            "client_uuid", sqlmodel.sql.sqltypes.AutoString(length=36), nullable=False
        ),
        sa.Column("session_id", sa.Integer(), nullable=False),
        sa.Column("exercise_id", sa.Integer(), nullable=False),
        sa.Column("set_number", sa.Integer(), nullable=False),
        sa.Column("reps", sa.Integer(), nullable=True),
        sa.Column("weight_kg", sa.Float(), nullable=True),
        sa.Column("duration_seconds", sa.Integer(), nullable=True),
        sa.Column("distance_meters", sa.Float(), nullable=True),
        sa.Column("notes", sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column("completed_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(
            ["exercise_id"],
            ["exercises.id"],
        ),
        sa.ForeignKeyConstraint(
            ["session_id"],
            ["workout_sessions.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_workout_sets_client_uuid"),
        "workout_sets",
        ["client_uuid"],
        unique=True,
    )
    op.create_index(
        op.f("ix_workout_sets_exercise_id"),
        "workout_sets",
        ["exercise_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_workout_sets_session_id"), "workout_sets", ["session_id"], unique=False
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_workout_sets_session_id"), table_name="workout_sets")
    op.drop_index(op.f("ix_workout_sets_exercise_id"), table_name="workout_sets")
    op.drop_index(op.f("ix_workout_sets_client_uuid"), table_name="workout_sets")
    op.drop_table("workout_sets")
    op.drop_index(op.f("ix_workout_sessions_user_id"), table_name="workout_sessions")
    op.drop_index(
        op.f("ix_workout_sessions_client_uuid"), table_name="workout_sessions"
    )
    op.drop_table("workout_sessions")
