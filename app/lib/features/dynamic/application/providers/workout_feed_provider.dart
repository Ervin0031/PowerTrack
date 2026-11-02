import 'package:app_flutter/features/dynamic/domain/entities/workout_feed_item.dart';
import 'package:app_flutter/features/dynamic/domain/workout_feed.dart';
import 'package:app_flutter/features/exercises/data/repositories/exercise_repository.dart';
import 'package:app_flutter/features/exercises/domain/entities/exercise.dart';
import 'package:app_flutter/features/profile/application/providers/fitness_profile_provider.dart';
import 'package:app_flutter/features/training/data/repositories/session_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 单次已完成训练详情（含与上次的对比）。动态页的关注流不走这里：
/// feed 卡片由分享快照渲染，只有「自己的训练」才能拉到逐组数据。
final workoutDetailProvider = FutureProvider.autoDispose.family<WorkoutFeedItem, int>((ref, sessionId) async {
  final raw = await ref.watch(sessionRepositoryProvider).getSessionDetail(sessionId);
  final session = WorkoutSessionDetail.fromJson(raw);
  final ids = session.sets.map((s) => s.exerciseId).toSet();
  final details = <int, ExerciseDetail>{};
  await Future.wait(
    ids.map((id) async {
      try {
        details[id] = await ref.read(exerciseRepositoryProvider).getExercise(id);
      } catch (_) {}
    }),
  );
  return _withComparisons(
    ref.read(sessionRepositoryProvider),
    buildWorkoutFeedItem(
      session: session,
      exercises: details,
      bodyWeightKg: ref.watch(fitnessProfileProvider).value?.weightKg,
    ),
  );
});

Future<WorkoutFeedItem> _withComparisons(SessionRepository repo, WorkoutFeedItem item) async {
  final compared = await Future.wait(
    item.exercises.map((exercise) async {
      try {
        final stats = await repo.getExerciseStats(exercise.exerciseId, days: 90);
        final history = [
          for (final session in stats.history)
            WorkoutPreviousSession(
              sessionId: session.sessionId,
              startedAt: session.startedAt,
              sets: [
                for (final set in session.sets)
                  WorkoutSetRecord(
                    id: 0,
                    exerciseId: exercise.exerciseId,
                    setNumber: set.setNumber,
                    reps: set.reps,
                    weightKg: set.weightKg,
                    rpe: set.rpe,
                    notes: set.notes,
                  ),
              ],
            ),
        ];
        return exercise.copyWith(
          vsLast: vsLastFromHistory(
            currentSessionId: item.sessionId,
            currentStartedAt: item.startedAt,
            history: history,
          ),
        );
      } catch (_) {
        return exercise;
      }
    }),
  );
  return item.copyWith(exercises: compared);
}
