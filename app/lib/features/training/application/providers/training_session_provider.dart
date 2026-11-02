import 'dart:async';
import 'dart:math';

import 'package:app_flutter/core/native/apple_health_service.dart';
import 'package:app_flutter/core/native/workout_live_activity_service.dart';
import 'package:app_flutter/features/training/application/providers/fatigue_auto_reduce_provider.dart';
import 'package:app_flutter/features/training/application/providers/rest_timer_settings_provider.dart';
import 'package:app_flutter/features/training/application/rest_alert_service.dart';
import 'package:app_flutter/features/exercises/domain/bodyweight.dart';
import 'package:app_flutter/features/exercises/domain/entities/exercise.dart';
import 'package:app_flutter/features/profile/application/providers/fitness_profile_provider.dart';
import 'package:app_flutter/features/profile/domain/entities/fitness_profile.dart';
import 'package:app_flutter/features/training/application/bodyweight_defaults.dart';
import 'package:app_flutter/features/training/application/exercise_editor.dart';
import 'package:app_flutter/features/training/data/models/session_models.dart';
import 'package:app_flutter/features/training/data/repositories/session_repository.dart';
import 'package:app_flutter/features/training/data/datasources/training_session_local_dao.dart';
import 'package:app_flutter/features/training/domain/bodyweight_load.dart';
import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:app_flutter/features/training/domain/entities/training_set_kind.dart';
import 'package:app_flutter/features/training/domain/new_set_defaults.dart';
import 'package:app_flutter/features/training/domain/rpe.dart';
import 'package:app_flutter/features/training/domain/set_elapsed.dart';
import 'package:app_flutter/features/training/domain/set_follow.dart';
import 'package:app_flutter/features/training/domain/strength.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'training_session_provider.g.dart';

/// 哨兵类型：用于区分「未传参」与「显式传 null」。
class _Unset {
  const _Unset();
}

const _unset = _Unset();

/// 当前进行中会话来源模板 id；结束/放弃时清空。
final activeTemplateIdProvider = StateProvider<int?>((ref) => null);

double? _asDouble(Object? value) {
  if (value is _Unset) return null;
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return null;
}

/// 全局共享的训练会话状态。
///
/// 由 `@riverpod` 生成 `trainingSessionProvider`（keepAlive，与应用生命周期一致），
/// 跨页面跳转保持同一份进行中会话。
///
/// 状态为 `AsyncValue<ActiveTraining?>`：
/// - `AsyncData(null)`：当前无进行中会话（未开始 / 已结束）。
/// - `AsyncData(非null)`：进行中会话（新建或冷启动恢复）。
/// - `AsyncLoading`：恢复检查 / 创建 / 完成请求进行中。
/// - `AsyncError`：请求异常，由页面转成用户可读文案。
@Riverpod(keepAlive: true)
class TrainingSession extends _$TrainingSession implements ExerciseListEditor {
  static final _random = Random();

  /// 生成客户端 UUID：服务端要求每次创建/每组上传都带稳定唯一串。
  ///
  /// 用「微秒时间戳 + 随机数」拼接，足够唯一，且避免新增 uuid 依赖。
  // ponytail: 时间戳+随机即可满足幂等需求，真正需要 RFC4122 时再换 uuid 包。
  String _newUuid() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32).toRadixString(16)}';

  int? get _globalRestSeconds => ref.read(restTimerSettingsProvider);

  void _syncLiveActivity(ActiveTraining session, {required bool start}) {
    final rest = _globalRestSeconds;
    if (start) {
      unawaited(
        WorkoutLiveActivityService.instance.start(
          session,
          globalRestSeconds: rest,
        ),
      );
    } else {
      unawaited(
        WorkoutLiveActivityService.instance.update(
          session,
          globalRestSeconds: rest,
        ),
      );
    }
  }

  @override
  Future<ActiveTraining?> build() async {
    WorkoutLiveActivityService.instance.cancelOverlappingRestAlert =
        RestAlertService.instance.cancel;

    // 开关/改休息时长时立刻刷新灵动岛，避免锁屏仍停在旧倒计时。
    ref.listen(restTimerSettingsProvider, (prev, next) {
      final session = state.asData?.value;
      if (session != null) _syncLiveActivity(session, start: false);
    });

    // 冷启动恢复：本地缓存优先（含完整动作/组数据，离线可用）；
    // 本地无缓存再查服务端是否进行中（此时仅会话头，动作为空）。
    final local = await _restoreFromLocal();
    if (local != null) {
      _syncLiveActivity(local, start: true);
      return local;
    }
    try {
      final restored = await _restoreFromServer();
      if (restored != null) {
        _syncLiveActivity(restored, start: true);
      }
      return restored;
    } catch (_) {
      return null;
    }
  }

  /// 从本地 SQLite 缓存恢复完整进行中会话；无缓存返回 null。
  Future<ActiveTraining?> _restoreFromLocal() async {
    try {
      return await ref.read(trainingSessionLocalDaoProvider).getActiveSession();
    } catch (_) {
      return null;
    }
  }

  /// 从服务端拉取进行中的会话并映射为本地 [ActiveTraining]；无则返回 null。
  ///
  /// 动作与组仅存在于本地内存（结束训练才批量上传），服务端进行中会话
  /// 不含这些数据，恢复后为空列表，由用户重新添加。
  Future<ActiveTraining?> _restoreFromServer() async {
    final session = await ref
        .read(sessionRepositoryProvider)
        .getInProgressSession();
    if (session == null) return null;
    return ActiveTraining(
      sessionId: session.id,
      clientUuid: session.clientUuid,
      startedAt: session.startedAt,
      exercises: const [],
    );
  }

  /// 开始训练：创建后端会话并进入进行中态。
  ///
  /// 1. 置为加载中。
  /// 2. 生成 clientUuid + 开始时间，调用 [SessionRepository.createSession]。
  /// 3. 以返回的会话 id 初始化 [ActiveTraining]。
  Future<void> start({int? templateId}) async {
    state = const AsyncLoading();
    try {
      final clientUuid = _newUuid();
      final startedAt = DateTime.now().toUtc();
      final id = await ref
          .read(sessionRepositoryProvider)
          .createSession(
            SessionCreate(clientUuid: clientUuid, startedAt: startedAt),
            templateId: templateId,
          );
      ref.read(activeTemplateIdProvider.notifier).state = templateId;
      state = AsyncData(
        ActiveTraining(
          sessionId: id,
          clientUuid: clientUuid,
          startedAt: startedAt,
          exercises: const [],
        ),
      );
      await _persist(state.value!);
      _syncLiveActivity(state.value!, start: true);
    } catch (error, stackTrace) {
      // 创建被拒（典型为 409：服务端已有进行中会话，如冷启动恢复检查失败后的重试）
      // → 尝试改为恢复该会话；恢复失败才回落到错误态。
      try {
        final restored = await _restoreFromServer();
        if (restored != null) {
          state = AsyncData(restored);
          await _persist(restored);
          _syncLiveActivity(restored, start: true);
          return;
        }
      } catch (_) {}
      state = AsyncError(error, stackTrace);
    }
  }

  /// 开一场，并把教练提案灌进动作列表。失败时返回 false。
  Future<bool> startWithPlan(List<TrainingExercise> exercises) async {
    await start();
    if (state.value == null) return false;
    final now = DateTime.now().toUtc();
    final planned = [
      for (var i = 0; i < exercises.length; i++)
        exercises[i].copyWith(
          sets: i == 0
              ? _armNextSetTimer(
                  [
                    for (final set in exercises[i].sets)
                      set.copyWith(clientUuid: _newUuid()),
                  ],
                  now,
                  force: false,
                )
              : [
                  for (final set in exercises[i].sets)
                    set.copyWith(clientUuid: _newUuid()),
                ],
        ),
    ];
    await loadTemplateExercises(planned, fillUntrainedWeight: true);
    return state.value != null;
  }

  /// 把教练建议的下一个动作追加到这场训练。已经在练则返回 false。
  Future<bool> addPlannedExercise(TrainingExercise exercise) async {
    final current = state.value;
    if (current == null) return false;
    if (current.exercises.any(
      (item) => item.exerciseId == exercise.exerciseId,
    )) {
      return false;
    }
    final now = DateTime.now().toUtc();
    final fresh = exercise.copyWith(
      sets: [
        for (final set in exercise.sets) set.copyWith(clientUuid: _newUuid()),
      ],
    );
    final hydrated = await _withBodyweight(
      fresh,
      bodyKg: readUserBodyweightKg(ref),
      fillUntrainedWeight: true,
    );
    final planned = hydrated.copyWith(
      sets: _armNextSetTimer(hydrated.sets, now, force: false),
    );
    final next = current.copyWith(
      exercises: [...current.exercises, planned],
      focusedExerciseId: planned.exerciseId,
    );
    state = AsyncData(next);
    _persist(next);
    _syncLiveActivity(next, start: false);
    return true;
  }

  /// 一次加入多个建议动作。已在练的跳过。空会话只给第一个动作的第一组记开始时间。
  Future<int> addPlannedExercises(List<TrainingExercise> exercises) async {
    final current = state.value;
    if (current == null || exercises.isEmpty) return 0;
    final now = DateTime.now().toUtc();
    final seen = {for (final item in current.exercises) item.exerciseId};
    final bodyKg = readUserBodyweightKg(ref);
    final planned = <TrainingExercise>[];
    for (final exercise in exercises) {
      if (!seen.add(exercise.exerciseId)) continue;
      final fresh = exercise.copyWith(
        sets: [
          for (final set in exercise.sets) set.copyWith(clientUuid: _newUuid()),
        ],
      );
      planned.add(
        await _withBodyweight(fresh, bodyKg: bodyKg, fillUntrainedWeight: true),
      );
    }
    if (planned.isEmpty) return 0;
    final wasEmpty = current.exercises.isEmpty;
    final merged = [
      ...current.exercises,
      for (var i = 0; i < planned.length; i++)
        if (wasEmpty && i == 0)
          planned[i].copyWith(
            sets: _armNextSetTimer(planned[i].sets, now, force: false),
          )
        else
          planned[i],
    ];
    final next = current.copyWith(
      exercises: merged,
      focusedExerciseId: wasEmpty
          ? planned.first.exerciseId
          : current.focusedExerciseId ?? planned.first.exerciseId,
    );
    state = AsyncData(next);
    _persist(next);
    _syncLiveActivity(next, start: false);
    return planned.length;
  }

  /// 用模板动作覆盖当前空列表（开始训练后立刻灌入计划组）。
  Future<void> loadTemplateExercises(
    List<TrainingExercise> exercises, {
    bool fillUntrainedWeight = false,
  }) async {
    final current = state.value;
    if (current == null) return;
    final bodyKg = readUserBodyweightKg(ref);
    final hydrated = <TrainingExercise>[];
    for (final exercise in exercises) {
      hydrated.add(
        await _withBodyweight(
          exercise,
          bodyKg: bodyKg,
          fillUntrainedWeight: fillUntrainedWeight,
        ),
      );
    }
    state = AsyncData(
      current.copyWith(
        exercises: hydrated,
        focusedExerciseId: hydrated.isEmpty ? null : hydrated.first.exerciseId,
      ),
    );
    await _persist(state.value!);
  }

  /// 把当前会话写入本地缓存（失败不阻塞训练，下次冷启动仅丢失最新一次编辑）。
  Future<void> _persist(ActiveTraining session) async {
    try {
      await ref
          .read(trainingSessionLocalDaoProvider)
          .saveActiveSession(session);
    } catch (_) {}
  }

  /// 清除本地缓存中的进行中会话。
  Future<void> _clearLocal() async {
    try {
      await ref.read(trainingSessionLocalDaoProvider).clearActiveSession();
    } catch (_) {}
  }

  /// 批量加入动作（来自动作选择库）。
  ///
  /// 已存在的 `exerciseId` 会被跳过，避免重复；[supersetId] 用于标记超级组。
  /// 并行拉取各动作最近一次训练的组数据（`last-session-sets`），预填重量/次数等；
  /// 无历史时器械默认 10kg×8，徒手默认 8 次且重量留空（界面显示「自重」）。
  /// 无历史或网络异常时回退为默认一组，不影响添加动作。
  Future<void> addExercises(List<Exercise> exercises, {int? supersetId}) async {
    final current = state.value;
    if (current == null) return;
    final existing = current.exercises.map((e) => e.exerciseId).toSet();
    final repo = ref.read(sessionRepositoryProvider);
    final toAdd = exercises.where((e) => !existing.contains(e.id)).toList();
    if (toAdd.isEmpty) return;
    final catalog = await loadEquipmentCatalog(ref);
    final added = await Future.wait(
      toAdd.map((e) async {
        final isBw = isBodyweightByCatalog(e.equipmentId, catalog);
        List<TrainingSet> sets = const [];
        List<GhostSet> ghostSets = const [];
        DateTime? ghostSessionDate;
        try {
          final last = await repo.getLastSessionSets(e.id);
          if (last != null && last.sets.isNotEmpty) {
            ghostSets = last.sets
                .map(
                  (s) => GhostSet(
                    setNumber: s.setNumber,
                    reps: s.reps,
                    weightKg: s.weightKg,
                    rpe: s.rpe,
                  ),
                )
                .toList();
            ghostSessionDate = last.sessionDate;
            sets = [
              for (final s in last.sets)
                TrainingSet(
                  setNumber: s.setNumber,
                  reps: s.reps,
                  weightKg: s.weightKg,
                  clientUuid: _newUuid(),
                ),
            ];
          } else {
            sets = [
              defaultNewTrainingSet(clientUuid: _newUuid(), isBodyweight: isBw),
            ];
          }
        } catch (_) {
          sets = [
            defaultNewTrainingSet(clientUuid: _newUuid(), isBodyweight: isBw),
          ];
        }
        if (!isBw) {
          sets = _suggestFrom1rm(sets, ghostSets);
        }
        return TrainingExercise(
          exerciseId: e.id,
          name: e.name,
          imageUrl: e.imageUrl,
          exerciseType: e.exerciseType,
          isBodyweight: isBw,
          supersetId: supersetId,
          sets: sets,
          ghostSets: ghostSets,
          ghostSessionDate: ghostSessionDate,
        );
      }),
    );
    final now = DateTime.now().toUtc();
    final focusedId = added.isNotEmpty
        ? added.last.exerciseId
        : current.focusedExerciseId;
    // 只给当前展开的动作开表。其余动作等到切过去再计，避免第一组耗时变成整场时长。
    final queued = [
      for (final exercise in added)
        if (exercise.exerciseId == focusedId)
          exercise.copyWith(
            sets: _armNextSetTimer(exercise.sets, now, force: false),
          )
        else
          exercise,
    ];
    state = AsyncData(
      current.copyWith(
        exercises: [...current.exercises, ...queued],
        focusedExerciseId: focusedId,
      ),
    );
    await _persist(state.value!);
    _syncLiveActivity(state.value!, start: false);
  }

  /// 用新动作替换 [oldId]，保留已填组、备注、休息和单位。
  Future<bool> replaceExercise(int oldId, Exercise next) async {
    final current = state.value;
    if (current == null) return false;
    if (next.id == oldId) return true;
    if (current.exercises.any((e) => e.exerciseId == next.id)) return false;
    final idx = current.exercises.indexWhere((e) => e.exerciseId == oldId);
    if (idx < 0) return false;

    List<GhostSet> ghostSets = const [];
    DateTime? ghostSessionDate;
    try {
      final last = await ref
          .read(sessionRepositoryProvider)
          .getLastSessionSets(next.id);
      if (last != null && last.sets.isNotEmpty) {
        ghostSets = last.sets
            .map(
              (s) => GhostSet(
                setNumber: s.setNumber,
                reps: s.reps,
                weightKg: s.weightKg,
                rpe: s.rpe,
              ),
            )
            .toList();
        ghostSessionDate = last.sessionDate;
      }
    } catch (_) {}

    final old = current.exercises[idx];
    final isBw = isBodyweightByCatalog(
      next.equipmentId,
      await loadEquipmentCatalog(ref),
    );
    final replaced = [...current.exercises]
      ..[idx] = old.copyWith(
        exerciseId: next.id,
        name: next.name,
        imageUrl: next.imageUrl,
        exerciseType: next.exerciseType,
        isBodyweight: isBw,
        ghostSets: ghostSets,
        ghostSessionDate: ghostSessionDate,
        sets: isBw
            ? fillBodyweightIfMissing(old.sets, readUserBodyweightKg(ref))
            : old.sets,
      );
    final focused = current.focusedExerciseId == oldId
        ? next.id
        : current.focusedExerciseId;
    state = AsyncData(
      current.copyWith(exercises: replaced, focusedExerciseId: focused),
    );
    await _persist(state.value!);
    return true;
  }

  void updateExercise(
    int exerciseId, {
    Object? notes = _unset,
    Object? restTargetSeconds = _unset,
    String? weightUnit,
  }) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        exercises: [
          for (final e in current.exercises)
            if (e.exerciseId != exerciseId)
              e
            else
              e.copyWith(
                notes: notes is _Unset ? e.notes : notes as String?,
                restTargetSeconds: restTargetSeconds is _Unset
                    ? e.restTargetSeconds
                    : restTargetSeconds as int?,
                weightUnit: weightUnit ?? e.weightUnit,
              ),
        ],
      ),
    );
    _persist(state.value!);
  }

  /// 删除动作及其全部组。
  void removeExercise(int exerciseId) {
    final current = state.value;
    if (current == null) return;
    final idx = current.exercises.indexWhere((e) => e.exerciseId == exerciseId);
    if (idx < 0) return;
    final remaining = [...current.exercises]..removeAt(idx);
    int? focused = current.focusedExerciseId;
    if (focused == exerciseId) {
      // 删掉当前展开动作：落到相邻的下一个（否则上一个）；无动作则清空。
      if (remaining.isEmpty) {
        focused = null;
      } else if (idx < remaining.length) {
        focused = remaining[idx].exerciseId;
      } else {
        focused = remaining.last.exerciseId;
      }
    }
    state = AsyncData(
      current.copyWith(exercises: remaining, focusedExerciseId: focused),
    );
    _persist(state.value!);
  }

  /// 切换动作卡片展开：同一时间只展开一个；再点当前展开项则收起。
  void toggleExerciseExpanded(int exerciseId) {
    final current = state.value;
    if (current == null) return;
    if (current.focusedExerciseId == exerciseId) {
      state = AsyncData(current.copyWith(focusedExerciseId: null));
      _persist(state.value!);
      _syncLiveActivity(state.value!, start: false);
      return;
    }
    focusExercise(exerciseId);
  }

  /// 将指定动作设为当前展开（正在练），并为其未完成组开表。
  void focusExercise(int exerciseId) {
    final current = state.value;
    if (current == null) return;
    if (!current.exercises.any((e) => e.exerciseId == exerciseId)) return;
    final now = DateTime.now().toUtc();
    final switching =
        current.focusedExerciseId != null &&
        current.focusedExerciseId != exerciseId;
    state = AsyncData(
      current.copyWith(
        focusedExerciseId: exerciseId,
        exercises: current.exercises.map((e) {
          if (e.exerciseId != exerciseId) return e;
          // 还没练过的动作，从切过来这一刻重开，不沿用加入列表时的起点。
          final fresh = e.sets.every((s) => s.completedAt == null);
          return e.copyWith(
            sets: _armNextSetTimer(e.sets, now, force: switching && fresh),
          );
        }).toList(),
      ),
    );
    _persist(state.value!);
    _syncLiveActivity(state.value!, start: false);
  }

  /// 给指定动作新增一组。
  void addSet(int exerciseId) {
    final current = state.value;
    if (current == null) return;
    final now = DateTime.now().toUtc();
    state = AsyncData(
      current.copyWith(
        exercises: current.exercises.map((e) {
          if (e.exerciseId != exerciseId) return e;
          final nextNumber = e.sets.isEmpty
              ? 1
              : e.sets.map((s) => s.setNumber).reduce(max) + 1;
          // 新增一组时复制上一组的次数与重量，减少重复输入。
          final previous = e.sets.isEmpty
              ? null
              : e.sets.reduce((a, b) => a.setNumber > b.setNumber ? a : b);
          final priorRpes = [
            for (final s in e.sets)
              if (previous != null &&
                  s.setNumber != previous.setNumber &&
                  s.completedAt != null &&
                  s.rpe != null &&
                  s.setKind != TrainingSetKind.warmup)
                s.rpe!,
          ];
          final previousKg = copiedWeightAfterPrevious(
            previousKg: previous?.weightKg,
            previousReps: previous?.reps,
            previousCompletedAt: previous?.completedAt,
            previousRpe: previous?.rpe,
            exerciseType: e.exerciseType,
            goal: _trainingGoal(),
            priorRpes: priorRpes,
            unit: e.weightUnit,
            autoReduce: ref.read(fatigueAutoReduceEnabledProvider),
          );
          final next = [
            ...e.sets,
            TrainingSet(
              setNumber: nextNumber,
              reps: previous?.reps,
              weightKg: copyOrBodyweightKg(
                isBodyweight: e.isBodyweight,
                previousKg: previousKg,
                // 徒手空重量保持「自重」，不要把档案体重写进格子。
                bodyKg: e.isBodyweight ? null : readUserBodyweightKg(ref),
              ),
              // 继承上一组类型，减少重复点选（热身/主要/放松/递减）。
              setKind: previous?.setKind ?? TrainingSetKind.working,
              // 不在创建时开表；由 [_armNextSetTimer] 只给当前要练的那一组计时。
              clientUuid: _newUuid(),
            ),
          ];
          return e.copyWith(sets: _armNextSetTimer(next, now, force: false));
        }).toList(),
      ),
    );
    _persist(state.value!);
  }

  /// 删除指定动作下的一组。
  ///
  /// 每个动作至少保留一组；若只剩一组则忽略（应改删整个动作）。
  void removeSet(int exerciseId, int setNumber) {
    final current = state.value;
    if (current == null) return;
    final exercise = current.exercises
        .where((e) => e.exerciseId == exerciseId)
        .firstOrNull;
    if (exercise == null || exercise.sets.length <= 1) return;
    final now = DateTime.now().toUtc();
    state = AsyncData(
      current.copyWith(
        exercises: current.exercises.map((e) {
          if (e.exerciseId != exerciseId) return e;
          final next = e.sets.where((s) => s.setNumber != setNumber).toList();
          return e.copyWith(sets: _armNextSetTimer(next, now, force: false));
        }).toList(),
      ),
    );
    _persist(state.value!);
  }

  /// 切换某组的完成状态：勾选写入完成时间与**本组用时**；取消则清空完成时间。
  ///
  /// 用时 = `now - 本组 startedAt`。完成后给下一组未完成组开表，使下一组耗时从此时起算，
  /// 不再相对会话开始或上一组创建时间累计。
  /// 这个动作的组都勾完时，收起它并展开下一个还有未完成组的动作。
  /// 无 RPE 的完成会清掉休息加时；带 RPE 的完成请走 [completeSetWithRpe]。
  void toggleSetDone(int exerciseId, int setNumber) {
    final current = state.value;
    if (current == null) return;
    final now = DateTime.now().toUtc();
    var restBonus = current.restBonusSeconds;
    var finishedExercise = false;
    final exercises = current.exercises.map((e) {
      if (e.exerciseId != exerciseId) return e;
      var unchecked = false;
      final updated = e.sets.map((s) {
        if (s.setNumber != setNumber) return s;
        if (s.completedAt != null) {
          unchecked = true;
          return s.copyWith(completedAt: null);
        }
        restBonus = 0;
        return s.copyWith(
          completedAt: now,
          restSeconds: _elapsedSeconds(current.exercises, s, now),
        );
      }).toList();
      final armed = _armNextSetTimer(updated, now, force: true);
      finishedExercise =
          !unchecked && armed.every((s) => s.completedAt != null);
      return e.copyWith(sets: armed);
    }).toList();

    var focusedId = current.focusedExerciseId;
    var exercisesOut = exercises;
    if (finishedExercise) {
      focusedId = _nextOpenExerciseId(exercises, exerciseId);
      if (focusedId != null) {
        exercisesOut = [
          for (final exercise in exercises)
            if (exercise.exerciseId != focusedId)
              exercise
            else
              exercise.copyWith(
                sets: _armNextSetTimer(
                  exercise.sets,
                  now,
                  force: exercise.sets.every((s) => s.completedAt == null),
                ),
              ),
        ];
      }
    }

    state = AsyncData(
      current.copyWith(
        exercises: exercisesOut,
        focusedExerciseId: focusedId,
        restBonusSeconds: restBonus,
      ),
    );
    _persist(state.value!);
    _syncLiveActivity(state.value!, start: false);
  }

  /// 刚练完 [finishedId] 之后，下一个还有未完成组的动作。后面没有就回到前面。
  int? _nextOpenExerciseId(List<TrainingExercise> exercises, int finishedId) {
    final index = exercises.indexWhere((e) => e.exerciseId == finishedId);
    if (index < 0) return null;
    bool open(TrainingExercise exercise) =>
        exercise.sets.any((s) => s.completedAt == null);
    for (var i = index + 1; i < exercises.length; i++) {
      if (open(exercises[i])) return exercises[i].exerciseId;
    }
    for (var i = 0; i < index; i++) {
      if (open(exercises[i])) return exercises[i].exerciseId;
    }
    return null;
  }

  /// 完成本组并写入 RPE：热力图、自动调节预填、红区加时、力竭降重建议。
  RpeFollowUp? completeSetWithRpe(int exerciseId, int setNumber, double rpe) {
    final current = state.value;
    if (current == null) return null;
    final now = DateTime.now().toUtc();
    final normalized = normalizeRpe(rpe);

    TrainingSet? completed;
    var alreadyDone = false;
    final exercises = current.exercises.map((e) {
      if (e.exerciseId != exerciseId) return e;
      var updated = e.sets.map((s) {
        if (s.setNumber != setNumber) return s;
        final warmup = s.setKind == TrainingSetKind.warmup;
        if (s.completedAt != null) {
          alreadyDone = true;
          completed = s.copyWith(rpe: warmup ? null : normalized);
          return completed!;
        }
        completed = s.copyWith(
          completedAt: now,
          restSeconds: _elapsedSeconds(current.exercises, s, now),
          rpe: warmup ? null : normalized,
        );
        return completed!;
      }).toList();
      // 勾选时已经开过下一组的表。事后补记 RPE 只改这一组，不再把下一组开始时间推到现在。
      if (!alreadyDone) updated = _armNextSetTimer(updated, now, force: true);
      return e.copyWith(sets: updated);
    }).toList();

    if (completed == null) return null;
    if (completed!.setKind == TrainingSetKind.warmup) {
      state = AsyncData(
        current.copyWith(exercises: exercises, restBonusSeconds: 0),
      );
      _persist(state.value!);
      _syncLiveActivity(state.value!, start: false);
      return null;
    }
    final weight = completed!.weightKg;
    final exercise = exercises.firstWhere((e) => e.exerciseId == exerciseId);
    final priorRpes = [
      for (final s in exercise.sets)
        if (s.setNumber != setNumber &&
            s.completedAt != null &&
            s.rpe != null &&
            s.setKind != TrainingSetKind.warmup)
          s.rpe!,
    ];
    double? oneRm;
    try {
      oneRm = estimated1rmFromExercise(exercise);
    } catch (_) {}
    final goal = _trainingGoal();
    final advice = weight != null && weight > 0
        ? recommendNextSet(
            weightKg: weight,
            rpe: normalized,
            reps: completed!.reps,
            oneRmKg: oneRm,
            exerciseType: exercise.exerciseType,
            priorRpes: priorRpes,
            goal: goal,
            unit: exercise.weightUnit,
          )
        : const RpeAdvice();

    final withSuggestion = exercises.map((e) {
      if (e.exerciseId != exerciseId) return e;
      return e.copyWith(
        sets: e.sets.map((s) {
          if (s.completedAt != null) return s;
          if (advice.suggestedWeightKg == null) return s;
          if (s.weightKg != null) return s;
          return s.copyWith(suggestedWeightKg: advice.suggestedWeightKg);
        }).toList(),
      );
    }).toList();

    var exercisesOut = withSuggestion;
    var autoReduced = false;
    final nextWeight = advice.suggestedWeightKg;
    if (nextWeight != null &&
        weight != null &&
        nextWeight < weight - 1e-9 &&
        (advice.fatigueWarning || normalized >= kRpeRedZone) &&
        ref.read(fatigueAutoReduceEnabledProvider)) {
      final reduced = _reduceRemainingOn(
        withSuggestion,
        exerciseId,
        failedWeightKg: weight,
        nextWeightKg: nextWeight,
        onlyNext: !advice.fatigueWarning,
      );
      if (_weightsChanged(withSuggestion, reduced)) {
        exercisesOut = reduced;
        autoReduced = true;
      }
    }

    state = AsyncData(
      current.copyWith(
        exercises: exercisesOut,
        restBonusSeconds: advice.extraRestSeconds,
      ),
    );
    _persist(state.value!);
    _syncLiveActivity(state.value!, start: false);
    return RpeFollowUp(
      exerciseId: exerciseId,
      setNumber: setNumber,
      advice: advice,
      autoReduced: autoReduced,
    );
  }

  /// 一键采纳下一组建议重量，并同步到之后未完成的同类型组。
  void applySuggestedWeight(int exerciseId, int setNumber) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        exercises: current.exercises.map((e) {
          if (e.exerciseId != exerciseId) return e;
          final target = e.sets
              .where((s) => s.setNumber == setNumber)
              .firstOrNull;
          final suggested = target?.suggestedWeightKg;
          if (target == null || suggested == null) return e;
          return e.copyWith(
            sets: patchSetAndFollow(
              sets: e.sets,
              edited: target.copyWith(
                weightKg: suggested,
                suggestedWeightKg: null,
              ),
              followWeight: true,
            ),
          );
        }).toList(),
      ),
    );
    _persist(state.value!);
  }

  /// 按本动作第一次力竭的建议，下调还没做、且不比该组轻的正式组。
  void reduceRemainingWeights(int exerciseId) {
    final current = state.value;
    if (current == null) return;
    final exercise = current.exercises
        .where((e) => e.exerciseId == exerciseId)
        .firstOrNull;
    if (exercise == null) return;
    final prior = <double>[];
    TrainingSet? failed;
    for (final s in exercise.sets) {
      if (s.completedAt == null ||
          s.rpe == null ||
          s.setKind == TrainingSetKind.warmup) {
        continue;
      }
      if (normalizeRpe(s.rpe!) >= kRpeFailure && (s.weightKg ?? 0) > 0) {
        failed = s;
        break;
      }
      prior.add(s.rpe!);
    }
    final failedWeight = failed?.weightKg;
    if (failed == null || failedWeight == null) return;
    final advice = recommendNextSet(
      weightKg: failedWeight,
      rpe: failed.rpe!,
      reps: failed.reps,
      exerciseType: exercise.exerciseType,
      priorRpes: prior,
      goal: _trainingGoal(),
      unit: exercise.weightUnit,
    );
    final next = advice.suggestedWeightKg;
    if (next == null || next >= failedWeight - 1e-9) return;
    state = AsyncData(
      current.copyWith(
        exercises: _reduceRemainingOn(
          current.exercises,
          exerciseId,
          failedWeightKg: failedWeight,
          nextWeightKg: next,
        ),
      ),
    );
    _persist(state.value!);
  }

  bool _weightsChanged(
    List<TrainingExercise> before,
    List<TrainingExercise> after,
  ) {
    if (before.length != after.length) return true;
    for (var i = 0; i < before.length; i++) {
      final left = before[i].sets;
      final right = after[i].sets;
      if (left.length != right.length) return true;
      for (var j = 0; j < left.length; j++) {
        if (left[j].weightKg != right[j].weightKg) return true;
      }
    }
    return false;
  }

  String _trainingGoal() {
    try {
      return ref.read(fitnessProfileProvider).value?.goal ??
          FitnessGoal.muscleGain;
    } catch (_) {
      return FitnessGoal.muscleGain;
    }
  }

  /// 把还没做的正式组写成 [nextWeightKg]。
  ///
  /// 比刚力竭这组更轻的退让、递减、放松组保持原重。
  /// [onlyNext] 只改第一组符合条件的正式组（连续红区少一片）。
  List<TrainingExercise> _reduceRemainingOn(
    List<TrainingExercise> exercises,
    int exerciseId, {
    required double failedWeightKg,
    required double nextWeightKg,
    bool onlyNext = false,
  }) {
    return exercises.map((e) {
      if (e.exerciseId != exerciseId) return e;
      var written = false;
      return e.copyWith(
        sets: e.sets.map((s) {
          if (written && onlyNext) return s;
          if (s.completedAt != null) return s;
          if (s.setKind != TrainingSetKind.working) return s;
          if (s.weightKg != null && s.weightKg! < failedWeightKg - 1e-9) {
            return s;
          }
          written = true;
          return s.copyWith(weightKg: nextWeightKg, suggestedWeightKg: null);
        }).toList(),
      );
    }).toList();
  }

  int? _elapsedSeconds(
    List<TrainingExercise> exercises,
    TrainingSet set,
    DateTime now,
  ) {
    return setElapsedSeconds(
      startedAt: set.startedAt,
      now: now,
      otherCompletedAt: [
        for (final exercise in exercises)
          for (final other in exercise.sets)
            if (!identical(other, set)) other.completedAt,
      ],
    );
  }

  /// 给当前第一个未完成组写入 [startedAt]。
  ///
  /// [force] 为 false 时若已有起点则不改（追加组时不打断正在练的一组）；
  /// 为 true 时覆盖为 [now]（完成上一组后下一组从此刻起算）。
  List<TrainingSet> _armNextSetTimer(
    List<TrainingSet> sets,
    DateTime now, {
    required bool force,
  }) {
    final index = sets.indexWhere((s) => s.completedAt == null);
    if (index < 0) return sets;
    if (!force && sets[index].startedAt != null) return sets;
    return [
      for (var i = 0; i < sets.length; i++)
        if (i == index) sets[i].copyWith(startedAt: now) else sets[i],
    ];
  }

  /// 更新某组的可编辑字段（次数 / 重量 / 休息 / 时长 / 距离 / 备注 / 组类型）。
  ///
  /// 用 [_unset] 哨兵区分「未传参（保留原值）」与「显式传 null（清空）」，
  /// 否则调用方只改次数时会误把休息/时长等字段清空。
  /// [setKind] 为非空枚举：传 null 表示不改。
  ///
  /// [followRemaining] 为 true 时，把本次改动的次数或重量同步到后面还没做的同类型组。
  /// [followMatching] 为 true 时，改为让还没完成、且该字段仍等于旧值的组跟着变。
  /// 「只这组」两个都传 false。已完成的组不改。
  @override
  void updateSet(
    int exerciseId,
    int setNumber, {
    Object? reps = _unset,
    Object? weightKg = _unset,
    Object? restSeconds = _unset,
    Object? durationSeconds = _unset,
    Object? distanceMeters = _unset,
    Object? notes = _unset,
    TrainingSetKind? setKind,
    Object? rpe = _unset,
    Object? suggestedWeightKg = _unset,
    bool followRemaining = true,
    bool followMatching = false,
  }) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        exercises: current.exercises.map((e) {
          if (e.exerciseId != exerciseId) return e;
          final target = e.sets
              .where((s) => s.setNumber == setNumber)
              .firstOrNull;
          if (target == null) return e;
          final kind = setKind ?? target.setKind;
          final edited = target.copyWith(
            reps: reps is _Unset ? target.reps : reps as int?,
            weightKg: weightKg is _Unset
                ? target.weightKg
                : _asDouble(weightKg),
            restSeconds: restSeconds is _Unset
                ? target.restSeconds
                : restSeconds as int?,
            durationSeconds: durationSeconds is _Unset
                ? target.durationSeconds
                : durationSeconds as int?,
            distanceMeters: distanceMeters is _Unset
                ? target.distanceMeters
                : _asDouble(distanceMeters),
            notes: notes is _Unset ? target.notes : notes as String?,
            setKind: kind,
            rpe: kind == TrainingSetKind.warmup
                ? null
                : (rpe is _Unset ? target.rpe : _asDouble(rpe)),
            suggestedWeightKg: suggestedWeightKg is _Unset
                ? target.suggestedWeightKg
                : _asDouble(suggestedWeightKg),
          );
          final followReps = reps is! _Unset;
          final followWeight = weightKg is! _Unset;
          return e.copyWith(
            sets: followMatching
                ? patchSetMatching(
                    sets: e.sets,
                    edited: edited,
                    previousReps: target.reps,
                    previousWeightKg: target.weightKg,
                    followReps: followReps,
                    followWeight: followWeight,
                  )
                : patchSetAndFollow(
                    sets: e.sets,
                    edited: edited,
                    followReps: followRemaining && followReps,
                    followWeight: followRemaining && followWeight,
                  ),
          );
        }).toList(),
      ),
    );
    _persist(state.value!);
  }

  /// 把传入的非空字段值批量应用到该动作下的全部组（「所有组」批量编辑）。
  void updateAllSets(int exerciseId, {int? reps, double? weightKg}) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        exercises: current.exercises.map((e) {
          if (e.exerciseId != exerciseId) return e;
          return e.copyWith(
            sets: e.sets.map((s) {
              if (s.completedAt != null) return s;
              var next = s;
              if (reps != null) next = next.copyWith(reps: reps);
              if (weightKg != null) next = next.copyWith(weightKg: weightKg);
              return next;
            }).toList(),
          );
        }).toList(),
      ),
    );
    _persist(state.value!);
  }

  /// 结束训练：只上传已完成的组；未完成组丢弃且不写入数据库。
  ///
  /// 返回是否成功；失败时保留进行中态，让页面可以继续编辑或重试。
  Future<bool> finish({String? notes}) async {
    final current = state.value;
    if (current == null) return false;
    state = const AsyncLoading();
    try {
      final sets = <WorkoutSetCreate>[];
      for (final exercise in current.exercises) {
        var number = 1;
        for (final set in exercise.sets) {
          if (set.completedAt == null) continue;
          sets.add(
            WorkoutSetCreate(
              exerciseId: exercise.exerciseId,
              setNumber: number,
              reps: set.reps,
              weightKg: set.weightKg,
              durationSeconds: set.durationSeconds,
              distanceMeters: set.distanceMeters,
              notes: set.notes,
              completedAt: set.completedAt,
              clientUuid: set.clientUuid,
              rpe: set.rpe,
            ),
          );
          number++;
        }
      }
      await ref
          .read(sessionRepositoryProvider)
          .completeSession(
            current.sessionId,
            SessionComplete(
              clientUuid: current.clientUuid,
              startedAt: current.startedAt,
              completedAt: DateTime.now().toUtc(),
              notes: notes,
              sets: sets,
            ),
            templateId: ref.read(activeTemplateIdProvider),
          );
      final completedAt = DateTime.now().toUtc();
      unawaited(
        AppleHealthService.instance.saveStrengthWorkout(
          start: current.startedAt,
          end: completedAt,
        ),
      );
      unawaited(WorkoutLiveActivityService.instance.end());
      unawaited(RestAlertService.instance.cancel());
      ref.read(activeTemplateIdProvider.notifier).state = null;
      state = const AsyncData(null);
      await _clearLocal();
      return true;
    } catch (_) {
      // 失败时保留进行中态，让页面可以继续编辑或重试。
      state = AsyncData(current);
      return false;
    }
  }

  /// 放弃训练：清空本地进行中会话，并尽力删除服务端会话。
  ///
  /// 服务端删除失败不阻塞放弃（离线也应可放弃）；残留的进行中会话
  /// 下次冷启动会被「返回训练」恢复，届时可再次放弃或正常结束。
  Future<void> discard() async {
    final current = state.value;
    if (current == null) return;
    state = const AsyncData(null);
    await _clearLocal();
    unawaited(WorkoutLiveActivityService.instance.end());
    unawaited(RestAlertService.instance.cancel());
    ref.read(activeTemplateIdProvider.notifier).state = null;
    try {
      await ref
          .read(sessionRepositoryProvider)
          .deleteSession(current.sessionId);
    } catch (_) {}
  }

  Future<TrainingExercise> _withBodyweight(
    TrainingExercise exercise, {
    double? bodyKg,
    bool fillUntrainedWeight = false,
  }) async {
    final isBw =
        exercise.isBodyweight ||
        await resolveIsBodyweight(ref, exerciseId: exercise.exerciseId);
    final applied = applyBodyweightDefault(
      exercise.copyWith(isBodyweight: isBw),
      bodyKg ?? readUserBodyweightKg(ref),
    );
    if (!fillUntrainedWeight) return applied;
    return applied.copyWith(
      sets: fillUntrainedEquipmentWeight(
        applied.sets,
        isBodyweight: applied.isBodyweight,
      ),
    );
  }

  List<TrainingSet> _suggestFrom1rm(
    List<TrainingSet> sets,
    List<GhostSet> ghosts,
  ) {
    final samples = <double>[];
    for (final g in ghosts) {
      final est = estimate1rm(weightKg: g.weightKg, reps: g.reps, rpe: g.rpe);
      if (est != null) samples.add(est);
    }
    final e1rm = blendEstimates(samples);
    if (e1rm == null) return sets;
    var goal = FitnessGoal.muscleGain;
    try {
      goal = ref.read(fitnessProfileProvider).value?.goal ?? goal;
    } catch (_) {}
    final suggested = workingWeight(e1rm, goal);
    if (suggested == null) return sets;
    return [
      for (final s in sets)
        s.weightKg == null ? s.copyWith(weightKg: suggested) : s,
    ];
  }
}
