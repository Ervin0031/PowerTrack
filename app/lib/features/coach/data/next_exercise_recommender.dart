import 'package:app_flutter/features/coach/data/coach_rest.dart';
import 'package:app_flutter/features/coach/domain/coach_proposal.dart';
import 'package:app_flutter/features/coach/domain/next_exercise.dart';
import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:dio/dio.dart';

/// 用本场动作、最近训练和同肌群动作库选下一个动作，不交给模型随便搜。
class NextExerciseRecommender {
  NextExerciseRecommender(this._dio) : _rest = CoachRest(_dio);

  final Dio _dio;
  final CoachRest _rest;

  Future<CoachSuggestion?> recommend({
    required List<TrainingExercise> session,
    int? focusedExerciseId,
    Set<int> excludeIds = const {},
  }) async {
    final details = <int, NextLift>{};
    Future<NextLift?> load(int id) async {
      final cached = details[id];
      if (cached != null) return cached;
      final lift = await _detail(id);
      if (lift != null) details[id] = lift;
      return lift;
    }

    final sessionLifts = <NextLift>[];
    for (final exercise in session) {
      final loaded = await load(exercise.exerciseId);
      sessionLifts.add(
        loaded ??
            NextLift(
              exerciseId: exercise.exerciseId,
              name: exercise.name,
              exerciseType: exercise.exerciseType,
              imageUrl: exercise.imageUrl,
            ),
      );
    }

    final recentRaw = await _rest.getRecentSessions(5);
    final recent = <List<NextLift>>[];
    final items = recentRaw['items'];
    if (items is List) {
      final sorted = [for (final item in items) if (item is Map) Map<String, dynamic>.from(item)];
      sorted.sort((a, b) {
        final left = a['started_at']?.toString() ?? '';
        final right = b['started_at']?.toString() ?? '';
        return right.compareTo(left);
      });
      for (final sessionItem in sorted) {
        final exercises = sessionItem['exercises'];
        if (exercises is! List) continue;
        final lifts = <NextLift>[];
        for (final raw in exercises) {
          if (raw is! Map) continue;
          final id = (raw['exercise_id'] as num?)?.toInt();
          if (id == null) continue;
          final loaded = await load(id);
          lifts.add(
            loaded ??
                NextLift(
                  exerciseId: id,
                  name: raw['name'] as String? ?? '动作',
                ),
          );
        }
        if (lifts.isNotEmpty) recent.add(lifts);
      }
    }

    final muscles = {
      for (final lift in sessionLifts)
        if (lift.muscleGroupId != null) lift.muscleGroupId!,
    };
    final catalog = <NextLift>[];
    final seen = <int>{};
    for (final muscleId in muscles) {
      final page = await _dio.get<dynamic>(
        '/api/v1/exercises',
        queryParameters: {'muscle_group_id': muscleId, 'limit': 20},
      );
      final data = page.data;
      final pageItems = data is Map ? data['items'] : null;
      if (pageItems is! List) continue;
      for (final raw in pageItems) {
        if (raw is! Map) continue;
        final id = (raw['id'] as num?)?.toInt();
        if (id == null || !seen.add(id)) continue;
        catalog.add(
          NextLift(
            exerciseId: id,
            name: raw['name'] as String? ?? '动作',
            muscleGroupId: (raw['primary_muscle_group_id'] as num?)?.toInt() ?? muscleId,
            muscleName: details[id]?.muscleName,
            exerciseType: raw['exercise_type'] as String? ?? 'compound',
            imageUrl: (raw['thumb_url'] ?? raw['image_url']) as String?,
          ),
        );
      }
    }

    final choice = pickNextExercise(
      session: sessionLifts,
      focusedExerciseId: focusedExerciseId,
      recentSessions: recent,
      catalog: catalog,
      excludeIds: excludeIds,
    );
    if (choice == null) return null;
    final lift = choice.lift;
    return CoachSuggestion(
      reason: choice.reason,
      exercise: CoachExercise(
        exerciseId: lift.exerciseId,
        name: lift.name,
        exerciseType: lift.exerciseType,
        imageUrl: lift.imageUrl,
        sets: await _plannedSets(lift.exerciseId),
      ),
    );
  }

  Future<NextLift?> _detail(int id) async {
    try {
      final response = await _dio.get<dynamic>('/api/v1/exercises/$id');
      final data = response.data;
      if (data is! Map) return null;
      return NextLift(
        exerciseId: id,
        name: data['name'] as String? ?? '动作',
        muscleGroupId: (data['primary_muscle_group_id'] as num?)?.toInt(),
        muscleName: data['primary_muscle_name'] as String?,
        exerciseType: data['exercise_type'] as String? ?? 'compound',
        imageUrl: (data['thumb_url'] ?? data['image_url']) as String?,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<CoachSet>> _plannedSets(int id) async {
    final response = await _dio.get<dynamic>(
      '/api/v1/exercises/$id/last-session-sets',
      options: Options(validateStatus: (code) => code == 200 || code == 404),
    );
    final data = response.data;
    final rawSets = response.statusCode == 404 || data is! Map ? null : data['sets'];
    final parsed = <CoachSet>[];
    if (rawSets is List) {
      var number = 1;
      for (final item in rawSets.take(4)) {
        if (item is! Map) continue;
        final kind = item['set_kind'] as String?;
        parsed.add(
          CoachSet(
            setNumber: number,
            setKind: kind == 'warmup' || kind == 'drop' || kind == 'cooldown' ? kind! : 'working',
            reps: (item['reps'] as num?)?.toInt(),
            weightKg: (item['weight_kg'] as num?)?.toDouble(),
          ),
        );
        number++;
      }
    }
    if (parsed.isNotEmpty) return parsed;
    return [
      for (var number = 1; number <= 3; number++) CoachSet(setNumber: number, setKind: 'working', reps: 8),
    ];
  }
}
