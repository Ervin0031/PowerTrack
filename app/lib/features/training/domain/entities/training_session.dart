/// 训练会话相关实体（本地会话工作模型）。
///
/// 纯 Dart，零 Flutter / Riverpod 依赖。字段对应后端
/// `SessionResponse` / `WorkoutSetResponse` / `SessionCreate` 等 Schema，
/// 但本文件面向「进行中会话」的本地编辑态，与后端的请求/响应 DTO 分离
/// （请求 DTO 见 `data/models/session_models.dart`）。
// ignore_for_file: invalid_annotation_target
library;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../rpe.dart';
import 'training_set_kind.dart';

part 'training_session.freezed.dart';
part 'training_session.g.dart';

/// 单个训练组（本地可编辑态）。
///
/// `completedAt` 同时承担「完成打勾」语义：非 null 表示该组已完成，
/// 直接复用后端 `WorkoutSetCreate.completed_at`，勾选即写入完成时间、取消即清空，
/// 无需额外布尔字段与后端对齐。
///
/// `restSeconds` 表示**本组动作用时**（完成时 `completedAt - startedAt`），
/// 仅本地展示；后端 `WorkoutSetCreate` 无此字段，上传时忽略。
/// 组间休息另由底部 [RestTimerBar] 按最近一次完成时间计时，与本字段无关。
///
/// `setKind` 为组类型标记（热身/主要/放松/递减），仅本地与缓存使用。
///
/// `startedAt` 为本组开始练的时间：仅在该组成为当前未完成组时写入；
/// 点「完成」时用其计算本组用时，**不得**回退到会话开始时间（否则会累计前面的组）。
@Freezed()
abstract class TrainingSet with _$TrainingSet {
  const factory TrainingSet({
    required int setNumber,
    int? reps,
    double? weightKg,
    int? restSeconds,
    int? durationSeconds,
    double? distanceMeters,
    String? notes,
    DateTime? completedAt,
    DateTime? startedAt,
    @Default(TrainingSetKind.working) TrainingSetKind setKind,
    required String clientUuid,
    double? rpe,
    double? suggestedWeightKg,
  }) = _TrainingSet;

  factory TrainingSet.fromJson(Map<String, dynamic> json) => _$TrainingSetFromJson(json);
}

/// 训练中的一个动作及其所有组。
@Freezed()
abstract class TrainingExercise with _$TrainingExercise {
  const factory TrainingExercise({
    required int exerciseId,
    required String name,
    String? imageUrl,
    @Default('compound') String exerciseType,

    /// 超级组标记：同一 `supersetId` 的动作视为一组超级组；null 表示普通动作。
    int? supersetId,

    /// 徒手/自重动作：未填重量时预填并展示用户体重。
    @Default(false) bool isBodyweight,
    @Default([]) List<TrainingSet> sets,

    /// 上次训练对应组（幽灵行对照；次数/重量已预填到本组）。
    @Default([]) List<GhostSet> ghostSets,
    DateTime? ghostSessionDate,
    String? notes,
    int? restTargetSeconds,
    @Default('kg') String weightUnit,
  }) = _TrainingExercise;

  factory TrainingExercise.fromJson(Map<String, dynamic> json) => _$TrainingExerciseFromJson(json);
}

/// 进行中的训练会话（全局共享状态）。
///
/// 由 [trainingSessionProvider] 持有；`null` 表示当前无进行中会话。
///
/// [focusedExerciseId]：当前展开/正在练的动作；同一时间最多一个，null 表示全部收起。
@Freezed()
abstract class ActiveTraining with _$ActiveTraining {
  const factory ActiveTraining({
    required int sessionId,
    required String clientUuid,
    required DateTime startedAt,
    @Default('in_progress') String status,
    @Default([]) List<TrainingExercise> exercises,

    /// 当前展开的动作 id（表示正在练的那一个）；null = 全部收起。
    int? focusedExerciseId,

    /// 当前组间休息额外秒数（RPE 红区 / 力竭时 +60）。下一组完成时覆盖。
    @Default(0) int restBonusSeconds,
  }) = _ActiveTraining;

  factory ActiveTraining.fromJson(Map<String, dynamic> json) => _$ActiveTrainingFromJson(json);
}
