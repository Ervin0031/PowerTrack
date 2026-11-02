import 'package:app_flutter/core/router/router_names.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';

/// 启动页。
///
/// 职责：
/// - 展示短暂启动过渡（让首帧与启动动画有机会出现）。
/// - 不做路由决策；超时后跳转 `/`，由 `appRouterProvider` 的 `redirect` 统一决定
///   Welcome / Login / Home 的最终目的地，避免两处重复判断状态。
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    // 异步等待后 Widget 可能已经销毁，导航前必须检查 mounted。
    if (!mounted) return;
    // 跳到 `/`，redirect 会按 hasSeenWelcome / hasToken 重新派发到 welcome|login|home。
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: M3ECircularWavyProgressIndicator()));
  }
}
