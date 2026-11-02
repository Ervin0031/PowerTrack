# PowerTrack App

PowerTrack 的 Flutter 客户端（iOS / Android），基于 Riverpod + go_router + Dio，采用 feature-first 的分层结构。项目总览见仓库根目录的 [README](../README.md)。

> 目录名为 `app/`，但 Dart 包名仍是 `app_flutter`，因此代码中统一使用 `package:app_flutter/...` 绝对导入。

## 功能

- **账号**：登录、注册、邮箱验证、忘记/重置密码、修改密码、登录设备管理。
- **训练**：训练会话与逐组记录、RPE、休息计时与本地通知、超级组、幽灵组（对照上次训练）、崩溃恢复。
- **训练日历与恢复**：训练日历、肌群恢复状态、下次可练建议。
- **动作库**：按肌群 / 器械 / 类型筛选与搜索，本地缓存（sqflite）离线可用，动作详情与历史统计。
- **模板与计划**：训练模板、模板完成记录、训练周期。
- **统计**：周容量、1RM 估算、力量标准、体重历史。
- **AI 教练**：BYOK，接入任意 OpenAI 兼容接口（默认 DeepSeek），API Key 仅保存在设备端；支持会话历史与训练数据工具调用。
- **社区**：动态流、关注、用户搜索、分享。
- **设置**：主题、缓存、AI 配置、账号设置。
- **iOS 增强**：Live Activity / 灵动岛、Apple Health 桥接。

## 技术栈

| 类别 | 包 |
|------|-----|
| 状态管理 | `flutter_riverpod` |
| 路由 | `go_router` |
| 网络 | `dio` |
| 本地数据库 | `sqflite` + `path_provider` |
| 安全存储 | `flutter_secure_storage`（iOS Keychain / Android Keystore） |
| 代码生成 | `freezed_annotation` + `json_annotation`（暂不可用，见「已知限制」） |
| UI | Material 3 + `m3e_core` + `material_ui` + 本地 `expressive_snack` |
| 图表 | `fl_chart` |
| iOS 原生 | `live_activities`、`flutter_local_notifications` |

## 目录结构

```
app/
├── lib/
│   ├── main.dart                 # 入口：初始化存储、hydrate token、ProviderContainer
│   ├── core/
│   │   ├── config/               # AppConfig：名称、baseUrl、超时、设计稿尺寸
│   │   ├── database/             # sqflite 初始化 + DAO 基类
│   │   ├── native/               # Live Activity / Apple Health 桥接
│   │   ├── network/              # Dio 工厂、拦截器、异常映射
│   │   ├── providers/            # 全局 Provider（dio 等）
│   │   ├── router/               # GoRouter + 启动分流 redirect
│   │   ├── storage/              # TokenStorage、AppLaunchStorage
│   │   └── ui/                   # 主题、颜色、字体、间距、屏幕适配
│   ├── features/
│   │   ├── auth/                 # 登录注册、邮箱验证、密码、设备管理
│   │   ├── training/             # 训练会话、日历、恢复、休息提醒
│   │   ├── exercises/            # 动作库、动作详情、动作统计
│   │   ├── templates/            # 模板与计划
│   │   ├── stats/                # 容量、1RM、力量标准
│   │   ├── coach/                # AI 教练（含 skills 工具定义）
│   │   ├── dynamic/              # 动态流、关注、分享
│   │   ├── profile/              # 健身档案、体重历史
│   │   ├── settings/             # 主题、缓存、AI、账号设置
│   │   ├── home/ splash/ welcome/ permissions/
│   │   └── ...
│   └── shared/                   # 复用组件与工具
├── packages/expressive_snack/    # 本地 Material 3 snackbar 包
├── assets/                       # 字体、图片等
├── ios/ android/
└── pubspec.yaml
```

### 分层约定

每个 feature 按需包含四层：

```
features/{name}/
├── domain/entities/       # 实体类，纯 Dart，零外部依赖
├── data/repositories/     # 数据源实现（API、本地存储）
├── application/providers/ # Riverpod Provider / Notifier
└── presentation/
    ├── screens/           # 页面级 Widget
    └── widgets/           # 可复用组件
```

- **Domain**：纯 Dart，禁止依赖 Flutter / Riverpod。
- **Data**：只依赖 Domain，不依赖 Flutter / Riverpod；平台判断由 Application 层注入。
- **Application**：Riverpod Provider，依赖 Domain + Data，不依赖 Flutter UI。
- **Presentation**：`ConsumerWidget`，只通过 Provider 取数据，禁止直接 import `*_repository.dart`。

简单页面（如 `splash/`、`welcome/`）可以只有 `presentation/`。

## 启动流程

`main.dart` 的执行顺序：

1. 绑定 Flutter 引擎，开启 edge-to-edge。
2. 初始化 `SharedPreferences`（启动标记等非敏感配置）。
3. `TokenStorage.hydrate()` 把 Keychain / Keystore 中的令牌读进内存——路由守卫与鉴权拦截器都在同步链路上读取 token，必须赶在 `runApp` 前完成。
4. 初始化本地通知，保证训练休息闹钟可调度。
5. 用 `ProviderContainer(overrides: ...)` 注入 `sharedPreferences` 与 `tokenStorage`，交给 `UncontrolledProviderScope`。

如果跳过 `hydrate()`，应用会以未登录状态启动。

## 本地运行

```sh
cd app
fvm flutter pub get
fvm flutter run --dart-define=BASE_URL=http://localhost:8000
```

- 项目通过 FVM 固定 Flutter 3.47.9（见 `.fvmrc`）；本机版本一致时也可直接用 `flutter`。
- iOS 构建前请在 Xcode 中选择你自己的开发团队，仓库刻意不包含签名团队信息。

### 编译期配置

| `--dart-define` | 默认值 | 说明 |
|-----------------|--------|------|
| `BASE_URL` | `http://localhost:8000` | 后端地址 |
| `APP_NAME` | `PowerTrack` | 应用标题 |
| `ENABLE_HTTP_LOG` | debug 下开启 | 网络请求日志 |
| `SHOW_FPS` | debug 下开启 | 右上角 FPS 浮层 |
| `SHOW_PERFORMANCE_OVERLAY` | `false` | Flutter 性能图 |

## 添加新 Feature

1. 创建 `lib/features/{name}/` 及所需的 `domain/`、`data/`、`application/`、`presentation/` 子目录。
2. 先写 Domain 实体 → Data 仓库 → Application Provider → Presentation 页面。
3. 在 `lib/core/router/app_router.dart` 注册路由。
4. 使用 `package:app_flutter/...` 绝对导入，避免相对路径。
5. 运行 `fvm flutter analyze` 检查分层边界与 lint。

## 已知限制

- **build_runner 不可用**：`analyzer_plugin` 与 Dart 3.12.2 的 `analyzer` 版本冲突，Freezed / riverpod_generator 无法生成代码。实体目前手写 `fromJson` / `toJson` 与手写 Provider；`pubspec.yaml` 中保留了对 `analyzer_plugin` 的版本覆盖，工具链恢复后应移除。
- **令牌存储**：`flutter_secure_storage` 落盘 + 内存缓存，保证 `accessToken` 等 getter 同步可读；旧版本存在 `SharedPreferences` 的明文令牌会在 `hydrate()` 时自动迁移。

## 验证命令

```sh
fvm flutter analyze                 # 静态分析与分层检查
fvm flutter test                    # 测试
dart format lib test                # 格式化

# 业务层不应直接使用 DioException（应返回空）
grep -r "DioException" lib/features/ lib/shared/
```

## 许可证

整个 PowerTrack 项目采用 [AGPL-3.0](../LICENSE)。`packages/` 下的本地包采用 MIT 许可，许可文件见各包目录。
