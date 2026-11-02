# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Monorepo layout

PowerTrack is a multi-part project. Each top-level directory is an independent codebase with its own toolchain — `cd` into it before running commands.

| Dir | Stack | Role |
|-----|-------|------|
| `app/` | Flutter (Dart SDK ^3.12.2), Riverpod + Clean Architecture | Cross-platform client |
| `backend/` | FastAPI + SQLModel + PostgreSQL, Python ≥3.10 | REST API, auth, Celery tasks |
| `frontend/` | Vite 8 + React 19 + Tailwind v4 + shadcn/ui + TanStack Router | Admin dashboard ("studio-admin") |

The Flutter app and backend are the primary pair. Base API URL (clients → backend): `http://localhost:8000`.

## Backend (`backend/`)

```sh
uv sync && uv run uvicorn app.main:app --reload   # install + dev server (:8000)
uv run pytest                                      # all tests
uv run pytest tests/api/test_auth.py -v            # single test file
uv run alembic revision --autogenerate -m "msg"    # new migration
uv run alembic upgrade head                        # apply migrations
black . && ruff check . && mypy .                  # format / lint / typecheck
```

Docker full stack: `docker compose up -d --build` from `backend/`. Env files in `secret/` (git-ignored).

迁移约定：`alembic revision --autogenerate` 只在本地开发时运行、产物经 git 提交；部署流程只跑 `alembic upgrade head`（db-migrate 已按此配置，勿把 autogenerate 加回——它会在服务器生成未跟踪文件，累积成分叉迁移导致多 head）。迁移图健康由 `tests/test_migrations.py` 把关（分叉/重复 revision id 会直接 fail）。

## Frontend (`frontend/`)

```sh
pnpm install && pnpm run dev   # install + dev server
pnpm run build                 # production build
pnpm run lint && pnpm run test # lint + test
```

## Flutter app (`app/`)

Feature-first Clean Architecture with Riverpod. Four-layer per-feature structure:

```
features/{name}/
├── domain/entities/       # 实体类，纯 Dart，零依赖
├── data/repositories/     # 数据源实现（API、本地存储）
├── application/providers/ # Riverpod Provider / Notifier
└── presentation/
    ├── screens/           # 页面级 Widget
    └── widgets/           # 可复用组件
```

```sh
cd app && flutter pub get
flutter test                                    # tests
flutter analyze                                 # lint (flutter_lints)
```

### Architecture rules

- **Domain**: pure Dart, no Flutter/Riverpod/Firebase imports
- **Data**: depends on Domain only, no Flutter/Riverpod, inject platform checks from Application layer
- **Application**: Riverpod providers, depends on Domain + Data, no Flutter UI classes
- **Presentation**: ConsumerWidget, access data through providers only, never import `*_repository.dart` directly

### Tech stack

| Layer | Package |
|-------|---------|
| State | flutter_riverpod |
| Navigation | go_router |
| Network | Dio (`core/network/dio_client.dart`) |
| Code gen | freezed_annotation + json_annotation (build_runner) |
| UI | Material 3 + m3e_core |

### Known issues

- `build_runner` fails due to `analyzer_plugin` version conflict with Dart 3.12.2 — Freezed code gen is unavailable; entities use hand-written `fromJson`/`toJson` for now
- Tokens live in the Keychain (`flutter_secure_storage`) with an in-memory cache so `TokenStorage`'s getters stay synchronous; `main()` must `await TokenStorage.hydrate()` before `runApp` or the app boots logged out

### Adding a feature

1. Create `lib/features/{name}/` with `domain/`, `data/`, `application/`, `presentation/` subdirs
2. Domain entity first → Data repo → Application provider → Presentation screen
3. Use `package:app_flutter/...` absolute imports (not relative)
4. Run `flutter analyze` to verify layer boundaries

## Deployment

`.github/workflows/deploy.yml` deploys **only the backend** on push to `main`.
