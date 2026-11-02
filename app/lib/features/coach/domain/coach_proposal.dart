import 'package:app_flutter/features/coach/domain/coach_thought.dart';

/// 今日课表提案。纯数据，确认后才写入训练会话。
class CoachProposal {
  const CoachProposal({
    required this.title,
    required this.summary,
    required this.estimatedMinutes,
    required this.exercises,
  });

  final String title;
  final String summary;
  final int estimatedMinutes;
  final List<CoachExercise> exercises;

  Map<String, dynamic> toJson() => {
        'title': title,
        'summary': summary,
        'estimated_minutes': estimatedMinutes,
        'exercises': [for (final exercise in exercises) exercise.toJson()],
      };

  factory CoachProposal.fromJson(Map<String, dynamic> json) {
    final raw = json['exercises'];
    return CoachProposal(
      title: json['title'] as String? ?? '今天的训练',
      summary: json['summary'] as String? ?? '',
      estimatedMinutes: (json['estimated_minutes'] as num?)?.toInt() ?? 45,
      exercises: raw is List
          ? [
              for (final item in raw)
                if (item is Map<String, dynamic>) CoachExercise.fromJson(item),
            ]
          : const [],
    );
  }
}

class CoachExercise {
  const CoachExercise({
    required this.exerciseId,
    required this.name,
    required this.exerciseType,
    required this.sets,
    this.notes,
    this.restTargetSeconds,
    this.imageUrl,
  });

  final int exerciseId;
  final String name;
  final String exerciseType;
  final String? notes;
  final int? restTargetSeconds;
  final String? imageUrl;
  final List<CoachSet> sets;

  Map<String, dynamic> toJson() => {
        'exercise_id': exerciseId,
        'name': name,
        'exercise_type': exerciseType,
        if (notes != null) 'notes': notes,
        if (restTargetSeconds != null)
          'rest_target_seconds': restTargetSeconds,
        'image_url': ?imageUrl,
        'sets': [for (final set in sets) set.toJson()],
      };

  factory CoachExercise.fromJson(Map<String, dynamic> json) {
    final raw = json['sets'];
    return CoachExercise(
      exerciseId: (json['exercise_id'] as num).toInt(),
      name: json['name'] as String? ?? '动作',
      exerciseType: json['exercise_type'] as String? ?? 'compound',
      notes: json['notes'] as String?,
      restTargetSeconds: (json['rest_target_seconds'] as num?)?.toInt(),
      imageUrl: json['image_url'] as String?,
      sets: raw is List
          ? [
              for (final item in raw)
                if (item is Map<String, dynamic>) CoachSet.fromJson(item),
            ]
          : const [],
    );
  }
}

class CoachSet {
  const CoachSet({
    required this.setNumber,
    required this.setKind,
    this.reps,
    this.weightKg,
  });

  final int setNumber;
  final String setKind;
  final int? reps;
  final double? weightKg;

  Map<String, dynamic> toJson() => {
        'set_number': setNumber,
        'set_kind': setKind,
        if (reps != null) 'reps': reps,
        if (weightKg != null) 'weight_kg': weightKg,
      };

  factory CoachSet.fromJson(Map<String, dynamic> json) {
    return CoachSet(
      setNumber: (json['set_number'] as num?)?.toInt() ?? 1,
      setKind: json['set_kind'] as String? ?? 'working',
      reps: (json['reps'] as num?)?.toInt(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
    );
  }
}

/// 一轮教练回复里 UI 需要的部分。
class CoachSuggestion {
  const CoachSuggestion({required this.reason, required this.exercise});

  final String reason;
  final CoachExercise exercise;

  factory CoachSuggestion.fromJson(Map<String, dynamic> json) {
    final raw = json['exercise'];
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('suggestion exercise');
    }
    return CoachSuggestion(
      reason: json['reason'] as String? ?? '',
      exercise: CoachExercise.fromJson(raw),
    );
  }
}

class CoachTurn {
  const CoachTurn({
    this.messages = const [],
    this.thoughts = const [],
    this.status,
    this.proposal,
    this.suggestion,
    this.error,
  });

  final List<String> messages;
  final List<CoachThoughtStep> thoughts;
  final String? status;
  final CoachProposal? proposal;
  final CoachSuggestion? suggestion;
  final String? error;
}
