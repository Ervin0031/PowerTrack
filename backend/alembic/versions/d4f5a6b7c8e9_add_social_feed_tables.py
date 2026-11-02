"""add social feed tables

Revision ID: d4f5a6b7c8e9
Revises: c1d2e3f4a5b6
Create Date: 2026-10-15 18:00:00.000000+00:00

"""

from alembic import op
import sqlalchemy as sa
import sqlmodel

revision = "d4f5a6b7c8e9"
down_revision = "c1d2e3f4a5b6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "follows",
        sa.Column("follower_id", sa.Integer(), nullable=False),
        sa.Column("followee_id", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.CheckConstraint("follower_id <> followee_id", name="ck_follows_not_self"),
        sa.ForeignKeyConstraint(["follower_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["followee_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("follower_id", "followee_id"),
    )
    op.create_index(
        op.f("ix_follows_followee_id"), "follows", ["followee_id"], unique=False
    )

    op.create_table(
        "feed_posts",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("session_id", sa.Integer(), nullable=True),
        sa.Column(
            "caption", sqlmodel.sql.sqltypes.AutoString(length=500), nullable=True
        ),
        sa.Column("highlights", sqlmodel.sql.sqltypes.AutoString(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(
            ["session_id"], ["workout_sessions.id"], ondelete="SET NULL"
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_feed_posts_user_id"), "feed_posts", ["user_id"], unique=False
    )
    op.create_index(
        op.f("ix_feed_posts_session_id"), "feed_posts", ["session_id"], unique=True
    )

    op.create_table(
        "feed_comments",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("post_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("set_id", sa.Integer(), nullable=True),
        sa.Column("body", sqlmodel.sql.sqltypes.AutoString(length=500), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["post_id"], ["feed_posts.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["set_id"], ["workout_sets.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(
        op.f("ix_feed_comments_post_id"), "feed_comments", ["post_id"], unique=False
    )
    op.create_index(
        op.f("ix_feed_comments_user_id"), "feed_comments", ["user_id"], unique=False
    )
    op.create_index(
        op.f("ix_feed_comments_set_id"), "feed_comments", ["set_id"], unique=False
    )

    op.create_table(
        "feed_likes",
        sa.Column("post_id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["post_id"], ["feed_posts.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("post_id", "user_id"),
    )
    op.create_index(
        op.f("ix_feed_likes_user_id"), "feed_likes", ["user_id"], unique=False
    )


def downgrade() -> None:
    op.drop_index(op.f("ix_feed_likes_user_id"), table_name="feed_likes")
    op.drop_table("feed_likes")
    op.drop_index(op.f("ix_feed_comments_set_id"), table_name="feed_comments")
    op.drop_index(op.f("ix_feed_comments_user_id"), table_name="feed_comments")
    op.drop_index(op.f("ix_feed_comments_post_id"), table_name="feed_comments")
    op.drop_table("feed_comments")
    op.drop_index(op.f("ix_feed_posts_session_id"), table_name="feed_posts")
    op.drop_index(op.f("ix_feed_posts_user_id"), table_name="feed_posts")
    op.drop_table("feed_posts")
    op.drop_index(op.f("ix_follows_followee_id"), table_name="follows")
    op.drop_table("follows")
