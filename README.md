<p align="center">
  <img src="images/logo.png" alt="PowerTrack logo" width="120" />
</p>

# PowerTrack

**English** · [中文](#中文)

An open-source strength-training tracker: a Flutter mobile app, a FastAPI backend, and a React admin dashboard. Track workouts set by set, visualize strength progress, and get coaching suggestions from an LLM you bring yourself.

<p align="center">
  <img src="images/IMG_1050.JPG" alt="Training home" height="420" />
  <img src="images/IMG_1064.PNG" alt="Workout session" height="420" />
  <img src="images/IMG_1062.PNG" alt="Statistics" height="420" />
  <img src="images/IMG_1063.PNG" alt="Profile" height="420" />
</p>

<p align="center">
  Training home · Workout session · Statistics · Profile
</p>

<p align="center">
  <img src="images/IMG_1066.PNG" alt="AI coach" height="420" />
  <img src="images/IMG_1067.PNG" alt="Muscle recovery" height="420" />
  <img src="images/IMG_1068.PNG" alt="Workout template" height="420" />
  <img src="images/IMG_1069.PNG" alt="Exercise library" height="420" />
</p>

<p align="center">
  AI coach · Muscle recovery · Templates · Exercise library
</p>

<p align="center">
  <img src="images/IMG_1070.PNG" alt="Training calendar" height="420" />
</p>

<p align="center">
  Training calendar
</p>

## Features

- **Workout tracking** — sets, reps, weight, RPE, rest timer, supersets, ghost sets against the previous session, and crash-safe session recovery.
- **Exercise library** — searchable and filterable by muscle group / equipment, cached locally for offline use.
- **Templates & programs** — reusable workout templates, training blocks, and next-session prescriptions.
- **Calendar & statistics** — training calendar, weekly volume, estimated 1RM, strength standards, and muscle-group recovery.
- **AI coach (BYOK)** — connect any OpenAI-compatible endpoint (DeepSeek by default); the API key stays on the device.
- **Accounts** — registration, email verification, password reset, device/session management.
- **Admin dashboard** — React + TanStack Router + shadcn/ui.
- **iOS extras** — Live Activity / Dynamic Island support.

## Architecture

```
PowerTrack/
├── app/        Flutter client (iOS / Android)
├── backend/    FastAPI + SQLModel + PostgreSQL
├── frontend/   React admin dashboard
└── docs/       Feature documentation (Chinese)
```

| Part | Stack |
|------|-------|
| `app/` | Flutter 3.47 · Dart ^3.12 · Riverpod · go_router · Dio · sqflite |
| `backend/` | Python ≥3.10 · FastAPI · SQLModel · PostgreSQL · Redis · Celery · Alembic |
| `frontend/` | Vite 8 · React 19 · TanStack Router · Tailwind v4 · shadcn/ui |

The API is served under `/api/v1` and authenticated with JWT bearer tokens. Health check: `GET /health`.

## Getting started

### Prerequisites

- Python ≥3.10 with [uv](https://docs.astral.sh/uv/)
- Flutter 3.47 with [FVM](https://fvm.app/) (see `app/.fvmrc`)
- Node.js 20+ with pnpm
- PostgreSQL 16 and Redis 7 (local install or Docker)

### Backend

```sh
cd backend
uv sync

# Create your local env file, then edit DATABASE_URL / JWT_SECRET_KEY
cp secret/.env.example secret/.env.development

uv run alembic upgrade head
uv run uvicorn app.main:app --reload
```

API docs: <http://localhost:8000/docs>

Create an administrator (password is required — there is no default):

```sh
ADMIN_PASSWORD='choose-a-strong-password' uv run python scripts/create_admin.py
```

Run tests: `uv run pytest`

### Mobile app

```sh
cd app
fvm flutter pub get
fvm flutter run --dart-define=BASE_URL=http://localhost:8000
```

For iOS, select your own development team in Xcode before building. The repository intentionally ships without one.

### Admin dashboard

```sh
cd frontend
pnpm install
cp .env.example .env      # set VITE_API_URL
pnpm run dev
```

Run tests: `pnpm run test`

### Docker (alternative)

```sh
cd backend
cp secret/.env.example secret/.env.production   # fill in real values first
docker compose up -d --build
```

## Configuration

Backend settings are read from `backend/secret/.env.<ENV>` (`ENV` defaults to `development`). Start from `backend/secret/.env.example`; never commit real env files.

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | PostgreSQL connection string |
| `JWT_SECRET_KEY` | JWT signing key (min. 32 chars) |
| `REDIS_CONNECTION_URL` | Redis connection string |
| `STORAGE_*` | S3-compatible object storage (RustFS) |
| `LLM_BASE_URL` / `LLM_API_KEY` | Optional server-side OpenAI-compatible LLM |
| `RESEND_API_KEY` / `EMAIL_*` | Email verification and password reset |

Client configuration is injected at build time:

```sh
fvm flutter run --dart-define=BASE_URL=https://api.example.com
```

## Security notes

- Real credentials live only in `backend/secret/.env.*`, which is git-ignored. Never commit them.
- Change every default in `docker-compose.yml` (`postgres/postgres`, `rustfsadmin`) before deploying.
- The default database and storage ports are exposed in the compose file for local development only.
- The AI coach is BYOK: user API keys are stored in the device's secure storage and never sent to the backend.

## Deployment

`.github/workflows/deploy.yml` deploys the backend on pushes to `main` via SSH. It expects repository secrets `SSH_HOST`, `SSH_USER`, and `SSH_PRIVATE_KEY`, and assumes the project lives at `/opt/PowerTrackV2`. Adjust or remove the workflow to match your own infrastructure.

## Contributing

Issues and pull requests are welcome. Please keep the layer boundaries described in `AGENTS.md` intact, run the relevant tests, and avoid committing secrets or local machine paths.

## License

Licensed under the [GNU Affero General Public License v3.0](LICENSE). If you run a modified version as a network service, you must make the corresponding source code available.

The `frontend/` directory retains the upstream MIT license of shadcn-admin, and the `backend/` scaffold retains its MIT license. Both are compatible with the AGPL for the project as a whole.

## Acknowledgements

- Admin dashboard based on [shadcn-admin](https://github.com/satnaing/shadcn-admin) by Sat Naing (MIT).
- Backend scaffold generated by [Forge](https://github.com/ning3739/forge).
- Google Sans Flex font, distributed under the SIL Open Font License (`app/assets/fonts/Google_Sans_Flex/OFL.txt`).
- `expressive_*` and `material_*` Flutter packages by Kostia Sokolovskyi (MIT); see the `LICENSE` files under `app/packages/`.

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
