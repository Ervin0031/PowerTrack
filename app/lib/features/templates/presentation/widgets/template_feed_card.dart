import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/templates/domain/entities/workout_template.dart';
import 'package:app_flutter/shared/widgets/app_network_image.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 模板列表一行：封面、标题、摘要，没有卡片底。
class TemplateFeedCard extends StatelessWidget {
  const TemplateFeedCard({super.key, required this.item, this.onTap});

  final WorkoutTemplate item;
  final VoidCallback? onTap;

  static const _coverSize = 64.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final meta = [
      item.difficulty.label,
      '${item.exerciseCount} 动作',
      '${item.setCount} 组',
      '完成 ${item.completionCount}',
      if (!item.isOwner) item.ownerUsername,
      item.isPublic ? '公开' : '私密',
    ].where((part) => part.trim().isNotEmpty).join(' · ');
    final tags = [
      ...item.primaryMuscles.take(2).map((m) => m.name),
      ...item.equipment.take(1).map((e) => e.name),
    ];
    final extraMuscles = item.primaryMuscles.length > 2
        ? item.primaryMuscles.length - 2
        : 0;
    final extraEq = item.equipment.length > 1 ? item.equipment.length - 1 : 0;
    final extra = extraMuscles + extraEq;
    if (extra > 0) tags.add('+$extra');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Cover(item: item),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (tags.isNotEmpty)
                    Text(
                      tags.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.item});

  final WorkoutTemplate item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (item.coverUrl != null) {
      return AppNetworkImage(
        url: item.coverUrl,
        size: TemplateFeedCard._coverSize,
        radius: 12,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.field),
      child: ColoredBox(
        color: cs.primaryContainer,
        child: SizedBox(
          width: TemplateFeedCard._coverSize,
          height: TemplateFeedCard._coverSize,
          child: Icon(
            Symbols.exercise_rounded,
            color: cs.onPrimaryContainer,
            size: 28,
          ),
        ),
      ),
    );
  }
}
