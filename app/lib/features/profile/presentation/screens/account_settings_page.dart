import 'package:app_flutter/core/network/error_message.dart';
import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/auth/application/providers/auth_controller.dart';
import 'package:app_flutter/features/auth/data/models/user_model.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 账号设置：改用户名 / 邮箱、注销账号。
///
/// 改密码不在此页（走 `POST /auth/change-password` 的独立页面）。
class AccountSettingsPage extends ConsumerStatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  ConsumerState<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends ConsumerState<AccountSettingsPage> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();

  /// 已把服务端资料灌进输入框的标记，避免每次重建都覆盖用户正在编辑的内容。
  bool _prefilled = false;
  bool _saving = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save(UserProfile user) async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    if (username.isEmpty || email.isEmpty) {
      showExpressiveSnack(context: context, message: '用户名和邮箱不能为空', icon: Symbols.error_outline_rounded);
      return;
    }
    if (username == user.username && email == user.email) {
      showExpressiveSnack(context: context, message: '没有需要保存的修改');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(authControllerProvider.notifier).updateAccount(
            username: username == user.username ? null : username,
            email: email == user.email ? null : email,
          );
      if (!mounted) return;
      showExpressiveSnack(context: context, message: '已保存');
    } catch (error) {
      if (!mounted) return;
      showExpressiveSnack(
        context: context,
        message: userFacingErrorMessage(error),
        icon: Symbols.error_outline_rounded,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 注销不可恢复，要求手输用户名二次确认。
  Future<void> _deleteAccount(UserProfile user) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('注销账号'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('账号与全部训练记录将被永久删除，无法恢复。\n输入用户名以确认：'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(hintText: user.username),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
            FilledButton(
              onPressed: controller.text.trim() == user.username ? () => Navigator.of(ctx).pop(true) : null,
              child: const Text('永久删除'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
      if (!mounted) return;
      showExpressiveSnack(context: context, message: '账号已注销');
      context.go(AppRoutes.login);
    } catch (error) {
      if (!mounted) return;
      showExpressiveSnack(
        context: context,
        message: userFacingErrorMessage(error),
        icon: Symbols.error_outline_rounded,
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(authControllerProvider).value;

    if (user != null && !_prefilled) {
      _prefilled = true;
      _usernameController.text = user.username;
      _emailController.text = user.email;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: Text('管理账号')),
      body: user == null
          ? const Center(child: M3ELoadingIndicator())
          : ListView(
              padding: const EdgeInsets.all(16).add(EdgeInsets.only(top: context.appBarInset)),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('账号资料', style: textTheme.titleMedium),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _usernameController,
                          enabled: !_saving,
                          decoration: const InputDecoration(labelText: '用户名', helperText: '3–50 个字符'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailController,
                          enabled: !_saving,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: '邮箱', helperText: '用于登录与找回密码'),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: M3EButton(
                            onPressed: _saving ? null : () => _save(user),
                            child: _saving
                                ? const SizedBox(width: 20, height: 20, child: M3ELoadingIndicator())
                                : const Text('保存'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('危险操作', style: textTheme.titleMedium),
                const SizedBox(height: 8),
                M3ESegmentedColumn(
                  onTap: (_) {
                    if (!_saving) _deleteAccount(user);
                  },
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(child: Icon(Symbols.delete_forever_rounded, color: colorScheme.error)),
                      title: Text('注销账号', style: TextStyle(color: colorScheme.error)),
                      subtitle: const Text('永久删除账号与全部训练记录'),
                      trailing: const Icon(Symbols.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '注销后无法恢复；如需保留数据，请先导出。',
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
    );
  }
}
