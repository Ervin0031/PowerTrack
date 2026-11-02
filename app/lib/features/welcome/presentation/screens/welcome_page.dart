import 'package:app_flutter/core/providers/dio_provider.dart';
import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';

/// 欢迎页。
///
/// 职责：
/// - 作为首次启动引导占位页面。
/// - 用户点击开始后标记 Welcome 已完成，再进入登录流程。
class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: GlassAppBar(title: const Text('Welcome')),
      body: Center(
        child: M3EButton(
          size: M3EButtonSize.md,
          onPressed: () async {
            await ref.read(appLaunchStorageProvider).markWelcomeSeen();
            // 异步写入后再导航，确保下一次启动不会重复进入 Welcome。
            if (context.mounted) context.go(AppRoutes.login);
          },
          child: const Text('Get started'),
        ),
      ),
    );
  }
}
