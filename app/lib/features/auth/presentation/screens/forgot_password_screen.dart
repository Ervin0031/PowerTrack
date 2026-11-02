import 'package:app_flutter/core/network/network.dart';
import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/auth/application/providers/auth_controller.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';

/// 找回密码页。
///
/// 职责：填写邮箱提交 [AuthController.forgotPassword]，由后端发送重置邮件。
/// 成功后带邮箱跳转重置密码页（[ResetPasswordScreen]）。
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).forgotPassword(
        email: _emailController.text.trim(),
      );
      if (!mounted) return;
      // 无论邮箱是否存在后端都返回成功，故直接提示并带入邮箱跳重置页。
      showExpressiveSnack(
        context: context,
        message: '若该邮箱已注册，重置邮件已发送',
        icon: Symbols.check_circle_outline_rounded,
        duration: const Duration(seconds: 4),
      );
      context.pushReplacement(
        AppRoutes.resetPassword,
        extra: {'email': _emailController.text.trim()},
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
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: const Text('找回密码')),
      body: SafeArea(
        // 顶部让给毛玻璃栏：内容从 appBarInset 之下开始，底部保留手势条留白。
        top: false,
        child: Center(
          child: SingleChildScrollView(
            // 输入完成后滚动即收起键盘。
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(24, context.appBarInset + 32, 24, 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 24,
                children: [
                  Text(
                    '输入注册邮箱，我们将发送验证码用于重置密码。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  M3ESegmentedColumn(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: [
                      TextFormField(
                        controller: _emailController,
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onTapUpOutside: (_) => FocusScope.of(context).unfocus(),
                        decoration: const InputDecoration(
                          hintText: '邮箱',
                          prefixIcon: Icon(Symbols.mail_outline_rounded),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return '请输入邮箱';
                          if (!v.contains('@')) return '邮箱格式不正确';
                          return null;
                        },
                        onFieldSubmitted: (_) => _submitting ? null : _submit(),
                      ),
                    ],
                  ),
                  M3EButton(
                    size: M3EButtonSize.md,
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20, child: M3ELoadingIndicator())
                        : const Text('发送验证码'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
