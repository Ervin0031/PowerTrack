import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

/// 网络图片的稳定缓存键。
///
/// S3 presigned URL 每次签发的 query 都不同（缓存键 = 完整 URL 会永远 miss），
/// 但对象路径本身稳定 —— 去掉签名 query 即可长期命中。非签名 URL（后端稳定
/// 端点，可能带 `?v=` 版本参数）原样返回，保留图片替换时的失效能力。
String stableImageCacheKey(String url) {
  if (!url.contains('X-Amz-')) return url;
  return url.split('?').first;
}

/// 统一的中等尺寸网络封面图。
///
/// 加载时显示占位灰块，加载完成淡入，失败回退占位块，避免出现「啪」地弹出
/// 或破图。尺寸由调用方固定（正方形用 [size]，非正方形用 [width]/[height]），
/// 避免图片到达后布局跳动。
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    required this.url,
    this.size,
    this.width,
    this.height,
    this.radius = 12,
    this.fit = BoxFit.cover,
    super.key,
  }) : assert(size != null || (width != null && height != null), '需提供 size，或同时提供 width 与 height');

  final String? url;
  final double? size;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final w = width ?? size!;
    final h = height ?? size!;
    final placeholder = Container(color: Theme.of(context).colorScheme.surfaceContainerHighest);
    final rounded = BorderRadius.circular(radius);

    if (url == null) {
      return ClipRRect(borderRadius: rounded, child: SizedBox(width: w, height: h, child: placeholder));
    }

    // 按「显示尺寸 × 像素密度」解码/落盘：64px 的格子不必解码整张原图，
    // 否则 ImageCache 会被大图挤爆、列表来回滚时反复重解码。
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = (w * dpr).round();
    final cacheH = (h * dpr).round();

    return ClipRRect(
      borderRadius: rounded,
      child: SizedBox(
        width: w,
        height: h,
        child: CachedNetworkImage(
          imageUrl: url!,
          cacheKey: stableImageCacheKey(url!),
          fit: fit,
          memCacheWidth: cacheW,
          memCacheHeight: cacheH,
          maxWidthDiskCache: cacheW,
          maxHeightDiskCache: cacheH,
          fadeInDuration: const Duration(milliseconds: 150),
          // 缩略图换原图等 URL 变化时先沿用旧图，避免闪回灰色占位。
          useOldImageOnUrlChange: true,
          placeholder: (_, _) => placeholder,
          errorWidget: (_, _, _) => placeholder,
        ),
      ),
    );
  }
}
