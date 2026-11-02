import 'package:app_flutter/core/network/network.dart';
import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/auth/application/providers/auth_controller.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';

/// 注册页。
///
/// 职责：收集用户名 + 邮箱 + 密码，校验后调用 [AuthController.register]。
/// 成功后不自动登录（后端要求先验证邮箱），跳转邮箱验证页并带入邮箱。
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).register(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      // 注册成功 → 跳转邮箱验证页（带邮箱），等待用户校验后登录。
      HapticFeedback.lightImpact();
      context.pushReplacement(
        AppRoutes.emailVerify,
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
      appBar: GlassAppBar(title: const Text('注册')),
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
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        onTapUpOutside: (_) => FocusScope.of(context).unfocus(),
                        decoration: const InputDecoration(
                          hintText: '用户名',
                          prefixIcon: Icon(Symbols.person_outline_rounded),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return '请输入用户名';
                          if (v.length < 3) return '用户名至少 3 位';
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
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
                        controller: _passwordController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onTapUpOutside: (_) => FocusScope.of(context).unfocus(),
                        decoration: const InputDecoration(
                          hintText: '密码',
                          prefixIcon: Icon(Symbols.lock_outline_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return '请输入密码';
                          if (value.length < 6) return '密码至少 6 位';
                          return null;
                        },
                        onFieldSubmitted: (_) => _submitting ? null : _submit(),
                      ),
                    ],
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      M3EButton(
                        size: M3EButtonSize.md,
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(width: 20, height: 20, child: M3ELoadingIndicator())
                            : const Text('注册'),
                      ),
                      M3ETextButton(
                        size: M3EButtonSize.md,
                        onPressed: () => context.pop(),
                        child: const Text('已有账号？去登录'),
                      ),
                    ],
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
