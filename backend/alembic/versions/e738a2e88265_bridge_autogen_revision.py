"""empty autogenerate already applied on local/dev db

Revision ID: e738a2e88265
Revises: e7e7e402e566
Create Date: 2026-08-05 03:00:00.000000+00:00

docker-compose 的 db-migrate 会 `alembic revision --autogenerate`，
曾写出这个 revision 并 stamp 进数据库，但文件没进仓库。补空迁移以接上后续链。
"""

revision = "e738a2e88265"
down_revision = "e7e7e402e566"
branch_labels = None
depends_on = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
