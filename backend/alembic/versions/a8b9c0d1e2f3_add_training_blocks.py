"""add training blocks

Revision ID: a8b9c0d1e2f3
Revises: b3c4d5e6f7a8
Create Date: 2026-10-21 12:00:00.000000+00:00

"""

from alembic import op
import sqlalchemy as sa
import sqlmodel

revision = "a8b9c0d1e2f3"
down_revision = "b3c4d5e6f7a8"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "training_blocks",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("title", sqlmodel.sql.sqltypes.AutoString(length=80), nullable=False),
        sa.Column("week_count", sa.Integer(), nullable=False),
        sa.Column("deload_week", sa.Integer(), nullable=False),
        sa.Column("started_on", sa.Date(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("user_id"),
    )
    op.create_index(
        op.f("ix_training_blocks_user_id"), "training_blocks", ["user_id"], unique=True
    )
    op.create_table(
        "training_block_days",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("block_id", sa.Integer(), nullable=False),
        sa.Column("weekday", sa.Integer(), nullable=False),
        sa.Column("template_id", sa.Integer(), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["block_id"], ["training_blocks.id"]),
        sa.ForeignKeyConstraint(["template_id"], ["workout_templates.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_training_block_days_block_id"),
        "training_block_days",
        ["block_id"],
        unique=False,
    )
    op.create_index(
        op.f("ix_training_block_days_template_id"),
        "training_block_days",
        ["template_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f("ix_training_block_days_template_id"), table_name="training_block_days"
    )
    op.drop_index(
        op.f("ix_training_block_days_block_id"), table_name="training_block_days"
    )
    op.drop_table("training_block_days")
    op.drop_index(op.f("ix_training_blocks_user_id"), table_name="training_blocks")
    op.drop_table("training_blocks")
