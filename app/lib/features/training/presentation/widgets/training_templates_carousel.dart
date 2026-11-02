import 'package:app_flutter/core/router/router_names.dart';
import 'package:app_flutter/core/ui/app_scroll_behavior.dart';
import 'package:app_flutter/core/ui/ui.dart';
import 'package:app_flutter/features/templates/domain/entities/workout_template.dart';
import 'package:app_flutter/features/training/application/providers/training_templates_carousel_provider.dart';
import 'package:app_flutter/shared/widgets/app_network_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 训练首页底部：模板 Carousel 展示区。
class TrainingTemplatesCarousel extends ConsumerWidget {
  const TrainingTemplatesCarousel({super.key});

  static const _height = 300.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trainingTemplatesCarouselProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return async.when(
      loading: () => const SizedBox(
        height: _height + 48,
        child: Center(child: M3ELoadingIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (items) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Text('训练模板', style: tt.titleLarge),
                  const Spacer(),
                  M3ETextButton(onPressed: () => context.push(AppRoutes.templates), child: const Text('全部')),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: _height,
                child: NotificationListener<OverscrollNotification>(
                  onNotification: (_) => true,
                  child: ScrollConfiguration(
                    behavior: const NestedHorizontalScrollBehavior(),
                    child: CarouselView(
                      itemExtent: 300,
                      shrinkExtent: 80,
                      itemSnapping: true,
                      // padding: const EdgeInsets.only(right: 12),
                      backgroundColor: cs.surfaceContainerLowest,
                      // elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
                      onTap: (index) {
                        if (index >= items.length) {
                          context.push(AppRoutes.templateCreate);
                        } else {
                          context.push(AppRoutes.templateDetailOf(items[index].id));
                        }
                      },
                      children: [
                        for (final item in items) _CarouselCard(item: item),
                        const _CreateCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CreateCard extends StatelessWidget {
  const _CreateCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Text(
          '+ 新建',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface),
        ),
      ),
    );
  }
}

class _CarouselCard extends StatelessWidget {
  const _CarouselCard({required this.item});

  final WorkoutTemplate item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final meta = '${item.exerciseCount} 动作 · ${item.setCount} 组 · ${item.difficulty.label}';
    final cover = item.coverUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (cover != null)
          CachedNetworkImage(
            imageUrl: cover,
            // 封面 URL 仍是 presigned（签名每次不同），剥离签名才能命中磁盘缓存。
            cacheKey: stableImageCacheKey(cover),
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 280),
            placeholder: (_, _) => ColoredBox(color: cs.surfaceContainerHighest),
            errorWidget: (_, _, _) => ColoredBox(
              color: cs.primaryContainer,
              child: Icon(Symbols.exercise_rounded, size: 48, color: cs.onPrimaryContainer),
            ),
          )
        else
          ColoredBox(
            color: cs.primaryContainer,
            child: Icon(Symbols.exercise_rounded, size: 48, color: cs.onPrimaryContainer),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, cs.scrim.withValues(alpha: 0.72)],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              M3EContainer(
                Shapes.pill,
                color: cs.secondaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Text(item.difficulty.label, style: tt.labelSmall?.copyWith(color: cs.onSecondaryContainer)),
              ),
              const Spacer(),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
