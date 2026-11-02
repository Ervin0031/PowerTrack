import 'package:flutter/foundation.dart';

/// 应用级静态配置入口。
///
/// 职责：
/// - 集中管理 App 名称、网络参数与 UI 设计稿尺寸。
/// - 通过 `String.fromEnvironment` / `bool.fromEnvironment` 支持编译期环境覆盖。
///
/// ⚠️ 注意：
/// 这里不读取运行时远程配置；如果需要动态切环境，应在更上层注入配置对象。
abstract final class AppConfig {
  /// 应用标题，供 MaterialApp、系统任务列表等位置复用。
  static const appName = String.fromEnvironment('APP_NAME', defaultValue: 'PowerTrack');

  /// 网络默认配置。
  ///
  /// `BASE_URL` 和 `ENABLE_HTTP_LOG` 可通过 `--dart-define` 覆盖，便于 dev/staging/prod 共用模板。
  ///
  /// 日志默认跟随 [kDebugMode]：debug 打开、release 关闭，避免生产环境打印
  /// 网络请求拖慢性能或泄露敏感信息。
  static const network = NetworkConfig(
    baseUrl: String.fromEnvironment(
      'BASE_URL',
      defaultValue: 'http://localhost:8000',
    ),
    connectTimeout: Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 30),
    sendTimeout: Duration(seconds: 30),
    enableLogging: bool.fromEnvironment('ENABLE_HTTP_LOG', defaultValue: kDebugMode),
  );

  /// UI 适配基准尺寸，通常取设计稿宽高。
  static const ui = UiConfig(designWidth: 390, designHeight: 844);

  /// 右上角 FPS 浮层。debug 默认开；release 默认关。
  /// 可用 `--dart-define=SHOW_FPS=true|false` 强制开关。
  static const showFps = bool.fromEnvironment('SHOW_FPS', defaultValue: kDebugMode);

  /// Flutter 自带性能图（顶部 UI/GPU 条）。需要时再开，遮挡较多。
  /// `--dart-define=SHOW_PERFORMANCE_OVERLAY=true`
  static const showPerformanceOverlay = bool.fromEnvironment('SHOW_PERFORMANCE_OVERLAY', defaultValue: false);
}

/// 网络层基础参数。
///
/// DioClient 会读取这里的 baseUrl、超时与日志开关，避免网络配置散落在各个 API 调用里。
class NetworkConfig {
  const NetworkConfig({
    required this.baseUrl,
    required this.connectTimeout,
    required this.receiveTimeout,
    required this.sendTimeout,
    required this.enableLogging,
  });

  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sendTimeout;
  final bool enableLogging;
}

/// 设计稿基准尺寸（预留参数，当前无消费方）。
class UiConfig {
  const UiConfig({required this.designWidth, required this.designHeight});

  final double designWidth;
  final double designHeight;
}
