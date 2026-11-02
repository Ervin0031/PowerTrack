# AGENTS.md

This file provides guidance to OpenCode sessions when working with code in this repository.

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

### UI conventions

- **组件一律用 m3e_core**：所有 UI 组件必须使用 `package:m3e_core/m3e_core.dart` 提供的组件（`M3E*`），不要使用 Material 3 内置组件，也不要自造轮子；仅当 m3e_core 确无对应实现时才退回 Material/基础 Widget。
- **弹窗/轻提示一律用 expressive_snack**：提示类弹窗统一走 `packages/expressive_snack/` 的 `showExpressiveSnack(...)`（`import 'package:expressive_snack/expressive_snack.dart';`），禁止使用 Material 的 `SnackBar` / `ScaffoldMessenger`。

### Tech stack

| Layer | Package |
|-------|---------|
| State | flutter_riverpod |
| Navigation | go_router |
| Network | Dio (`core/network/dio_client.dart`) |
| Code gen | freezed_annotation + json_annotation (build_runner) |
| Local cache | sqflite (`core/database/`) |
| UI | Material 3 Expressive (`expressive_*` packages) + m3e_core |

### Local database (`core/database/`)

Single shared SQLite DB (`AppDatabase`, sqflite, `powertrack.db`). Feature modules never open their own DB:

- Table schemas are registered by calling `AppDatabase.registerSchema([...])` at the top of the feature's local DAO file — do not edit `app_database.dart` to add a table.
- Feature DAOs extend `BaseDao` (upsert/batch/count helpers), e.g. `features/exercises/data/local/exercise_local_dao.dart`. Schema version bumps + migrations go in `AppDatabase.onUpgrade`.

### Configuration

`core/config/app_config.dart` centralizes app name, base URL, and design-spec sizes; values can be overridden at build time via `--dart-define` (e.g. `BASE_URL`), not at runtime.

### Known issues

- `build_runner` previously failed due to `analyzer_plugin` version conflict with Dart 3.12.2. Fixed via `dependency_overrides: analyzer_plugin: 0.13.1` in `pubspec.yaml` — Freezed / riverpod_generator codegen now works; run `flutter pub run build_runner build` after adding `@freezed` / `@riverpod` annotations.
- `_AuthInterceptor` token is in-memory only — no Keychain persistence yet

### Adding a feature

1. Create `lib/features/{name}/` with `domain/`, `data/`, `application/`, `presentation/` subdirs
2. Domain entity first → Data repo → Application provider → Presentation screen
3. Use `package:app_flutter/...` absolute imports (not relative)
4. Run `flutter analyze` to verify layer boundaries

## Deployment

`.github/workflows/deploy.yml` deploys **only the backend** on push to `main`.
