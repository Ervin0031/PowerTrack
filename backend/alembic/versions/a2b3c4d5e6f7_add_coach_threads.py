"""add coach threads

Revision ID: a2b3c4d5e6f7
Revises: d4f5a6b7c8e9
Create Date: 2026-10-16 18:00:00.000000+00:00

"""

from alembic import op
import sqlalchemy as sa

revision = "a2b3c4d5e6f7"
down_revision = "d4f5a6b7c8e9"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "coach_threads",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_coach_threads_user_id", "coach_threads", ["user_id"])
    op.create_table(
        "coach_messages",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("thread_id", sa.Integer(), nullable=False),
        sa.Column("role", sa.String(length=16), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("proposal_json", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["thread_id"], ["coach_threads.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_coach_messages_thread_id", "coach_messages", ["thread_id"])


def downgrade() -> None:
    op.drop_index("ix_coach_messages_thread_id", table_name="coach_messages")
    op.drop_table("coach_messages")
    op.drop_index("ix_coach_threads_user_id", table_name="coach_threads")
    op.drop_table("coach_threads")
