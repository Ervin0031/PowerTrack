import 'package:app_flutter/core/network/network.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/auth/application/providers/auth_controller.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';

/// 修改密码页（已登录）。
///
/// 职责：输入旧密码 + 新密码，调用 [AuthController.changePassword]。
/// 成功返回上一页；失败展示错误（如旧密码错误）。
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).changePassword(
        oldPassword: _oldController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      showExpressiveSnack(
        context: context,
        message: '密码修改成功',
        icon: Symbols.check_circle_outline_rounded,
        duration: const Duration(seconds: 4),
      );
      context.pop();
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
      appBar: GlassAppBar(title: const Text('修改密码')),
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
                        controller: _oldController,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.password],
                        onTapUpOutside: (_) => FocusScope.of(context).unfocus(),
                        decoration: const InputDecoration(
                          hintText: '旧密码',
                          prefixIcon: Icon(Symbols.lock_outline_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return '请输入旧密码';
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: _newController,
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
                          if (value == _oldController.text) return '新密码不能与旧密码相同';
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
                        : const Text('保存'),
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
