/// 动态页训练卡片的纯 Dart 聚合与文案。
library;

import 'package:app_flutter/features/dynamic/domain/entities/feed_post.dart';
import 'package:app_flutter/features/dynamic/domain/entities/workout_feed_item.dart';
import 'package:app_flutter/features/exercises/domain/entities/exercise.dart';
import 'package:app_flutter/features/training/domain/rpe.dart';
import 'package:app_flutter/features/training/domain/strength.dart';

const kResistanceMet = 6.0;

const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

String formatFeedTimestamp(DateTime startedAt) {
  final local = startedAt.toLocal();
  final hour = local.hour;
  final period = hour < 12 ? '上午' : '下午';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}年${local.month}月${local.day}日 $period $hour12:$minute';
}

double estimateSessionKcal({required Duration duration, required double weightKg}) {
  if (weightKg <= 0 || duration.inSeconds <= 0) return 0;
  return kResistanceMet * weightKg * duration.inSeconds / 3600;
}

String dayPeriod(DateTime local) {
  final hour = local.hour;
  if (hour < 6) return '凌晨';
  if (hour < 12) return '上午';
  if (hour < 14) return '中午';
  if (hour < 18) return '下午';
  return '晚间';
}

/// 无备注时按时间 + 主肌群生成标题，如「周三晚间背阔肌与斜方肌专项训练」。
String generateWorkoutTitle({
  required DateTime startedAt,
  String? notes,
  List<String> primaryMuscleNames = const [],
}) {
  final trimmed = notes?.trim();
  if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  final local = startedAt.toLocal();
  final weekday = _weekdays[local.weekday - 1];
  final period = dayPeriod(local);
  final names = primaryMuscleNames.where((n) => n.trim().isNotEmpty).toList();
  if (names.isEmpty) return '$weekday$period力量训练';
  if (names.length == 1) return '$weekday$period${names.first}专项训练';
  if (names.length == 2) return '$weekday$period${names[0]}与${names[1]}专项训练';
  return '$weekday$period${names[0]}、${names[1]}与${names[2]}专项训练';
}

List<int> restIntervalsSeconds(List<WorkoutSetRecord> sets) {
  final times = sets.map((s) => s.completedAt).whereType<DateTime>().toList()..sort();
  if (times.length < 2) return const [];
  final gaps = <int>[];
  for (var i = 1; i < times.length; i++) {
    final gap = times[i].difference(times[i - 1]).inSeconds;
    if (gap >= 20 && gap <= 20 * 60) gaps.add(gap);
  }
  return gaps;
}

int hardSetCount(Iterable<WorkoutSetRecord> sets) => sets.where((s) => isHardSet(s.rpe)).length;

double? averageRpe(Iterable<WorkoutSetRecord> sets) {
  final values = sets.map((s) => s.rpe).whereType<double>().toList();
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a + b) / values.length;
}

String formatLoggedSet(WorkoutSetRecord set) {
  final parts = <String>[];
  if (set.weightKg != null && set.weightKg! > 0) {
    parts.add('${formatWeight(set.weightKg!)} kg');
  }
  if (set.reps != null && set.reps! > 0) {
    parts.add('${set.reps} 次');
  }
  var body = parts.join(' × ');
  if (set.durationSeconds != null && set.durationSeconds! > 0) {
    final s = set.durationSeconds!;
    final dur = s >= 60 ? '${s ~/ 60}分${s % 60}秒' : '$s秒';
    body = body.isEmpty ? dur : '$body · $dur';
  }
  if (set.distanceMeters != null && set.distanceMeters! > 0) {
    final meters = set.distanceMeters!;
    final dist = meters >= 1000 ? '${(meters / 1000).toStringAsFixed(2)} km' : '${meters.round()} m';
    body = body.isEmpty ? dist : '$body · $dist';
  }
  if (set.rpe != null) {
    final tag = 'RPE ${formatRpe(set.rpe!)}';
    body = body.isEmpty ? tag : '$body · $tag';
  }
  return body.isEmpty ? '—' : body;
}

WorkoutVsLast? vsLastFromHistory({
  required int currentSessionId,
  required DateTime currentStartedAt,
  required List<WorkoutPreviousSession> history,
}) {
  final candidates = history.where((h) {
    if (h.sessionId == currentSessionId) return false;
    return h.startedAt.isBefore(currentStartedAt);
  }).toList();
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) => b.startedAt.compareTo(a.startedAt));
  final last = candidates.first;
  final volume = last.sets.fold<double>(0, (sum, s) => sum + s.volume);
  final weighted = last.sets.where((s) => s.weightKg != null && s.weightKg! > 0);
  WorkoutSetRecord? top;
  for (final set in weighted) {
    if (top == null || set.weightKg! > top.weightKg!) top = set;
  }
  return WorkoutVsLast(
    previousVolume: volume,
    previousMaxWeightKg: top?.weightKg,
    previousRepsAtMax: top?.reps,
    previousAt: last.startedAt,
  );
}

String formatVsLast({required double currentVolume, required WorkoutVsLast last}) {
  final delta = currentVolume - last.previousVolume;
  if (delta.abs() < 1) return '容量与上次持平';
  if (delta > 0) return '容量比上次 +${delta.round()} kg';
  return '容量比上次 ${delta.round()} kg';
}

String? formatPreviousTopSet(WorkoutVsLast last) {
  final weight = last.previousMaxWeightKg;
  if (weight == null) return null;
  final reps = last.previousRepsAtMax;
  if (reps == null) return '上次最重 ${formatWeight(weight)} kg';
  return '上次 ${formatWeight(weight)} kg × $reps 次';
}

String formatIntensityLine({required int hardSets, required double? averageRpe}) {
  final parts = <String>[];
  if (hardSets > 0) parts.add('$hardSets 个有效组');
  if (averageRpe != null) parts.add('平均 RPE ${formatRpe(averageRpe)}');
  return parts.join(' · ');
}

WorkoutFeedItem buildWorkoutFeedItem({
  required WorkoutSessionDetail session,
  required Map<int, ExerciseDetail> exercises,
  double? bodyWeightKg,
}) {
  final byExercise = <int, List<WorkoutSetRecord>>{};
  for (final set in session.sets) {
    byExercise.putIfAbsent(set.exerciseId, () => []).add(set);
  }

  final summaries = <WorkoutExerciseSummary>[];
  final primary = <String, WorkoutMuscleHit>{};
  final secondary = <String, WorkoutMuscleHit>{};

  byExercise.forEach((exerciseId, sets) {
    final detail = exercises[exerciseId];
    final ordered = [...sets]..sort((a, b) => a.setNumber.compareTo(b.setNumber));
    final volume = ordered.fold<double>(0, (sum, s) => sum + s.volume);
    final weights = ordered.map((s) => s.weightKg).whereType<double>().where((w) => w > 0);
    summaries.add(
      WorkoutExerciseSummary(
        exerciseId: exerciseId,
        name: detail?.name ?? '动作 $exerciseId',
        nameEn: detail?.nameEn,
        imageUrl: detail?.imageUrl,
        setCount: ordered.length,
        maxWeightKg: weights.isEmpty ? null : weights.reduce((a, b) => a > b ? a : b),
        volume: volume,
        primaryMuscleName: detail?.primaryMuscleName,
        sets: ordered,
      ),
    );

    final pName = detail?.primaryMuscleName;
    final pEn = detail?.primaryMuscleNameEn ?? '';
    if (pName != null && pName.isNotEmpty) {
      final prev = primary[pName];
      primary[pName] = WorkoutMuscleHit(
        name: pName,
        nameEn: pEn,
        isPrimary: true,
        setCount: (prev?.setCount ?? 0) + sets.length,
        volume: (prev?.volume ?? 0) + volume,
      );
    }
    for (final muscle in detail?.secondaryMuscles ?? const <MuscleGroup>[]) {
      if (primary.containsKey(muscle.name)) continue;
      final prev = secondary[muscle.name];
      secondary[muscle.name] = WorkoutMuscleHit(
        name: muscle.name,
        nameEn: muscle.nameEn,
        isPrimary: false,
        setCount: (prev?.setCount ?? 0) + sets.length,
        volume: (prev?.volume ?? 0) + volume * 0.5,
      );
    }
  });

  final primaryList = primary.values.toList()..sort((a, b) => b.volume.compareTo(a.volume));
  final secondaryList = secondary.values.toList()..sort((a, b) => b.volume.compareTo(a.volume));

  final duration = session.duration;
  final kcal = duration == null || bodyWeightKg == null
      ? null
      : estimateSessionKcal(duration: duration, weightKg: bodyWeightKg);

  return WorkoutFeedItem(
    sessionId: session.id,
    startedAt: session.startedAt,
    completedAt: session.completedAt,
    notes: session.notes,
    duration: duration,
    volumeKg: summaries.fold<double>(0, (sum, e) => sum + e.volume),
    estimatedKcal: kcal,
    title: generateWorkoutTitle(
      startedAt: session.startedAt,
      notes: session.notes,
      primaryMuscleNames: primaryList.map((m) => m.name).take(3).toList(),
    ),
    exercises: summaries,
    primaryMuscles: primaryList,
    secondaryMuscles: secondaryList,
    restSeconds: restIntervalsSeconds(session.sets),
    hardSetCount: hardSetCount(session.sets),
    averageRpe: averageRpe(session.sets),
  );
}

/// 关注流动态 → 卡片模型。只拿得到分享时刻的快照，拿不到逐组数据。
///
/// 无快照（老数据或结构不认识）时返回 null，由卡片降级为纯文字动态。
/// [bodyWeightKg] 只在看自己的动态时用于估算热量——别人的体重算不出也不该猜。
WorkoutFeedItem? feedItemFromPost(FeedPost post, {required int myUserId, double? bodyWeightKg}) {
  final snapshot = post.snapshot;
  if (snapshot == null) return null;

  final startedAt = snapshot.startedAt ?? post.createdAt;
  final primary = [
    for (final muscle in snapshot.muscles)
      WorkoutMuscleHit(
        name: muscle.name,
        // 快照只存中文名，解剖图靠中文分支匹配。
        nameEn: '',
        isPrimary: true,
        setCount: muscle.hardSets,
        volume: muscle.volume,
      ),
  ];
  final caption = post.caption?.trim() ?? '';
  final duration = snapshot.duration;
  final kcal = post.userId == myUserId && bodyWeightKg != null && duration != null
      ? estimateSessionKcal(duration: duration, weightKg: bodyWeightKg)
      : null;

  return WorkoutFeedItem(
    sessionId: post.sessionId ?? 0,
    startedAt: startedAt,
    completedAt: snapshot.completedAt,
    notes: snapshot.notes,
    duration: duration,
    volumeKg: snapshot.totalVolumeKg,
    estimatedKcal: kcal,
    title: caption.isNotEmpty
        ? caption
        : generateWorkoutTitle(
            startedAt: startedAt,
            notes: snapshot.notes,
            primaryMuscleNames: snapshot.muscles.map((m) => m.name).take(3).toList(),
          ),
    exercises: [
      for (final pr in snapshot.prs)
        WorkoutExerciseSummary(
          exerciseId: pr.exerciseId,
          name: pr.exerciseName,
          setCount: 1,
          maxWeightKg: pr.weightKg,
          volume: (pr.weightKg ?? 0) * (pr.reps ?? 0),
        ),
    ],
    primaryMuscles: primary,
    hardSetCount: snapshot.hardSets,
  );
}
