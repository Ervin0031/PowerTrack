/// 训练会话相关的 API 请求 DTO。
///
/// 仅包含「创建会话 / 完成会话」的请求体，与后端
/// `SessionCreate` / `SessionComplete` / `WorkoutSetCreate` Schema 对应。
/// 响应体在 `session_repository.dart` 内手动解析，避免再生成额外的数据类。
// ignore_for_file: invalid_annotation_target
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_models.freezed.dart';
part 'session_models.g.dart';

/// 创建会话请求体：`POST /api/v1/sessions`。
@Freezed()
abstract class SessionCreate with _$SessionCreate {
  const factory SessionCreate({required String clientUuid, required DateTime startedAt}) = _SessionCreate;

  factory SessionCreate.fromJson(Map<String, dynamic> json) => _$SessionCreateFromJson(json);
}

/// 单个训练组请求体（用于完成会话时批量上传）。
@Freezed()
abstract class WorkoutSetCreate with _$WorkoutSetCreate {
  const factory WorkoutSetCreate({
    required int exerciseId,
    required int setNumber,
    int? reps,
    double? weightKg,
    int? durationSeconds,
    double? distanceMeters,
    String? notes,
    DateTime? completedAt,
    required String clientUuid,
    double? rpe,
  }) = _WorkoutSetCreate;

  factory WorkoutSetCreate.fromJson(Map<String, dynamic> json) => _$WorkoutSetCreateFromJson(json);
}

/// 完成会话请求体：`PUT /api/v1/sessions/{id}/complete`。
@Freezed()
abstract class SessionComplete with _$SessionComplete {
  const factory SessionComplete({
    required String clientUuid,
    required DateTime startedAt,
    required DateTime completedAt,
    String? notes,
    @Default([]) List<WorkoutSetCreate> sets,
  }) = _SessionComplete;

  factory SessionComplete.fromJson(Map<String, dynamic> json) => _$SessionCompleteFromJson(json);
}
