import 'package:app_flutter/core/network/network.dart';
import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/auth/application/providers/auth_controller.dart';
import 'package:app_flutter/features/profile/application/providers/fitness_profile_provider.dart';
import 'package:app_flutter/shared/widgets/widgets.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';

/// 登录页。
///
/// 职责：
/// - 收集邮箱 + 密码，校验后调用 [AuthController.login]。
/// - 成功后同步健身档案：未完成引导则进问卷，已完成则进首页。
///
/// 数据流：`ConsumerStatefulWidget` → `authControllerProvider.notifier.login`
/// → `AuthRepository.login`（Dio）→ 写令牌 → 拉取用户资料。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  /// 表单校验器；也用于在提交前统一触发所有字段校验。
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController(text: "root@powertrack.com");
  final _passwordController = TextEditingController();

  /// 是否正在提交：防止重复点击造成多次登录请求。
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // 校验未通过（格式错误/空值）直接返回，由 Form 里的错误文案提示用户。
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    await ref
        .read(authControllerProvider.notifier)
        .login(email: _emailController.text.trim(), password: _passwordController.text);

    if (!mounted) return;

    final state = ref.read(authControllerProvider);
    // 先判 hasError：AsyncNotifier 切换状态时会 copyWithPrevious 保留 hasValue，
    // 登录失败后的 AsyncError 其 hasValue 仍为 true，若先判 hasValue 会误走成功分支。
    if (state.hasError) {
      // 失败：用 expressive snack 展示用户可读文案（错误 icon + 8 秒展示时长）。
      showExpressiveSnack(
        context: context,
        message: userFacingErrorMessage(state.error),
        icon: Symbols.error_outline_rounded,
        duration: const Duration(seconds: 8),
      );
    } else if (state.hasValue) {
      // 登录成功：先同步档案，未完成引导则进问卷而不是首页。
      HapticFeedback.lightImpact();
      try {
        final profile = await ref.read(fitnessProfileProvider.notifier).syncFromServer();
        if (!mounted) return;
        context.go(profile == null ? AppRoutes.onboarding : AppRoutes.home);
      } catch (_) {
        if (!mounted) return;
        context.go(AppRoutes.onboarding);
      }
    }
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: const Text('登录'),
        actions: [
          M3ETextButton(
            onPressed: () {
              context.push(AppRoutes.emailVerify);
            },
            child: Text("验证邮箱"),
          ),
        ],
      ),
      body: SafeArea(
        // 顶部让给毛玻璃栏：内容从 appBarInset 之下开始，底部保留手势条留白。
        top: false,
        child: SingleChildScrollView(
          // 输入完成后滚动即收起键盘。
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(24, context.appBarInset + 32, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 24,
              children: [
                AppShapeIcon(icon: Symbols.email, shape: Shapes.softBurst, size: 100, iconSize: 32, filled: false),
                M3ESegmentedColumn(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  children: [
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      onTapUpOutside: (event) => FocusScope.of(context).unfocus(),
                      decoration: const InputDecoration(hintText: '邮箱', prefixIcon: Icon(Symbols.mail_outline_rounded)),
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
                      autofillHints: const [AutofillHints.password],
                      onTapUpOutside: (event) => FocusScope.of(context).unfocus(),
                      decoration: const InputDecoration(hintText: '密码', prefixIcon: Icon(Symbols.lock_outline_rounded)),
                      validator: (value) {
                        if (value == null || value.isEmpty) return '请输入密码';
                        // 后端对密码有 min_length=6 约束，前端先拦截，避免无谓请求。
                        if (value.length < 6) return '密码至少 6 位';
                        return null;
                      },
                      onFieldSubmitted: (_) => _submitting ? null : _submit(),
                    ),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 12,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: M3EButton(
                        size: M3EButtonSize.md,
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox(width: 20, height: 20, child: M3ELoadingIndicator())
                            : const Text('登录'),
                      ),
                    ),

                    M3ETextButton(
                      size: M3EButtonSize.md,
                      onPressed: () {
                        context.push(AppRoutes.emailRegister);
                      },
                      child: Text("注册"),
                    ),
                    M3ETextButton(
                      size: M3EButtonSize.sm,
                      onPressed: () {
                        context.push(AppRoutes.forgotPassword);
                      },
                      child: Text("忘记密码？"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
