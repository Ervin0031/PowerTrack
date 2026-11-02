"""add workout templates

Revision ID: f9b2c3d4e5a6
Revises: e8a1b2c3d4e5
Create Date: 2026-09-11 19:00:00.000000+00:00

"""

from alembic import op
import sqlalchemy as sa
import sqlmodel

revision = "f9b2c3d4e5a6"
down_revision = "e8a1b2c3d4e5"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "workout_templates",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column(
            "title", sqlmodel.sql.sqltypes.AutoString(length=120), nullable=False
        ),
        sa.Column("description", sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column(
            "cover_image_key",
            sqlmodel.sql.sqltypes.AutoString(length=500),
            nullable=True,
        ),
        sa.Column(
            "difficulty", sqlmodel.sql.sqltypes.AutoString(length=20), nullable=False
        ),
        sa.Column("is_public", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_workout_templates_user_id"),
        "workout_templates",
        ["user_id"],
        unique=False,
    )

    op.create_table(
        "workout_template_exercises",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("template_id", sa.Integer(), nullable=False),
        sa.Column("exercise_id", sa.Integer(), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.Column("superset_id", sa.Integer(), nullable=True),
        sa.Column("notes", sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column("rest_target_seconds", sa.Integer(), nullable=True),
        sa.Column(
            "weight_unit", sqlmodel.sql.sqltypes.AutoString(length=8), nullable=False
        ),
        sa.ForeignKeyConstraint(["exercise_id"], ["exercises.id"]),
        sa.ForeignKeyConstraint(["template_id"], ["workout_templates.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_workout_template_exercises_exercise_id"),
        "workout_template_exercises",
        ["exercise_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_workout_template_exercises_template_id"),
        "workout_template_exercises",
        ["template_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_workout_template_exercises_superset_id"),
        "workout_template_exercises",
        ["superset_id"],
        unique=False,
    )

    op.create_table(
        "workout_template_sets",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("template_exercise_id", sa.Integer(), nullable=False),
        sa.Column("set_number", sa.Integer(), nullable=False),
        sa.Column("reps", sa.Integer(), nullable=True),
        sa.Column("weight_kg", sa.Float(), nullable=True),
        sa.Column("duration_seconds", sa.Integer(), nullable=True),
        sa.Column("distance_meters", sa.Float(), nullable=True),
        sa.Column("notes", sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column(
            "set_kind", sqlmodel.sql.sqltypes.AutoString(length=20), nullable=False
        ),
        sa.ForeignKeyConstraint(
            ["template_exercise_id"], ["workout_template_exercises.id"]
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_workout_template_sets_template_exercise_id"),
        "workout_template_sets",
        ["template_exercise_id"],
        unique=False,
    )

    op.add_column(
        "workout_sessions", sa.Column("template_id", sa.Integer(), nullable=True)
    )
    op.create_index(
        op.f("ix_workout_sessions_template_id"),
        "workout_sessions",
        ["template_id"],
        unique=False,
    )
    op.create_foreign_key(
        "fk_workout_sessions_template_id",
        "workout_sessions",
        "workout_templates",
        ["template_id"],
        ["id"],
    )


def downgrade() -> None:
    op.drop_constraint(
        "fk_workout_sessions_template_id", "workout_sessions", type_="foreignkey"
    )
    op.drop_index(
        op.f("ix_workout_sessions_template_id"), table_name="workout_sessions"
    )
    op.drop_column("workout_sessions", "template_id")
    op.drop_index(
        op.f("ix_workout_template_sets_template_exercise_id"),
        table_name="workout_template_sets",
    )
    op.drop_table("workout_template_sets")
    op.drop_index(
        op.f("ix_workout_template_exercises_superset_id"),
        table_name="workout_template_exercises",
    )
    op.drop_index(
        op.f("ix_workout_template_exercises_template_id"),
        table_name="workout_template_exercises",
    )
    op.drop_index(
        op.f("ix_workout_template_exercises_exercise_id"),
        table_name="workout_template_exercises",
    )
    op.drop_table("workout_template_exercises")
    op.drop_index(op.f("ix_workout_templates_user_id"), table_name="workout_templates")
    op.drop_table("workout_templates")
