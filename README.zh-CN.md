<p align="center">
  <a href="README.md">English</a> · <strong>中文</strong>
</p>

> English is the primary README. This file keeps the current Chinese text. A fuller Chinese rewrite can come later.

---

## 中文

一个开源的健身训练追踪系统，包含 Flutter 移动端、FastAPI 后端和 React 管理后台。逐组记录训练、可视化力量进步，并接入你自带的 LLM 作为 AI 教练。

## 功能

- **训练追踪** — 组数、次数、重量、RPE、休息计时、超级组、对照上次训练的幽灵组，以及崩溃后可恢复的进行中会话。
- **动作库** — 按肌群 / 器械筛选与搜索，本地缓存，离线可用。
- **模板与计划** — 可复用的训练模板、训练周期和下次课处方。
- **日历与统计** — 训练日历、周容量、1RM 估算、力量标准、肌群恢复状态。
- **AI 教练（BYOK）** — 支持任意 OpenAI 兼容接口（默认 DeepSeek），API Key 仅保存在设备端。
- **账号体系** — 注册、邮箱验证、重置密码、设备与会话管理。
- **管理后台** — React + TanStack Router + shadcn/ui。
- **iOS 增强** — 灵动岛 / Live Activity。

## 架构

```
PowerTrack/
├── app/        Flutter 客户端（iOS / Android）
├── backend/    FastAPI + SQLModel + PostgreSQL
├── frontend/   React 管理后台
└── docs/       功能文档
```

| 模块 | 技术栈 |
|------|--------|
| `app/` | Flutter 3.47 · Dart ^3.12 · Riverpod · go_router · Dio · sqflite |
| `backend/` | Python ≥3.10 · FastAPI · SQLModel · PostgreSQL · Redis · Celery · Alembic |
| `frontend/` | Vite 8 · React 19 · TanStack Router · Tailwind v4 · shadcn/ui |

接口统一前缀 `/api/v1`，使用 JWT Bearer 鉴权。健康检查：`GET /health`。

## 快速开始

### 环境要求

- Python ≥3.10 和 [uv](https://docs.astral.sh/uv/)
- Flutter 3.47 和 [FVM](https://fvm.app/)（见 `app/.fvmrc`）
- Node.js 20+ 和 pnpm
- PostgreSQL 16、Redis 7（本地安装或 Docker）

### 后端

```sh
cd backend
uv sync

# 创建本地环境文件，并填入 DATABASE_URL / JWT_SECRET_KEY
cp secret/.env.example secret/.env.development

uv run alembic upgrade head
uv run uvicorn app.main:app --reload
```

接口文档：<http://localhost:8000/docs>

创建管理员（密码必须显式提供，脚本没有默认密码）：

```sh
ADMIN_PASSWORD='换成强密码' uv run python scripts/create_admin.py
```

在 API 运行的状态下，可选使用 [hasaneyldrm/exercises-dataset](https://github.com/hasaneyldrm/exercises-dataset) 初始化动作库。导入脚本按英文名匹配已有动作，补齐缺失的示范 GIF，并创建尚不存在的动作：

```sh
git clone --depth 1 https://github.com/hasaneyldrm/exercises-dataset /tmp/exercises-dataset

cd backend
uv run python scripts/import_exercises_dataset.py \
  --dataset /tmp/exercises-dataset \
  --user root --password '管理员密码' --dry-run
# 去掉 --dry-run 正式写入
```

运行测试：`uv run pytest`

### 移动端

```sh
cd app
fvm flutter pub get
fvm flutter run --dart-define=BASE_URL=http://localhost:8000
```

iOS 构建前请在 Xcode 中选择你自己的开发团队，仓库刻意不包含签名团队信息。

### 管理后台

```sh
cd frontend
pnpm install
cp .env.example .env      # 设置 VITE_API_URL
pnpm run dev
```

运行测试：`pnpm run test`

### Docker（可选）

```sh
cd backend
cp secret/.env.example secret/.env.production   # 先填入真实配置
docker compose up -d --build
```

## 配置

后端从 `backend/secret/.env.<ENV>` 读取配置（`ENV` 默认为 `development`）。请以 `backend/secret/.env.example` 为模板，真实环境文件不要提交。

| 变量 | 用途 |
|------|------|
| `DATABASE_URL` | PostgreSQL 连接串 |
| `JWT_SECRET_KEY` | JWT 签名密钥（至少 32 字符） |
| `REDIS_CONNECTION_URL` | Redis 连接串 |
| `STORAGE_*` | S3 兼容对象存储（RustFS） |
| `LLM_BASE_URL` / `LLM_API_KEY` | 可选的服务器端 OpenAI 兼容 LLM |
| `RESEND_API_KEY` / `EMAIL_*` | 邮箱验证与重置密码 |

客户端地址在构建时注入：

```sh
fvm flutter run --dart-define=BASE_URL=https://api.example.com
```

## 安全提示

- 真实凭据只放在 `backend/secret/.env.*`，该目录已被 git 忽略，切勿提交。
- 部署前务必修改 `docker-compose.yml` 中的默认值（`postgres/postgres`、`rustfsadmin`）。
- compose 中暴露的数据库与对象存储端口仅供本地开发使用。
- AI 教练采用 BYOK：用户的 API Key 保存在设备安全存储中，不会上传到后端。

## 部署

`.github/workflows/deploy.yml` 会在推送到 `main` 时通过 SSH 部署后端。它需要仓库 Secrets：`SSH_HOST`、`SSH_USER`、`SSH_PRIVATE_KEY`，并假设项目位于 `/opt/PowerTrackV2`。请根据你自己的服务器调整或删除该工作流。

## 贡献

欢迎提交 Issue 和 Pull Request。请保持 `AGENTS.md` 中约定的分层边界，运行相关测试，并且不要提交密钥或本机路径。

## 许可证

本项目采用 [GNU Affero General Public License v3.0](LICENSE)。如果你将修改后的版本作为网络服务运行，必须公开对应的源代码。

`frontend/` 目录保留上游 shadcn-admin 的 MIT 许可，`backend/` 脚手架保留其 MIT 许可，二者与整体 AGPL 许可兼容。

## 致谢

- 管理后台基于 [shadcn-admin](https://github.com/satnaing/shadcn-admin)（作者 Sat Naing，MIT）。
- 后端脚手架由 [Forge](https://github.com/ning3739/forge) 生成。
- Google Sans Flex 字体遵循 SIL Open Font License（`app/assets/fonts/Google_Sans_Flex/OFL.txt`）。
- `expressive_*` 与 `material_*` Flutter 包由 Kostia Sokolovskyi 提供（MIT），许可文件见 `app/packages/`。
