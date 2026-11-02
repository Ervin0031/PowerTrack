import 'package:app_flutter/features/training/domain/entities/training_session.dart';

/// 训练组类型（本地标记；上传后端时暂不携带）。
enum TrainingSetKind {
  /// 热身组。
  warmup,

  /// 主要组（默认）。
  working,

  /// 放松组。
  cooldown,

  /// 递减组。
  drop;

  /// 菜单与提示用完整名称。
  String get label => switch (this) {
        TrainingSetKind.warmup => '热身组',
        TrainingSetKind.working => '主要组',
        TrainingSetKind.cooldown => '放松组',
        TrainingSetKind.drop => '递减组',
      };
}

/// 按 Motra 规则为各组生成组数格文案（与列表顺序一一对应）。
///
/// - 热身组 → `热身`
/// - 主要组 → 主要组序号 `1`/`2`/…
/// - 放松组 → `放松`
/// - 递减组 → 接在最近主要组序号后加字母：`1A`/`1B`/`1C`（尚无主要组时从 `1A` 起）
List<String> trainingSetDisplayLabels(List<TrainingSet> sets) {
  var workingCount = 0;
  var dropBase = 0;
  var dropIndex = 0;
  TrainingSetKind? previous;
  final labels = <String>[];

  for (final set in sets) {
    switch (set.setKind) {
      case TrainingSetKind.warmup:
        labels.add('热身');
      case TrainingSetKind.cooldown:
        labels.add('放松');
      case TrainingSetKind.working:
        workingCount++;
        dropBase = workingCount;
        dropIndex = 0;
        labels.add('$workingCount');
      case TrainingSetKind.drop:
        if (previous != TrainingSetKind.drop) {
          dropBase = workingCount > 0 ? workingCount : 1;
          dropIndex = 0;
        }
        final letter = String.fromCharCode(0x41 + dropIndex); // A, B, C…
        labels.add('$dropBase$letter');
        dropIndex++;
    }
    previous = set.setKind;
  }
  return labels;
}
