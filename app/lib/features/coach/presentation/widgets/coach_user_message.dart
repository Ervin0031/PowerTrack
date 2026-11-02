import 'package:material_ui/material_ui.dart';

/// 用户说的话。靠右，大圆角色块托住，没有描边和投影。
///
/// 不用 Expressive 的多边形裁切。那些形状按固定路径缩放，多行字会被切掉。
class CoachUserMessage extends StatelessWidget {
  const CoachUserMessage({super.key, required this.text});

  /// 用户原文。
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.84),
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 28),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: scheme.onPrimaryContainer,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
