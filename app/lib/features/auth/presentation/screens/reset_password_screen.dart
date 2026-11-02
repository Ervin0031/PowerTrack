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

/// 重置密码页。
///
/// 职责：输入邮箱 + 邮件验证码 + 新密码，调用 [AuthController.resetPassword]。
/// 成功后返回登录页。
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.email});

  /// 来自找回密码页带入的邮箱，可直接预填。
  final String? email;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.email != null) _emailController.text = widget.email!;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).resetPassword(
        email: _emailController.text.trim(),
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      showExpressiveSnack(
        context: context,
        message: '密码已重置，请登录',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: const Text('重置密码')),
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
                  M3ESegmentedColumn(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
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
                      ),
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        onTapUpOutside: (_) => FocusScope.of(context).unfocus(),
                        decoration: const InputDecoration(
                          hintText: '验证码',
                          prefixIcon: Icon(Symbols.confirmation_number_rounded),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return '请输入验证码';
                          if (v.length < 4) return '验证码格式不正确';
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onTapUpOutside: (_) => FocusScope.of(context).unfocus(),
                        decoration: const InputDecoration(
                          hintText: '新密码',
                          prefixIcon: Icon(Symbols.lock_outline_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return '请输入新密码';
                          if (value.length < 6) return '密码至少 6 位';
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
                        : const Text('重置密码'),
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
