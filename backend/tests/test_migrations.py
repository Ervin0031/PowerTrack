"""迁移图健康检查：分叉（多 head）或重复 revision id 在 pytest 阶段即暴露。

背景：2026-10 生产部署失败，根因是服务器上 autogenerate 残留文件与 git 迁移分叉
出多个 head、且出现重复 revision id。本测试把这类问题挡在提交前。
"""

from pathlib import Path

from alembic.config import Config
from alembic.script import ScriptDirectory

BACKEND_ROOT = Path(__file__).resolve().parent.parent
VERSIONS_DIR = BACKEND_ROOT / "alembic" / "versions"


def _script() -> ScriptDirectory:
    return ScriptDirectory.from_config(Config(str(BACKEND_ROOT / "alembic.ini")))


def test_single_head() -> None:
    heads = _script().get_heads()
    assert len(heads) == 1, f"迁移图存在多个 head（分叉），先 alembic merge：{heads}"


def test_no_duplicate_revision_ids() -> None:
    files = [p for p in VERSIONS_DIR.glob("*.py") if p.name != "__init__.py"]
    ids = {rev.revision for rev in _script().walk_revisions()}
    msg = f"重复的 revision id：{len(files)} 个迁移文件只有 {len(ids)} 个唯一 id"
    assert len(ids) == len(files), msg
