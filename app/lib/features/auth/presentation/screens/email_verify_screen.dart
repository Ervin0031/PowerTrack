import 'package:app_flutter/core/network/network.dart';
import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/auth/application/providers/auth_controller.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';

/// 邮箱验证页。
///
/// 职责：展示注册时填写的邮箱（由注册页通过 [GoRouterState.extra] 传入），
/// 仅收集 6 位验证码，调用 [AuthController.verifyEmail]，验证成功后返回登录页。
/// 提供「重发验证邮件」入口（[AuthController.resendVerification]）。
///
/// 验证码输入使用 m3e 风格的 [PinInput]：焦点格每次获得焦点会随机切换形状。
class EmailVerifyScreen extends ConsumerStatefulWidget {
  const EmailVerifyScreen({super.key, this.email});

  /// 来自注册成功页带入的邮箱，仅展示用。
  final String? email;

  @override
  ConsumerState<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends ConsumerState<EmailVerifyScreen> {
  bool _submitting = false;
  bool _resending = false;
  String _code = '';

  Future<void> _verify(String code) async {
    if (_submitting) return;
    final email = widget.email?.trim() ?? '';
    if (email.isEmpty || !email.contains('@')) {
      showExpressiveSnack(
        context: context,
        message: '邮箱信息缺失，无法验证',
        icon: Symbols.error_outline_rounded,
        duration: const Duration(seconds: 8),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).verifyEmail(email: email, code: code);
      if (!mounted) return;
      showExpressiveSnack(
        context: context,
        message: '邮箱验证成功，请登录',
        icon: Symbols.check_circle_outline_rounded,
        duration: const Duration(seconds: 4),
      );
      context.go(AppRoutes.login);
    } catch (error) {
      if (!mounted) return;
      showExpressiveSnack(
        context: context,
        message: userFacingErrorMessage(error),
        icon: Symbols.error_outline_rounded,
        duration: const Duration(seconds: 8),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resend() async {
    final email = widget.email?.trim() ?? '';
    if (email.isEmpty || !email.contains('@')) {
      showExpressiveSnack(
        context: context,
        message: '请先填写正确的邮箱',
        icon: Symbols.error_outline_rounded,
        duration: const Duration(seconds: 8),
      );
      return;
    }

    setState(() => _resending = true);
    try {
      await ref.read(authControllerProvider.notifier).resendVerification(email: email);
      if (!mounted) return;
      showExpressiveSnack(
        context: context,
        message: '验证邮件已重新发送',
        icon: Symbols.check_circle_outline_rounded,
        duration: const Duration(seconds: 4),
      );
    } catch (error) {
      if (!mounted) return;
      showExpressiveSnack(
        context: context,
        message: userFacingErrorMessage(error),
        icon: Symbols.error_outline_rounded,
        duration: const Duration(seconds: 8),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: const Text('验证邮箱')),
      body: SafeArea(
        // 顶部让给毛玻璃栏：内容从 appBarInset 之下开始，底部保留手势条留白。
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, context.appBarInset + 32, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 24,
            children: [
              AppShapeIcon(icon: Symbols.verified_user_rounded, shape: Shapes.ghostish, size: 100, iconSize: 42, filled: false),
              Text('我们已向你的邮箱发送验证码，请查收并填写。', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),

              // 以文本方式展示注册邮箱（不可编辑）。
              M3ESegmentedColumn(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                children: [
                  Row(
                    children: [
                      Icon(Symbols.mail_outline_rounded, color: cs.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.email?.trim().isNotEmpty == true
                              ? widget.email!.trim()
                              : '未获取到邮箱',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              PinInput(
                length: 6,
                autoFocus: true,
                keyboardType: TextInputType.number,
                onChanged: (value) => _code = value,
                onCompleted: _verify,
                cellBuilder: (context, cell, index) {
                  final cs = Theme.of(context).colorScheme;
                  final focused = cell.isFocused;
                  return M3EContainer(
                    cell.shape,
                    width: 48,
                    height: 48,
                    color: focused ? cs.primary : cs.primaryContainer,
                    child: Center(
                      child: Text(
                        cell.character ?? '',
                        style: TextStyle(fontSize: 24, color: focused ? cs.onPrimary : cs.onPrimaryContainer),
                      ),
                    ),
                  );
                },
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  M3EButton(
                    size: M3EButtonSize.md,
                    onPressed: _submitting || _code.length < 6 ? null : () => _verify(_code),
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20, child: M3ELoadingIndicator())
                        : const Text('验证'),
                  ),
                  M3ETextButton(
                    size: M3EButtonSize.md,
                    onPressed: _resending ? null : _resend,
                    child: _resending
                        ? const SizedBox(width: 16, height: 16, child: M3ELoadingIndicator())
                        : const Text('重新发送验证邮件'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
