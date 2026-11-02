# PowerTrack Flutter

基于 Riverpod + go_router + Dio 的 Flutter 项目，提供完整的启动、路由、网络与本地存储脚手架。

## 目录结构

```
lib/
├── main.dart                              # 入口：async init + ProviderContainer override + AdaptiveTheme
├── core/
│   ├── config/
│   │   └── app_config.dart                # 应用常量：appName / baseUrl / 超时 / UI 设计稿尺寸
│   ├── storage/
│   │   ├── token_storage.dart             # access/refresh token 持久化（SharedPreferences）
│   │   └── app_launch_storage.dart        # 首次启动 / Welcome 已读标记
│   ├── network/
│   │   ├── dio_client.dart                # Dio 工厂：装配拦截器链 + refreshDio
│   │   ├── api_exception.dart             # 业务异常基类 + 4xx/5xx 子类
│   │   ├── error_message.dart             # 错误 → 用户可读文案
│   │   ├── network.dart                   # barrel export
│   │   └── interceptors/
│   │       ├── auth_interceptor.dart      # 注入 Authorization + 401 自动刷新
│   │       ├── error_interceptor.dart     # DioException → ApiException
│   │       └── logging_interceptor.dart   # 请求/响应/错误日志
│   ├── providers/
│   │   ├── dio_provider.dart              # sharedPreferences / tokenStorage / appLaunchStorage / dio
│   │   └── api_providers.dart             # ApiClient 门面（get/post）
│   ├── router/
│   │   └── app_router.dart                # GoRouter + 启动分流 redirect
│   ├── ui/
│   │   ├── app_theme.dart                 # 亮/暗 ThemeData
│   │   ├── app_colors.dart                # 颜色 token + BuildContext 扩展
│   │   ├── app_text_styles.dart           # 字体 token + TextTheme 映射
│   │   ├── app_radius.dart                # 圆角 token
│   │   ├── adaptive_spacing.dart          # 间距 token
│   │   ├── adaptive_breakpoints.dart      # 响应式断点
│   │   ├── screen_adapt.dart              # 屏幕适配（w/h/radius/icon/font）
│   │   ├── safe_area_ext.dart             # 安全区快捷扩展
│   │   └── ui.dart                        # barrel export
│   └── ...
├── features/
│   ├── splash/pages/splash_page.dart      # 启动页：仅延迟 + 跳转，不做路由判断
│   ├── welcome/pages/welcome_page.dart    # 首次启动引导
│   ├── auth/pages/login_page.dart         # 登录页（mock）
│   └── home/pages/home_page.dart          # 首页：主题切换 + 退出登录
└── shared/
    └── widgets/
        ├── section_header.dart            # 分区标题
        ├── settings_tile.dart             # 设置项 / SettingsGroup
        └── widgets.dart                   # barrel export
```

## 启动流程

`main.dart` 的执行顺序：

1. `WidgetsFlutterBinding.ensureInitialized()`：确保 Flutter 引擎就绪。
2. `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)`：沉浸式布局。
3. `SharedPreferences.getInstance()`：拿到本地存储实例。
4. `ProviderContainer(overrides: [...])`：把 `sharedPreferencesProvider` 注入 Riverpod 依赖图。
5. `UncontrolledProviderScope`：将容器交给 `MyApp`，后续 Provider 都可同步读取。
6. `MyApp` 监听 `appRouterProvider`，搭配 `MaterialApp.router` 的 Material 3 主题（`themeMode: ThemeMode.system`，跟随系统）。

**为什么用 ProviderContainer 而不是直接 `ProviderScope`？**
`sharedPreferencesProvider` 是同步 Provider，但 `SharedPreferences.getInstance()` 是异步的。提前在 `main` 中 await 一次，再通过 `overrideWithValue` 注入，可以让所有下游 Provider（`tokenStorageProvider`、`dioProvider`、`appRouterProvider`）保持同步读取，避免在 Widget 里再触发一次异步等待。

## 路由与启动分流

`core/router/app_router.dart` 中定义：

- 路径常量：`AppRoutes.splash` / `welcome` / `login` / `home`。
- `initialLocation: /splash`。
- `redirect` 在每次导航时按以下规则统一派发：

| 当前路径 | 已看 Welcome | 已登录 | 目标 |
|---|---|---|---|
| `/splash` | — | — | 放行，由 splash 页面控制后续 |
| `/welcome` | 否 | — | 放行 |
| `/welcome` | 是 | 是 | `/home` |
| `/welcome` | 是 | 否 | `/login` |
| 其它 | 否 | — | `/welcome` |
| 其它 | 是 | 否 | `/login` |
| `/login` | 是 | 是 | `/home` |
| 其它 | 是 | 是 | 放行 |

`splash_page.dart` 只负责 800ms 启动延迟 + `context.go(AppRoutes.home)`，路由判断完全交给 `redirect`，避免两处重复判断状态。

## 网络层

`core/network/dio_client.dart` 创建的 Dio 实例带三段拦截器：

1. `AuthInterceptor`：自动注入 `Authorization: Bearer <accessToken>`；401 时用 `refreshDio`（独立的最小客户端，避免递归刷新）调用 `/api/auth/refresh`，成功后用新 token 重放原请求。
2. `LoggingInterceptor`（可关）：用 `logger` 包打印请求/响应/错误。
3. `ErrorInterceptor`：把 `DioException` 映射成 `ApiException` 子类（`BadRequestException` / `UnauthorizedException` / `ServerException` / `NetworkException` 等），业务层只看业务异常。

UI 展示用 `userFacingErrorMessage(error)` 抽取对用户友好的文案，避免暴露 Dio / ApiException 包装层。

## 本地存储

- `TokenStorage`：access / refresh / expiresAt，通过 `SharedPreferences` 持久化。`hasToken` 给路由守卫判断登录态。
- `AppLaunchStorage`：`hasSeenWelcome` / `markWelcomeSeen()`。

## 已知限制

- **build_runner 在 Dart 3.12.2 下不可用**：`analyzer_plugin` 与新版 `analyzer` 类型不兼容（`Element` vs `Element2`），Freezed / riverpod_generator 无法生成 `*.g.dart`。脚手架使用手写 Provider 与手写 `fromJson` / `toJson`。
- **Token 存储**：`SharedPreferences` 不是高安全级别方案；正式环境如需更严格保护可替换为 `flutter_secure_storage`，`TokenStorage` 对外接口保持不变。
- **依赖固定版本**：无；已移除 `adaptive_theme`，统一使用 Flutter 内置 Material 3 主题（`ThemeMode.system` 跟随系统）。

## 添加新 Feature

1. `lib/features/<name>/` 下按需建目录（脚手架仅放了 `pages/`，按业务复杂度可加 `application/providers/`、`data/repositories/`、`domain/entities/`）。
2. 在 `core/router/app_router.dart` 注册路由：
   ```dart
   GoRoute(path: '/foo', builder: (_, _) => const FooPage()),
   ```
3. 复杂页面用 `application/providers/` 暴露 Riverpod Provider，业务 Notifier 内部协调 `ApiClient` / Repository。
4. UI 通过 `ref.watch(...)` 读取状态，避免在 Widget 中直接调 Dio。

## 验证命令

```bash
flutter pub get

flutter analyze   # 静态分析

flutter test      # 运行测试

dart format lib test

# 检查业务异常用法（应返回空）
grep -r "DioException" lib/features/ lib/shared/
```

## 技术栈

| 类别 | 包 |
|---|---|
| 状态管理 | `flutter_riverpod` |
| 路由 | `go_router` |
| 网络 | `dio` |
| 本地存储 | `shared_preferences` |
| 主题 | Flutter Material 3（`useMaterial3: true`，`ThemeMode.system`）|
| 日志 | `logger` |
| 代码生成（占位） | `freezed_annotation` + `json_annotation` |
| 构建工具（占位） | `build_runner` |