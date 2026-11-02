import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 还没配 API Key 时的空状态。
class CoachAiSetupPrompt extends StatelessWidget {
  const CoachAiSetupPrompt({super.key, required this.onSetup});

  /// 打开 AI 设置页。
  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 48, bottom: 24),
      child: Column(
        children: [
          M3EContainer(
            .sunny,
            color: scheme.primaryContainer,
            padding: const EdgeInsets.all(18),
            child: Icon(Symbols.key_rounded, color: scheme.onPrimaryContainer, size: 28),
          ),
          const SizedBox(height: 20),
          Text('先放上你的 Key', style: textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            '教练在这台手机上直接问模型。Key 只留在本机，不经过服务器。',
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
          ),
          const SizedBox(height: 20),
          M3EButton(onPressed: onSetup, child: const Text('去设置')),
        ],
      ),
    );
  }
}

/// 训练档案还没填时的一句提示。
class CoachProfilePrompt extends StatelessWidget {
  const CoachProfilePrompt({super.key, required this.onFill});

  /// 打开健身档案页。
  final VoidCallback onFill;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '先写一下器械、伤病和每次想练多久。',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          M3EButton(onPressed: onFill, style: M3EButtonStyle.text, child: const Text('去写')),
        ],
      ),
    );
  }
}

/// 发送失败时的一行说明。
class CoachErrorLine extends StatelessWidget {
  const CoachErrorLine({super.key, required this.message});

  /// 已经转成用户能看的错误文案。
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(message, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.error)),
    );
  }
}

/// 还没有消息时的问候，和可以直接发出去的几句话。
class CoachEmptyHint extends StatelessWidget {
  const CoachEmptyHint({super.key, required this.onSuggest});

  /// 点某一句时送出的原文。档案没写完时为空，句子不可点。
  final ValueChanged<String>? onSuggest;

  static const _lines = <(String, String)>[
    ('按档案排今天这一堂', '按我的档案排今天这一堂力量训练'),
    ('看看最近练得怎么样', '给我分析最近训练数据'),
    ('肌群恢复得如何', '看看我的肌群恢复和本周容量'),
    ('今天适不适合加量', '结合睡眠和恢复，看看今天适不适合加量'),
    ('练前怎么热身', '按今天的训练给我一份热身'),
    ('练完怎么放松', '练完给我一份放松和拉伸'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 36, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          M3EContainer(
            .verySunny,
            color: scheme.primaryContainer,
            padding: const EdgeInsets.all(16),
            child: Icon(Symbols.auto_awesome_rounded, fill: 1, color: scheme.onPrimaryContainer, size: 28),
          ),
          const SizedBox(height: 28),
          Text('今天\n练什么', style: textTheme.displaySmall),
          const SizedBox(height: 20),
          for (final line in _lines)
            InkWell(
              onTap: onSuggest == null ? null : () => onSuggest!(line.$2),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  line.$1,
                  style: textTheme.titleLarge?.copyWith(
                    color: onSuggest == null ? scheme.onSurface.withValues(alpha: 0.38) : scheme.onSurface,
                    height: 1.3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
