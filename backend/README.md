# PowerTrack Backend

PowerTrack 的后端服务：基于 FastAPI + SQLModel + PostgreSQL，为移动端和管理后台提供认证、动作库、训练记录、模板、统计、社区动态与 AI 教练接口。项目总览见仓库根目录的 [README](../README.md)。

## 技术栈

| 类别 | 选型 |
|------|------|
| Web 框架 | FastAPI |
| ORM / 数据库 | SQLModel + PostgreSQL |
| 迁移 | Alembic |
| 缓存 / 消息队列 | Redis + Celery |
| 认证 | JWT（access + refresh） |
| 对象存储 | S3 兼容存储（RustFS） |
| LLM | OpenAI 兼容接口（默认 DeepSeek） |
| 日志 / 测试 | Loguru / pytest |

## 功能

- **认证**：注册、登录、JWT 刷新、登出、邮箱验证、密码重置/修改、登录设备管理。
- **用户**：当前用户信息、健身档案、管理员用户管理。
- **动作库**：动作、器械、肌群字典，支持图片上传与缩略图处理；动作与器械查询公开，写操作仅管理员。
- **训练**：训练会话、逐组记录、RPE、模板、训练周期、下次课处方。
- **统计**：周容量、1RM 估算、力量标准、肌群恢复。
- **社区**：动态流、关注、分享。
- **AI 教练**：OpenAI 兼容接口，支持会话历史与工具调用。
- **基础设施**：Redis 缓存、Celery 后台任务（如数据库备份）、速率限制、结构化日志、健康检查。

## 快速开始

### 环境要求

- Python ≥3.10
- [uv](https://docs.astral.sh/uv/)
- PostgreSQL 16、Redis 7（本地安装或 Docker）

### 安装与启动

```sh
cd backend
uv sync

# 创建本地环境文件，并填入 DATABASE_URL / JWT_SECRET_KEY 等
cp secret/.env.example secret/.env.development

uv run alembic upgrade head
uv run uvicorn app.main:app --reload
```

启动后可访问：

- Swagger UI：<http://localhost:8000/docs>
- ReDoc：<http://localhost:8000/redoc>
- 健康检查：`GET /health`

创建管理员（密码必须显式提供，脚本没有默认密码）：

```sh
ADMIN_PASSWORD='choose-a-strong-password' uv run python scripts/create_admin.py
```

用户名、邮箱可通过 `ADMIN_USERNAME` / `ADMIN_EMAIL` 覆盖。

### Celery

```sh
# worker
uv run celery -A app.core.celery.celery_app worker --loglevel=info

# 定时任务调度（仅生产）
uv run celery -A app.core.celery.celery_app beat --loglevel=info
```

## API 约定

- 基地址：`/api/v1`，健康检查为 `GET /health`。
- 认证：除注册/登录/邮箱验证/密码重置外，均需 `Authorization: Bearer <access_token>`。
- 时间：ISO 8601，UTC，以 `Z` 结尾，如 `2026-01-01T08:00:00Z`。
- 请求体兼容 `camelCase` 与 `snake_case`（训练、模板、档案模块），响应统一 `snake_case`。
- 分页列表返回 `{"items": [...], "total": 数量}`。
- 错误返回 `{"status": 状态码, "error": "错误信息"}`。

## 配置

配置从 `secret/.env.<ENV>` 读取（`ENV` 默认 `development`）。以 `secret/.env.example` 为模板，真实凭据不要提交。

| 变量 | 用途 |
|------|------|
| `DATABASE_URL` | PostgreSQL 连接串 |
| `JWT_SECRET_KEY` | JWT 签名密钥（至少 32 字符） |
| `REDIS_CONNECTION_URL` | Redis 连接串 |
| `CELERY_BROKER_URL` / `CELERY_RESULT_BACKEND` | Celery broker 与结果后端 |
| `STORAGE_*` | S3 兼容对象存储（RustFS） |
| `LLM_BASE_URL` / `LLM_API_KEY` / `LLM_MODEL` | 服务端 OpenAI 兼容 LLM |
| `EMAIL_*` | 邮箱验证与密码重置 |

## 数据库迁移

```sh
# 本地开发：生成迁移并提交产物
uv run alembic revision --autogenerate -m "描述"

# 应用迁移（部署流程只跑这一条）
uv run alembic upgrade head
```

约定：`--autogenerate` 只在本地开发时运行；部署环境只执行 `upgrade head`，避免服务器生成未跟踪文件、累积成分叉迁移。迁移图健康由 `tests/test_migrations.py` 检查（分叉或重复 revision id 会直接失败）。

## 脚本

`scripts/` 下提供常用运维与数据脚本：

| 脚本 | 用途 |
|------|------|
| `create_admin.py` | 创建管理员（`ADMIN_PASSWORD` 必填） |
| `seed_exercises.py` / `seed_exercise_data.py` | 写入动作库种子数据 |
| `import_exercises_dataset.py` | 导入动作数据集（需 `BASE_URL`、`ADMIN_USER`、`ADMIN_PASS`） |
| `upload_exercise_images.py` | 批量上传动作图片（同上） |
| `backfill_exercise_thumbnails.py` | 回填缩略图 |
| `dedupe_exercises.py` | 清理重复动作 |

## 测试与代码质量

```sh
uv run pytest                          # 全部测试
uv run pytest tests/api/test_auth.py -v  # 单个文件
uv run pytest --cov=app tests/         # 覆盖率

black . && ruff check . && mypy .      # 格式化 / 检查 / 类型
```

## Docker

```sh
cd backend
cp secret/.env.example secret/.env.production   # 先填入真实配置
docker compose up -d --build
```

compose 包含：`app`（API）、`db`（PostgreSQL）、`db-migrate`（启动时执行 `alembic upgrade head`）、`redis`、`celery-worker`、`celery-beat`、`rustfs`（对象存储）。

## 目录结构

```
backend/
├── app/
│   ├── main.py             # 应用入口、路由挂载、OpenAPI 配置
│   ├── core/               # 配置、数据库、Redis、Celery、日志、安全、依赖
│   ├── decorators/         # 限流等装饰器
│   ├── models/             # SQLModel 模型
│   ├── schemas/            # Pydantic schemas
│   ├── crud/               # 数据访问
│   ├── services/           # 业务逻辑
│   ├── routers/v1/         # auth / users / exercises / templates / workouts / coach / feed ...
│   ├── tasks/              # Celery 任务
│   └── utils/              # 工具函数
├── alembic/                # 数据库迁移
├── scripts/                # 管理、种子数据、导入与图片上传脚本
├── secret/                 # 环境文件（git 忽略，仅 .env.example 入库）
├── static/                 # 静态文件
├── tests/                  # API / 单元测试 / 迁移图检查
├── Dockerfile
├── docker-compose.yml
└── pyproject.toml
```

## 许可证

`backend/` 目录采用 MIT 许可，见 [LICENSE](LICENSE)；整个 PowerTrack 项目采用 [AGPL-3.0](../LICENSE)。后端脚手架最初由 [Forge](https://github.com/ning3739/forge) 生成。
