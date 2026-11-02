import 'package:app_flutter/core/ui/ui.dart';
import 'package:material_ui/material_ui.dart';

/// 引导页大按钮卡片：点击即选中。
class OnboardingChoiceCard extends StatelessWidget {
  const OnboardingChoiceCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.hint,
  });

  final String label;
  final String? hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: selected ? cs.primaryContainer : cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: hint == null ? 18 : 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selected ? cs.onPrimaryContainer : cs.onSurface,
                      ),
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        hint!,
                        style: tt.bodySmall?.copyWith(
                          color: selected ? cs.onPrimaryContainer.withValues(alpha: 0.8) : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? cs.primary : cs.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
