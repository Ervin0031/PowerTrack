import 'package:app_flutter/core/network/ai_error.dart';
import 'package:app_flutter/core/ui/glass_app_bar.dart';
import 'package:app_flutter/core/ui/safe_area_ext.dart';
import 'package:app_flutter/features/settings/application/providers/ai_settings_provider.dart';
import 'package:app_flutter/features/settings/domain/entities/ai_settings.dart';
import 'package:expressive_snack/expressive_snack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 自带 AI Key 的设置页。Key 只写本机安全存储，不经过 PowerTrack 后端。
class AiSettingsPage extends ConsumerStatefulWidget {
  const AiSettingsPage({super.key});

  @override
  ConsumerState<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends ConsumerState<AiSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _key = TextEditingController();
  final _baseUrl = TextEditingController();
  final _model = TextEditingController();
  var _initialized = false;
  var _obscure = true;
  var _testing = false;
  var _saving = false;
  var _clearing = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(aiSettingsProvider).valueOrNull;
    _baseUrl.text = settings?.baseUrl ?? AiSettings.defaultBaseUrl;
    _model.text = settings?.model ?? AiSettings.defaultModel;
  }

  @override
  void dispose() {
    _key.dispose();
    _baseUrl.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(aiSettingsProvider).valueOrNull;
    ref.listen(aiSettingsProvider, (previous, next) {
      final value = next.valueOrNull;
      if (value == null || _initialized) return;
      _initialized = true;
      _baseUrl.text = value.baseUrl;
      _model.text = value.model;
    });

    final hasKey = settings?.hasKey ?? false;
    final busy = _testing || _saving || _clearing;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: const Text('AI 教练')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(24, context.appBarInset + 24, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 20,
              children: [
                Text(
                  '用自己的 API Key 直连模型服务。Key 只保存在本机安全存储，'
                  '并直接发送到你填写的地址，不经过 PowerTrack 服务器。'
                  '请只填写可信的 HTTPS 地址。',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.45),
                ),
                M3ESegmentedColumn(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    TextFormField(
                      controller: _key,
                      obscureText: _obscure,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: hasKey ? '已保存，留空表示不修改' : 'API Key',
                        prefixIcon: const Icon(Symbols.key_rounded),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: IconButton(
                            tooltip: _obscure ? '显示' : '隐藏',
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Symbols.visibility_rounded : Symbols.visibility_off_rounded),
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (hasKey) return null;
                        if (value == null || value.trim().isEmpty) {
                          return '请输入 API Key';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _baseUrl,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: AiSettings.defaultBaseUrl,
                        // labelText: '接口地址',
                        prefixIcon: Icon(Symbols.link_rounded),
                      ),
                      validator: (value) => validateAiBaseUrl(value),
                    ),
                    TextFormField(
                      controller: _model,
                      autocorrect: false,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        hintText: AiSettings.defaultModel,
                        // labelText: '模型（需支持工具调用）',
                        prefixIcon: Icon(Symbols.memory_rounded),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入模型名';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                Row(
                  spacing: 12,
                  children: [
                    Expanded(
                      child: M3EOutlinedButton(
                        size: .md,
                        onPressed: busy ? null : _test,
                        child: _testing
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('测试连接'),
                      ),
                    ),
                    Expanded(
                      child: M3EFilledButton(
                        size: .md,
                        onPressed: busy ? null : _save,
                        child: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('保存'),
                      ),
                    ),
                  ],
                ),
                if (hasKey) TextButton(onPressed: busy ? null : _clear, child: const Text('清除已保存的 Key')),
                Text(
                  '对话记录仍会保存到 PowerTrack 服务器，但不会包含你的 Key。'
                  'AI 请求可能产生费用，请留意服务商的价格。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _test() async {
    if (!_formKey.currentState!.validate()) return;
    final key = _key.text.trim().isEmpty ? await ref.read(aiSettingsRepositoryProvider).readApiKey() : _key.text.trim();
    if (!mounted) return;
    if (key == null || key.isEmpty) {
      _snack('请先填写 API Key');
      return;
    }
    setState(() => _testing = true);
    try {
      await ref
          .read(aiSettingsRepositoryProvider)
          .testConnection(baseUrl: _baseUrl.text, model: _model.text, apiKey: key);
      if (mounted) _snack('连接成功', ok: true);
    } catch (error) {
      if (mounted) _snack(aiErrorMessage(error));
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await ref.read(aiSettingsProvider.notifier).save(baseUrl: _baseUrl.text, model: _model.text, apiKey: _key.text);
    if (!mounted) return;
    setState(() => _saving = false);
    final result = ref.read(aiSettingsProvider);
    if (result.hasError) {
      _snack('保存失败，请重试');
      return;
    }
    _key.clear();
    _baseUrl.text = result.valueOrNull?.baseUrl ?? _baseUrl.text;
    _model.text = result.valueOrNull?.model ?? _model.text;
    _snack('已保存', ok: true);
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除 API Key？'),
        content: const Text('清除后 AI 教练会停用，直到重新填写。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('清除')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearing = true);
    await ref.read(aiSettingsProvider.notifier).clearApiKey();
    if (!mounted) return;
    setState(() => _clearing = false);
    if (ref.read(aiSettingsProvider).hasError) {
      _snack('清除失败，请重试');
      return;
    }
    _key.clear();
    _snack('已清除', ok: true);
  }

  void _snack(String message, {bool ok = false}) {
    showExpressiveSnack(
      context: context,
      message: message,
      icon: ok ? Symbols.check_circle_outline_rounded : Symbols.error_outline_rounded,
    );
  }
}
