import 'package:app_flutter/features/exercises/application/providers/exercises_provider.dart';
import 'package:app_flutter/shared/widgets/app_network_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

/// 40px 动作封面。本地没有地址或加载失败时退回圆形符号。
class ExerciseThumb extends ConsumerWidget {
  const ExerciseThumb({super.key, required this.exerciseId, required this.fallback});

  final int exerciseId;
  final IconData fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncUrl = ref.watch(exerciseImageUrlProvider(exerciseId));
    final url = asyncUrl.asData?.value;
    if (asyncUrl.isLoading) {
      return M3EContainer(
        Shapes.circle,
        width: 40,
        height: 40,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: SizedBox(),
      );
    }
    if (url == null || url.isEmpty) return _Fallback(icon: fallback);
    final cs = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cache = (40 * dpr).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 40,
        height: 40,
        child: CachedNetworkImage(
          imageUrl: url,
          cacheKey: stableImageCacheKey(url),
          fit: BoxFit.cover,
          memCacheWidth: cache,
          memCacheHeight: cache,
          maxWidthDiskCache: cache,
          maxHeightDiskCache: cache,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (_, _) => ColoredBox(color: cs.surfaceContainerHighest),
          errorWidget: (_, _, _) => _Fallback(icon: fallback),
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return M3EContainer(
      Shapes.circle,
      width: 40,
      height: 40,
      color: cs.primaryContainer,
      child: Icon(icon, size: 20, color: cs.onPrimaryContainer, fill: 1),
    );
  }
}
