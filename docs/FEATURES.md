# PowerTrack 功能说明书

> 本文档由前后端代码扫描整理，覆盖各客户端、后端 API、管理后台的功能与实现现状。
> 状态图例：✅ 已实现 · 🟡 占位/Mock · ❌ 未实现

---

## 1. 项目总览

PowerTrack 是一套健身训练追踪系统，包含多个独立代码库：

| 目录 | 技术栈 | 角色 |
|------|--------|------|
| `backend/` | FastAPI + SQLModel + PostgreSQL + Celery | REST API、认证、后台任务 |
| `app/` | Flutter + Riverpod + Clean Architecture | 跨平台客户端（主力） |
| `frontend/` | Vite + React 19 + TanStack + shadcn/ui | 管理后台（studio-admin） |

后端 API 统一前缀 `/api/v1`，JWT Bearer 鉴权。健康检查 `GET /health`。

---

## 2. 客户端功能

### 2.1 认证与账号 ✅

| 功能 | 说明 | 相关文件 |
|------|------|----------|
| 登录 | 邮箱/用户名 + 密码；成功写入 token 并拉取用户信息 | `auth/presentation/screens/login_screen.dart` |
| 注册 | 用户名 + 邮箱 + 密码，注册后进入邮箱验证 | `.../register_screen.dart` |
| 邮箱验证 | 6 位验证码（`PinInput`）+ 重新发送 | `.../email_verify_screen.dart` |
| 忘记/重置密码 | 邮箱发码 → 验证码 + 新密码 | `.../forgot_password_screen.dart`、`.../reset_password_screen.dart` |
| 修改密码 | 旧密码 + 新密码，成功后退出 | `.../change_password_screen.dart` |
| 设备管理 | 列出活跃会话设备，可「登出全部」（有确认弹窗） | `.../devices_screen.dart` |
| 会话恢复 | 启动时 Keychain/本地 token 恢复 → 刷新 → 已登录/欢迎页 | `AuthController.build`（Flutter）/ `AuthViewModel.restoreSession`（iOS） |
| 自动刷新 | 401 时用 refresh token 换取新 access token 并重试 | `core/network/interceptors/auth_interceptor.dart` |

**Token 存储差异**：原生 iOS 用 Keychain（`KeychainManager`，`WhenUnlockedThisDeviceOnly`）；Flutter 目前用 SharedPreferences（未加密，见 `core/storage/token_storage.dart`）。

### 2.2 健身档案 / 新手引导 ✅

- **引导问卷**（Flutter `onboarding_page.dart`）：7 步 —— 性别 → 出生年 → 身高/体重（Cupertino 滚轮）→ 目标 → 经验 → 受伤部位（多选）→ 每周天数/时长；每一步草稿本地持久化，结束提交。
- **档案页**（`fitness_profile_page.dart`）：展示热量目标、BMR、TDEE、最大心率、年龄、目标/经验/伤情/计划；可「重新填写」。
- 接口：`GET/PUT /api/v1/users/me/profile`（未填写时返回 `complete=false`，不 404）。
- 计算在前后端各实现一份，逻辑一致（见 §4.6 指标）。

### 2.3 训练（核心）✅

**训练首页**（`training_page.dart`）
- 本周进度波浪环、7 天打卡日历、本周训练次数、连续周数、上次训练信息。
- 「开始训练 / 返回训练」入口、下拉刷新、日历与 AI 训练占位。

**进行中会话**（`training_session_page.dart`）
- AppBar 实时计时；动作卡片列表；溢出菜单：完成训练 / 训练设置 / 休息闹钟与音频 / 放弃训练。
- 底部悬浮栏：「✦ 建议」（AI 占位）+「+」打开动作选择库；键盘弹出时切换为 `EditBar`。
- 通过 Heroine 缩放转场从首页胶囊进入，支持边缘拖拽关闭。

**组表格**（`widgets/set_table.dart`）
- 列：组数 / 耗时 / 次数 / 重量(kg) / 完成。
- 左滑删除组（至少保留一组）；每组类型菜单（热身/主要/递减/放松）；RPE 热力颜色；建议重量提示（点按采用）；幽灵行参考。
- 完成前要求已填次数或重量。

**超级组** ✅（轻量标记）
- 动作选择库中多选（≥2）后出现「添加超级组」按钮，给同批动作打相同 `supersetId`；单选仅「添加动作」。
- 选择库按钮显隐带 `AnimatedSize` 过渡。
- ⚠️ 目前仅有数据标记，训练页**尚未做视觉分组**。

**幽灵模式**（Ghost Sets）✅
- 添加动作时拉取该动作最近一次训练的组数据（`last-session-sets`），作为参考行展示（上周/上次），**不预填**输入框。

**休息计时**（`widgets/rest_timer_bar.dart`）✅
- 全局可配置目标秒数（默认 90s，可关闭）；RPE 红区/力竭 `+60s`；超时变红显示 `+m:ss`；波浪进度 + 震动/系统滴答。

**RPE 自调节** ✅
- 收集弹窗（6.0–10.0 滑块，分区文案/配色）；下一组重量建议按区间调整（见 §4.5）；力竭可一键降重约 10%；重量按 2.5kg 取整。

**音频提示** 🟡 仅占位 UI，无实际播放。

**会话持久化** ✅
- 本地 SQLite 单行 JSON（`active_session`）缓存整会话，冷启动可恢复；结束时批量上传。
- 服务端仅有一进行一次中会话，冲突返回 409。

**状态管理**（`application/providers/`）
- `trainingSessionProvider`：start / addExercises / removeExercise / addSet / removeSet / toggleSetDone / completeSetWithRpe / applySuggestedWeight / updateSet / finish / discard。
- `restTimerSettingsProvider`、`trainingHomeProvider`（近 12 周聚合统计）、`activeSetEditNotifierProvider`。

### 2.4 动作库 ✅

- **列表**（`exercises_page.dart`）：搜索 + 三个筛选（肌群 / 器械 / 类型：复合|孤立），分页卡片列表，滚动加载（页大小 20）。
- **详情**（`exercise_detail_page.dart`）：图片、中英文名、类型、主/次肌群、器械、动作说明。
- **本地缓存** ✅：SQLite 表 `muscle_groups` / `equipment` / `exercises` / `exercise_details`；首次联网分页拉全量并回填详情，之后离线可用、本地 `LIKE` 搜索。
- 接口：`GET /api/v1/exercises`、`/exercises/{id}`、`/exercises/muscle-groups`、`/exercises/equipment`。
- **动作选择库**（训练内）：复用列表与筛选，多选添加，已添加动作置灰。

### 2.5 进度 / 历史

| 客户端 | 现状 |
|--------|------|
| 原生 iOS | ✅ 训练历史分页列表、会话详情、单动作历史（Swift Charts 趋势图） |
| Flutter | 🟡 仅 `stats` tab 占位（首页导航「数据」），无进度页 |

### 2.6 设置与主题 ✅

- **设置页**：外观分组 → 主题设置；版本信息（PackageInfo）。
- **主题设置**：14 种主色、明/暗/跟随系统、8 种色调策略（标准/鲜艳/忠实/灵动/单色/柔和/彩虹/果彩）、3 种字体（系统默认 / 鸿蒙黑体 / Maple Mono）；实时生效并持久化。
- 主题由 `M3EColorScheme.generate` 生成（`core/ui/app_theme.dart`）。

### 2.7 首页与导航 ✅

- **首页**（`home_page.dart`）：`IndexedStack` 保留四个 tab 状态（训练 / 动态 / 数据 / 你）+ 底部胶囊磨砂导航栏；再次点当前 tab 回到顶部。
- 有进行中会话时，导航栏顶部胶囊显示会话信息（Heroine 转场进入）。
- 版本更新弹窗（Changelog，当前仅定义 1.0.0）。
- **动态**、**数据**、AI 均为占位页。

### 2.8 原生 iOS 额外能力

- 底部 Tab：首页 / 动态 / 我（iOS 27+ 增加 AI tab）。
- Tab 底部配件迷你播放器：进行中会话的动作、组数、实时计时。
- 训练记录（`ActiveWorkoutView`）、会话历史、单动作历史图表。
- 个人中心的「设置 / 心跳 / 设备」为占位。
- SwiftData 已接入但**无任何 `@Model`**（schema 为空）；持久化实际走远程 API + `Documents/WorkoutDrafts` JSON。
- AI 全部为占位页，无服务/接口。

---

## 3. 后端 API

### 3.1 认证 `/api/v1/auth`

| 方法 | 路径 | 说明 | 鉴权 |
|------|------|------|------|
| POST | `/register` | 注册，发送验证邮件 | 无 |
| POST | `/login` | 邮箱/用户名登录，返回 access+refresh | 无 |
| POST | `/refresh` | 用 refresh token 换新 **access** token | 无 |
| POST | `/logout` | 吊销指定 refresh token | 无 |
| POST | `/logout-all` | 吊销当前用户全部 refresh token | Bearer |
| POST | `/verify-email` | 6 位码验证邮箱，成功后发欢迎邮件 | 无 |
| POST | `/resend-verification` | 重发验证码（用户不存在也静默成功） | 无 |
| POST | `/forgot-password` | 发送重置码（始终返回通用成功） | 无 |
| POST | `/reset-password` | 码重置密码，吊销全部 refresh | 无 |
| POST | `/change-password` | 旧密码改新密码，吊销全部 refresh | Bearer |
| GET | `/devices` | 列出未吊销设备会话 | Bearer |

### 3.2 用户 `/api/v1/users`

| 方法 | 路径 | 说明 | 鉴权 |
|------|------|------|------|
| GET | `/me` | 当前用户资料 | Bearer |
| GET | `/me/profile` | 健身档案（未填 `complete=false`，不 404） | Bearer |
| PUT | `/me/profile` | 新建/更新健身档案，写入体重日志 | Bearer |
| PUT | `/me` | 改用户名/邮箱/密码/激活态（唯一性校验） | Bearer |
| DELETE | `/me` | 注销账号 | Bearer |
| GET | `/` | 用户列表（分页） | Superuser |
| GET/PUT/DELETE | `/{user_id}` | 管理员查改删用户（禁止删自己） | Superuser |

### 3.3 动作 / 肌群 / 器械 `/api/v1/exercises`

| 方法 | 路径 | 说明 | 鉴权 |
|------|------|------|------|
| GET | `` | 分页动作列表；筛选 `search`/`muscle_group_id`/`equipment_id`/`exercise_type` | 无 |
| GET | `/{id}` | 动作详情（含肌群/器械名、次肌群、图片） | 无 |
| POST / PUT / DELETE | `` `/{id}` | 增改删动作（multipart，可带图片） | Superuser |
| GET/POST/PUT/DELETE | `/equipment`* | 器械 CRUD（被引用删除返回 409） | 读无 / 写 Superuser |
| GET/POST/PUT/DELETE | `/muscle-groups`* | 肌群 CRUD（可按 upper/lower/core 筛选，被引用 409） | 读无 / 写 Superuser |

### 3.4 训练会话 `/api/v1/sessions` 与性能查询

| 方法 | 路径 | 说明 | 鉴权 |
|------|------|------|------|
| POST | `/sessions` | 创建轻量会话（`client_uuid` 幂等；已有进行中会话 409） | Bearer |
| PUT | `/sessions/{id}/complete` | 完成会话，事务批量写入全部组（按组 UUID 幂等） | Bearer |
| GET | `/sessions` | 历史分页；筛选 `status`/`start_date`/`end_date` | Bearer |
| GET | `/sessions/in-progress` | 当前进行中会话，无则 404（冷启动恢复） | Bearer |
| GET | `/sessions/{id}` | 会话详情（含全部组，校验归属） | Bearer |
| DELETE | `/sessions/{id}` | 删除会话及组 | Bearer |
| GET | `/exercises/{id}/last-performance` | 该动作最近一次完成组 | Bearer |
| GET | `/exercises/{id}/last-session-sets` | 最近一次含该动作会话的全部组（幽灵数据） | Bearer |
| GET | `/exercises/{id}/history` | 该动作组分页历史（趋势图） | Bearer |
| GET | `/sync/last-performances` | 批量最近记录，`exercise_ids` 逗号分隔 | Bearer |
| POST | `/rpe/recommend` | RPE 下一组建议 | Bearer |

**关键业务逻辑**：每用户同时仅一个进行中会话；完成接口事务化并去重；时间统一转 UTC 朴素时间；批量最近记录以 `max(id)` 作为最近性代理。

### 3.5 RPE 自调节 `/rpe/recommend`

纯规则，前后端各一份（`backend/app/services/rpe.py`、`app/.../domain/rpe.dart`）：

| RPE 区间 | 建议 |
|----------|------|
| 10.0（力竭） | 重量 ×0.90（2.5kg 取整），**+60s 休息**，疲劳警告，剩余组再降 10% |
| ≥9.5（红区） | 同重量，**+60s 休息** |
| ≥9.0 | 同重量 |
| 8.0–8.5（甜区） | 重量 ×1.025 |
| 7.0–7.5 | 重量 ×1.05 |
| <7.0 | 重量 ×1.075 |

`weight_kg ≤ 0` 时不建议重量。RPE 归一化到 0.5 步长、限幅 0.5–10.0。

### 3.6 指标计算（`services/metrics.py`）

随 `GET/PUT /users/me/profile` 实时计算，无独立端点：
- 年龄（8–100 钳制）；BMR（Mifflin-St Jeor，性别不明取平均）。
- 活动系数（由每周天数或经验推导）；TDEE = BMR × 系数。
- 最大心率（Tanaka：208 − 0.7×年龄）。
- 热量目标：减脂 TDEE−400 / 增肌 TDEE+250 / 维持 TDEE。
- 建议分化名（如 推/拉/腿、全身力量、全身循环+有氧）。

### 3.7 基础设施

- **邮件**（`utils/email.py`）：SMTP + Jinja2 模板（`verification` / `welcome` / `password_reset`），3 次指数退避重试，支持批量。验证码 6 位、60 分钟有效、最多 5 次尝试、一次性。
- **存储**（`services/storage.py`）：S3 兼容（RustFS）+ boto3；图片类型校验、≤10MB，key `exercises/images/{uuid}.{ext}`；预签名 URL 有效期 3600s。
- **限流**（`decorators/rate_limit.py`）：内存滑动窗口实现 + 预设（10/分、100/分、1000/时）。⚠️ **已定义但未挂到任何端点，当前未生效**。
- **备份**（`core/celery.py` + `tasks/backup_database_task.py`）：Celery + Redis；每日 03:00 备份数据库，gzip 压缩，保留 30 天，最多 3 次重试。无 HTTP 管理端点。
- **异常规范**：`HTTPException` → `{"status": <code>, "error": <msg>}`；未捕获异常 → 500。

---

## 4. 管理后台（`frontend/`）

| 路由 | 功能 | 状态 |
|------|------|------|
| `/sign-in`、`/sign-up`、`/forgot-password`、`/otp` | 登录/注册/找回/验证码 | ✅ 已接后端 |
| `/` | 仪表盘（硬编码 KPI、mock 图表） | 🟡 Mock |
| `/users` | 用户列表/编辑/删除 | ✅ 已接后端 |
| `/exercises` | 动作 CRUD + 图片上传 | ✅ 已接后端 |
| `/exercises/equipment` | 器械 CRUD | ✅ 已接后端 |
| `/exercises/muscle-groups` | 肌群 CRUD | ✅ 已接后端 |
| `/settings/*` | 个人资料/账号/通知/显示 | 🟡 Mock（仅外观本地生效） |
| `/settings/appearance` | 主题/字体 | ✅ 本地生效 |
| `/errors/$error`、`/401`…`/503` | 错误页 | ✅ |
| `/tasks`、`/apps`、`/chats`、`/help-center` | 模板残留页 | 🟡 Mock/占位 |

- 鉴权：自研 JWT（非 Clerk），token 存 `localStorage`，401 自动刷新重试，失败跳登录；路由守卫检查 access token。
- 基址：`VITE_API_URL`（默认相对路径，dev 代理 `/api → :8000`）。
- ⚠️ 「邀请用户」无后端接口，仅弹提示。

---

## 5. 跨端能力对照

| 功能 | 后端 | Flutter | 原生 iOS | 管理后台 |
|------|:---:|:---:|:---:|:---:|
| 注册/登录/邮箱验证 | ✅ | ✅ | ✅ | ✅ |
| 找回/重置/改密 | ✅ | ✅ | ✅ | ✅ |
| 设备管理 | ✅ | ✅（无入口） | 🟡 | ✅ API |
| 健身档案/引导 | ✅ | ✅ | 🟡 | – |
| 动作库 | ✅ | ✅（本地缓存） | ✅ | ✅ |
| 训练会话记录 | ✅ | ✅ | ✅ | – |
| 组/RPE/休息计时 | ✅ | ✅ | 🟡 | – |
| 超级组标记 | ✅ | ✅（无视觉分组） | ❌ | – |
| 幽灵组参考 | ✅ | ✅ | ✅ | – |
| 训练历史/趋势图 | ✅ | 🟡 占位 | ✅ | – |
| AI 建议 / 训练 | ❌ | 🟡 占位 | 🟡 占位 | – |
| 音频提示 | – | 🟡 占位 | ❌ | – |
| 主题自定义 | – | ✅ | – | ✅ |
| 用户/动作/器械/肌群管理 | ✅ | – | – | ✅ |

---

## 6. 核心数据模型

- **users**：username/email（唯一）、hashed_password、is_active、is_superuser、is_verified、last_login_at。
- **refresh_tokens**：token、device_name/type、ip、ua、is_revoked、expires_at、last_used_at。
- **verification_codes**：code、code_type（email_verification/password_reset）、expires_at、attempts(≤5)、is_used。
- **user_profiles**：gender、birth_year、height_cm、weight_kg、goal、experience、injury_tags、weekly_days、session_minutes、equipment、preferences。
- **weight_logs**：体重变更历史。
- **muscle_groups** / **equipment** / **exercises** / **exercise_secondary_muscles**（多对多）。
- **workout_sessions**：client_uuid（唯一）、status（in_progress/completed）、started_at、completed_at、notes。
- **workout_sets**：client_uuid（唯一）、exercise_id、set_number、reps、weight_kg、duration_seconds、distance_meters、notes、completed_at、rpe(0.5–10)。

Flutter 本地 SQLite（`powertrack.db`）：`muscle_groups`、`equipment`、`exercises`、`exercise_details`、`active_session`（单行 JSON）。

---

## 7. 配置与环境

- **Flutter**：`core/config/app_config.dart`，`--dart-define=BASE_URL`（当前默认 `http://127.0.0.1:8000`，远端地址在注释里）、`ENABLE_HTTP_LOG`（默认跟随 debug）、`APP_NAME`。
- **iOS**：`Info.plist` `API_BASE_URL`，否则 `http://localhost:8000`。
- **后端**：`app/core/config/modules/*`（App/CORS/DB/Email/JWT/Logger/Redis/Storage），env 在 `secret/`（git 忽略）。
- **管理后台**：`VITE_API_URL`。

---

## 8. 现状 / 未实现 / 风险

**占位或 Mock**
- Flutter：动态、数据 tab；AI 建议/训练、日历、音频、奖励、训练模板、器械预设；Changelog 仅 1.0.0。
- 原生 iOS：AI 全部占位；个人中心设置/心跳/设备占位；SwiftData schema 为空。
- 后端：无 AI、无 1RM 估算、无限流生效端点。
- 管理后台：仪表盘、tasks/apps/chats/help-center、多数 settings 为 mock。

**已知缺口**
- 超级组仅有数据标记，训练页无视觉分组。
- Flutter 路由 `/change_password`、`/devices` 无 UI 入口（仅可编程到达）；`trainingExercises` 路由常量未使用。
- Flutter token 存 SharedPreferences（未加密），非 Keychain/secure storage。
- 后端 refresh 不轮换（仅发新 access，refresh 复用至过期/吊销），JWT 无 `jti`。
- 密码强度校验器已实现但注册/重置未调用（仅 `min_length=6`）。
- 动作搜索只匹配中文名，未匹配 `name_en`（与接口描述不符）。
- 限流装饰器未挂载，当前不生效。
- Flutter 死代码：`session_settings_sheets.dart`、`settings_group.dart`、`api_providers.dart` 的 `ApiClient` 未被使用。

---

*文档基于代码扫描整理，未覆盖测试用例与种子数据明细。*
