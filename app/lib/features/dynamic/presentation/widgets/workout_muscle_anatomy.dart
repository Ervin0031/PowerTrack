import 'package:app_flutter/features/dynamic/domain/entities/workout_feed_item.dart';
import 'package:app_flutter/features/dynamic/presentation/widgets/workout_muscle_map.dart';
import 'package:app_flutter/features/profile/domain/entities/fitness_profile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_muscle_anatomy/flutter_muscle_anatomy.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_drawing/path_drawing.dart';

export 'package:app_flutter/features/dynamic/presentation/widgets/workout_muscle_map.dart'
    show musclesForHit, isChestHit;

/// 根据档案性别选男女模型；未透露时用男性模型。
bool isFemaleAnatomy(String? gender) => gender == FitnessGender.female;

List<Color> anatomyPalette(ColorScheme cs) => [
  cs.primary,
  cs.tertiary,
  cs.secondary,
  cs.error,
  cs.inversePrimary,
];

/// 正反面人体模型：主肌群实色、次肌群半透明，各肌群颜色不同。
class WorkoutMuscleAnatomy extends StatelessWidget {
  const WorkoutMuscleAnatomy({
    super.key,
    required this.female,
    required this.primary,
    required this.secondary,
    this.height = 300,
  });

  final bool female;
  final List<WorkoutMuscleHit> primary;
  final List<WorkoutMuscleHit> secondary;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = anatomyPalette(cs);
    // Anatomy 工厂 + customPainter 每次 build 重新构建；且 _AnatomyPainter 无 ==，
    // painter 一变整幅肌肉图重绘（动态流滚动 jank 主源）。参数相同则复用缓存。
    // ponytail: 线性扫描缓存，条目数 = 动态流里 (性别×配色×肌群组合) 的去重数，量级几十，无需 LRU。
    final cached = _AnatomyCache.get(
      female: female,
      palette: palette,
      primary: primary,
      secondary: secondary,
      height: height,
      colorScheme: cs,
    );
    final pec = _pecHighlight(palette);
    return SizedBox(
      height: height,
      width: cached.size.width,
      child: CustomPaint(
        size: cached.size,
        painter: cached.painter,
        foregroundPainter: pec == null
            ? null
            : _PecOverlayPainter(
                female: female,
                viewScale: cached.viewScale,
                color: pec.color,
                opacity: pec.opacity,
                strokeColor: cs.outlineVariant,
              ),
      ),
    );
  }

  ({Color color, double opacity})? _pecHighlight(List<Color> palette) {
    for (var i = 0; i < primary.length; i++) {
      if (isChestHit(primary[i])) {
        return (color: palette[i % palette.length], opacity: 0.88);
      }
    }
    for (var i = 0; i < secondary.length; i++) {
      if (isChestHit(secondary[i])) {
        return (color: palette[(i + 2) % palette.length], opacity: 0.38);
      }
    }
    return null;
  }
}

/// 按语义色涂肌群。未列入的肌肉保持底色，不使用动态流的多色调色板。
class MuscleTint {
  const MuscleTint({required this.name, this.nameEn = '', required this.color});

  final String name;
  final String nameEn;
  final Color color;
}

class MuscleStatusAnatomy extends StatelessWidget {
  const MuscleStatusAnatomy({
    super.key,
    required this.female,
    required this.tints,
    this.height = 140,
  });

  final bool female;
  final List<MuscleTint> tints;
  final double height;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cached = _StatusAnatomyCache.get(
      female: female,
      tints: tints,
      height: height,
      colorScheme: cs,
    );
    return SizedBox(
      height: height,
      width: cached.size.width,
      child: CustomPaint(
        size: cached.size,
        painter: cached.painter,
        foregroundPainter: cached.pecColor == null
            ? null
            : _PecOverlayPainter(
                female: female,
                viewScale: cached.viewScale,
                color: cached.pecColor!,
                opacity: 0.9,
                strokeColor: cs.outlineVariant,
              ),
      ),
    );
  }
}

class _StatusAnatomyCache {
  _StatusAnatomyCache._();

  static final _entries =
      <
        _StatusKey,
        ({
          CustomPainter painter,
          ViewScale viewScale,
          Size size,
          Color? pecColor,
        })
      >{};

  static ({
    CustomPainter painter,
    ViewScale viewScale,
    Size size,
    Color? pecColor,
  })
  get({
    required bool female,
    required List<MuscleTint> tints,
    required double height,
    required ColorScheme colorScheme,
  }) {
    final key = _StatusKey(
      female: female,
      tints: tints,
      height: height,
      colorScheme: colorScheme,
    );
    final hit = _entries[key];
    if (hit != null) return hit;

    final factory = Anatomy(
      female ? 'female' : 'male',
      hairColor: colorScheme.onSurface,
    );
    final anatomy = factory.both();
    anatomy.setDefaultFill(
      color: colorScheme.surfaceContainerHighest,
      opacity: 1,
    );
    anatomy.setDefaultStroke(color: colorScheme.outlineVariant, width: 0.6);

    Color? pecColor;
    for (final tint in tints) {
      final muscles = musclesForHit(
        WorkoutMuscleHit(
          name: tint.name,
          nameEn: tint.nameEn,
          isPrimary: true,
          setCount: 0,
          volume: 0,
        ),
      );
      if (muscles.isEmpty) continue;
      anatomy.highlightAll(muscles, color: tint.color, opacity: 0.9);
      if (muscles.contains(Muscle.pectoralisMajor)) pecColor = tint.color;
    }

    final size = Size(height * 1.15, height);
    final value = (
      painter: anatomy.customPainter(size, fill: true),
      viewScale: anatomy.getViewScale(size, filled: true),
      size: size,
      pecColor: pecColor,
    );
    _entries[key] = value;
    return value;
  }
}

class _StatusKey {
  _StatusKey({
    required this.female,
    required List<MuscleTint> tints,
    required this.height,
    required ColorScheme colorScheme,
  }) : names = [for (final tint in tints) '${tint.nameEn}|${tint.name}'],
       colors = [for (final tint in tints) tint.color.toARGB32()],
       fill = colorScheme.surfaceContainerHighest.toARGB32(),
       stroke = colorScheme.outlineVariant.toARGB32(),
       hair = colorScheme.onSurface.toARGB32();

  final bool female;
  final double height;
  final List<String> names;
  final List<int> colors;
  final int fill;
  final int stroke;
  final int hair;

  @override
  bool operator ==(Object other) =>
      other is _StatusKey &&
      female == other.female &&
      height == other.height &&
      fill == other.fill &&
      stroke == other.stroke &&
      hair == other.hair &&
      listEquals(names, other.names) &&
      listEquals(colors, other.colors);

  @override
  int get hashCode => Object.hash(
    female,
    height,
    fill,
    stroke,
    hair,
    Object.hashAll(names),
    Object.hashAll(colors),
  );
}

/// (性别, 配色, 肌群组合, 高度) 维度缓存构建好的 anatomy painter。
class _AnatomyCache {
  _AnatomyCache._();

  static final _entries =
      <_CacheKey, ({CustomPainter painter, ViewScale viewScale, Size size})>{};

  static ({CustomPainter painter, ViewScale viewScale, Size size}) get({
    required bool female,
    required List<Color> palette,
    required List<WorkoutMuscleHit> primary,
    required List<WorkoutMuscleHit> secondary,
    required double height,
    required ColorScheme colorScheme,
  }) {
    final key = _CacheKey(
      female: female,
      palette: palette,
      primary: primary,
      secondary: secondary,
      height: height,
    );
    final hit = _entries[key];
    if (hit != null) return hit;

    final factory = Anatomy(
      female ? 'female' : 'male',
      hairColor: colorScheme.onSurface,
    );
    // 始终正反面并排，避免 byMuscles 只留一侧、卧推胸大肌被裁掉。
    final anatomy = factory.both();
    anatomy.setDefaultFill(
      color: colorScheme.surfaceContainerHighest,
      opacity: 1,
    );
    anatomy.setDefaultStroke(color: colorScheme.outlineVariant, width: 0.6);

    for (var i = 0; i < primary.length; i++) {
      anatomy.highlightAll(
        musclesForHit(primary[i]),
        color: palette[i % palette.length],
        opacity: 0.88,
      );
    }
    for (var i = 0; i < secondary.length; i++) {
      anatomy.highlightAll(
        musclesForHit(secondary[i]),
        color: palette[(i + 2) % palette.length],
        opacity: 0.38,
      );
    }

    final size = Size(height * 1.15, height);
    final value = (
      painter: anatomy.customPainter(size, fill: true),
      viewScale: anatomy.getViewScale(size, filled: true),
      size: size,
    );
    _entries[key] = value;
    return value;
  }
}

class _CacheKey {
  const _CacheKey({
    required this.female,
    required this.palette,
    required this.primary,
    required this.secondary,
    required this.height,
  });

  final bool female;
  final List<Color> palette;
  final List<WorkoutMuscleHit> primary;
  final List<WorkoutMuscleHit> secondary;
  final double height;

  @override
  bool operator ==(Object other) =>
      other is _CacheKey &&
      female == other.female &&
      height == other.height &&
      listEquals(palette, other.palette) &&
      listEquals(primary, other.primary) &&
      listEquals(secondary, other.secondary);

  @override
  int get hashCode => Object.hash(
    female,
    height,
    Object.hashAll(palette),
    Object.hashAll(primary),
    Object.hashAll(secondary),
  );
}

/// `flutter_muscle_anatomy` 1.2.8 把胸大肌 SVG id 写成了 `pectolaris_major`，
/// 枚举 `pectoralisMajor` 对不上，highlight 是空操作。正面路径叠一层补上。
class _PecOverlayPainter extends CustomPainter {
  _PecOverlayPainter({
    required this.female,
    required this.viewScale,
    required this.color,
    required this.opacity,
    required this.strokeColor,
  });

  final bool female;
  final ViewScale viewScale;
  final Color color;
  final double opacity;
  final Color strokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    final matrix = viewScale.painterTransform;
    for (final path in female ? _femalePecParsed : _malePecParsed) {
      final transformed = path.transform(matrix.storage);
      canvas.drawPath(transformed, stroke);
      canvas.drawPath(transformed, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _PecOverlayPainter oldDelegate) {
    return female != oldDelegate.female ||
        color != oldDelegate.color ||
        opacity != oldDelegate.opacity ||
        strokeColor != oldDelegate.strokeColor;
  }
}

/// 胸大肌路径只解析一次（原实现在 paint() 里每帧 parseSvgPathData）。
final _malePecParsed = [for (final d in _malePecPaths) parseSvgPathData(d)];
final _femalePecParsed = [for (final d in _femalePecPaths) parseSvgPathData(d)];

const _malePecPaths = [
  'm 16.09197,11.663384 c 1.413776,-0.24773 2.919972,0.01865 4.183906,0.692386 0.576255,0.55707 0.772191,1.470958 0.60335,2.215622 -0.662213,0.933353 -0.6936,2.352746 -1.895489,2.830076 -0.811629,0.481477 -1.715904,0.25513 -2.594515,0.179074 -0.738624,-0.05005 -1.18052,-0.680766 -1.129179,-1.393572 -0.04345,-1.064468 -0.007,-2.125466 0.182798,-3.169661 0.151624,-0.478329 0.237157,-1.015741 0.649129,-1.353925 z',
  'm 13.896151,11.663384 c -1.413777,-0.24773 -2.919984,0.01874 -4.1839081,0.692386 -0.576247,0.55707 -0.7721896,1.470958 -0.6033543,2.215622 0.6622147,0.933353 0.6936044,2.352746 1.8954954,2.830076 0.81163,0.481477 1.715901,0.25513 2.594509,0.179073 0.738629,-0.05001 1.180518,-0.680766 1.129185,-1.393571 0.04345,-1.064468 0.0075,-2.125467 -0.182801,-3.169662 -0.151629,-0.478328 -0.237158,-1.01574 -0.649126,-1.353924 z',
];

const _femalePecPaths = [
  'm 15.485079,15.359308 c 1.038055,-0.270195 2.284865,-0.263201 3.064095,0.546698 0.845291,0.782614 1.269111,1.940901 1.359079,3.039652 -1.234745,0.53844 -2.474278,1.357318 -3.889141,1.228968 -0.588471,-0.307046 -0.87485,-0.903975 -0.711777,-1.532515 0.05449,-1.094486 0.119193,-2.188507 0.177744,-3.282803 z',
  'm 14.880698,15.359308 c -1.038049,-0.270195 -2.284852,-0.263201 -3.064079,0.546698 -0.845291,0.782614 -1.269111,1.940901 -1.35908,3.039652 1.234746,0.53844 2.474273,1.357318 3.88913,1.228968 0.588466,-0.307046 0.874843,-0.903975 0.711772,-1.532515 -0.05449,-1.094486 -0.11919,-2.188507 -0.177743,-3.282803 z',
];

/// 单肌群灰色特写，铺在恢复卡片右侧。胸大肌走补画路径。
class MuscleGroupCloseup extends StatelessWidget {
  const MuscleGroupCloseup({
    super.key,
    required this.female,
    required this.name,
    this.nameEn = '',
  });

  final bool female;
  final String name;
  final String nameEn;

  @override
  Widget build(BuildContext context) {
    final art = _closeupArt(female: female, name: name, nameEn: nameEn);
    if (art == null) return const SizedBox.shrink();
    return CustomPaint(
      painter: _MuscleCloseupPainter(
        art: art,
        ink: Theme.of(context).colorScheme.onSurface,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _CloseupArt {
  const _CloseupArt({
    required this.outlines,
    required this.muscles,
    required this.focus,
  });

  final List<Path> outlines;
  final List<Path> muscles;
  final Rect focus;
}

final _closeupCache = <String, _CloseupArt?>{};

_CloseupArt? _closeupArt({
  required bool female,
  required String name,
  required String nameEn,
}) {
  final key = '$female|$nameEn|$name';
  if (_closeupCache.containsKey(key)) return _closeupCache[key];
  final muscles = musclesForHit(
    WorkoutMuscleHit(
      name: name,
      nameEn: nameEn,
      isPrimary: true,
      setCount: 0,
      volume: 0,
    ),
  );
  if (muscles.isEmpty) {
    _closeupCache[key] = null;
    return null;
  }

  var front = 0;
  var back = 0;
  for (final muscle in muscles) {
    if (muscle.isFront || muscle == Muscle.pectoralisMajor) front++;
    if (muscle.isBack) back++;
  }
  final view = back > front ? BodyView.back : BodyView.front;
  final anatomy = Anatomy(female ? 'female' : 'male').byView(view);
  final paths = <Path>[];
  for (final muscle in muscles) {
    if (!muscle.isForView(view)) continue;
    if (muscle == Muscle.pectoralisMajor) {
      paths.addAll(female ? _femalePecParsed : _malePecParsed);
      continue;
    }
    paths.addAll(anatomy.getMusclePaths(muscle, position: MuscleSide.both));
  }
  if (paths.isEmpty) {
    _closeupCache[key] = null;
    return null;
  }

  var focus = paths.first.getBounds();
  for (final path in paths.skip(1)) {
    focus = focus.expandToInclude(path.getBounds());
  }
  if (focus.width < 0.4 || focus.height < 0.4) {
    _closeupCache[key] = null;
    return null;
  }
  final art = _CloseupArt(
    outlines: anatomy.outlinePaths,
    muscles: paths,
    focus: focus,
  );
  _closeupCache[key] = art;
  return art;
}

class _MuscleCloseupPainter extends CustomPainter {
  _MuscleCloseupPainter({required this.art, required this.ink});

  final _CloseupArt art;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final pad = art.focus.inflate(art.focus.longestSide * 0.42);
    final scale = size.height / pad.height;
    if (scale <= 0 || !scale.isFinite) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width * 0.58, size.height * 0.5);
    canvas.scale(scale);
    canvas.translate(-pad.center.dx, -pad.center.dy);

    final body = Paint()
      ..color = ink.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;
    final muscle = Paint()
      ..color = ink.withValues(alpha: 0.16)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = ink.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 / scale;
    for (final path in art.outlines) {
      canvas.drawPath(path, body);
    }
    for (final path in art.muscles) {
      canvas.drawPath(path, muscle);
      canvas.drawPath(path, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MuscleCloseupPainter oldDelegate) {
    return oldDelegate.art != art || oldDelegate.ink != ink;
  }
}
