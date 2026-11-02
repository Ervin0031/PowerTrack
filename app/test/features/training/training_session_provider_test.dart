import 'package:app_flutter/core/providers/dio_provider.dart';
import 'package:app_flutter/features/exercises/domain/entities/exercise.dart';
import 'package:app_flutter/features/profile/application/providers/fitness_profile_provider.dart';
import 'package:app_flutter/features/profile/domain/entities/fitness_profile.dart';
import 'package:app_flutter/features/training/application/providers/fatigue_auto_reduce_provider.dart';
import 'package:app_flutter/features/training/application/providers/training_session_provider.dart';
import 'package:app_flutter/features/training/data/models/session_models.dart';
import 'package:app_flutter/features/training/data/repositories/session_repository.dart';
import 'package:app_flutter/features/training/data/datasources/training_session_local_dao.dart';
import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:app_flutter/features/training/domain/entities/training_set_kind.dart';
import 'package:app_flutter/features/training/domain/rpe.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 本地 DAO 桩：不触碰 SQLite。
class _StubDao extends TrainingSessionLocalDao {
  _StubDao(super.ref);

  @override
  Future<ActiveTraining?> getActiveSession() async => null;

  @override
  Future<void> saveActiveSession(ActiveTraining session) async {}

  @override
  Future<void> clearActiveSession() async {}
}

/// 会话仓库桩：不发起网络请求。
class _StubRepo extends SessionRepository {
  _StubRepo() : super(Dio());

  SessionComplete? lastComplete;

  @override
  Future<InProgressSession?> getInProgressSession() async => null;

  @override
  Future<int> createSession(SessionCreate body, {int? templateId}) async => 1;

  @override
  Future<void> completeSession(
    int sessionId,
    SessionComplete body, {
    int? templateId,
  }) async {
    lastComplete = body;
  }

  @override
  Future<void> deleteSession(int sessionId) async {}

  LastSessionSets? lastSets;

  @override
  Future<LastSessionSets?> getLastSessionSets(int exId) async => lastSets;
}

class _StubFitnessProfile extends FitnessProfileController {
  @override
  Future<FitnessProfile?> build() async => const FitnessProfile(
    gender: FitnessGender.male,
    birthYear: 1990,
    heightCm: 175,
    weightKg: 72,
    goal: FitnessGoal.muscleGain,
    experience: FitnessExperience.intermediate,
  );
}

void main() {
  late ProviderContainer container;
  late TrainingSession notifier;
  late _StubRepo repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'training.rest_timer_enabled': false,
    });
    final prefs = await SharedPreferences.getInstance();
    repo = _StubRepo();
    container = ProviderContainer(
      overrides: [
        trainingSessionLocalDaoProvider.overrideWith(_StubDao.new),
        sessionRepositoryProvider.overrideWith((ref) => repo),
        fitnessProfileProvider.overrideWith(_StubFitnessProfile.new),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);
    notifier = container.read(trainingSessionProvider.notifier);
    await container.read(trainingSessionProvider.future);
    await container.read(fitnessProfileProvider.future);
  });

  TrainingSet setOf(int setNumber) => notifier.state.value!.exercises.first.sets
      .firstWhere((s) => s.setNumber == setNumber);

  test('只改次数时保留休息值，显式传 null 才清空', () async {
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026),
        exercises: [
          TrainingExercise(
            exerciseId: 1,
            name: '卧推',
            sets: [
              TrainingSet(
                setNumber: 1,
                reps: 8,
                restSeconds: 90,
                clientUuid: 's1',
              ),
            ],
          ),
        ],
      ),
    );

    // 只传次数：休息值必须保留（回归：曾因未传参被误清空）。
    notifier.updateSet(1, 1, reps: 10);
    expect(setOf(1).reps, 10);
    expect(setOf(1).restSeconds, 90);

    // 显式传 null 才算清空。
    notifier.updateSet(1, 1, reps: null);
    expect(setOf(1).reps, isNull);
    expect(setOf(1).restSeconds, 90);

    notifier.updateSet(1, 1, restSeconds: null);
    expect(setOf(1).restSeconds, isNull);
  });

  test('新增一组时复制上一组的次数与重量与类型', () async {
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026),
        exercises: [
          TrainingExercise(
            exerciseId: 1,
            name: '卧推',
            sets: [
              TrainingSet(
                setNumber: 1,
                reps: 8,
                weightKg: 60,
                setKind: TrainingSetKind.warmup,
                clientUuid: 's1',
              ),
            ],
          ),
        ],
      ),
    );

    notifier.addSet(1);
    final sets = notifier.state.value!.exercises.first.sets;
    expect(sets, hasLength(2));
    expect(sets.last.setNumber, 2);
    expect(sets.last.reps, 8);
    expect(sets.last.weightKg, 60);
    expect(sets.last.setKind, TrainingSetKind.warmup);

    // 删光动作后重新追加：无上一组可复制，默认主要组。
    notifier.removeExercise(1);
    notifier.state = AsyncData(
      notifier.state.value!.copyWith(
        exercises: [
          const TrainingExercise(exerciseId: 1, name: '卧推', sets: []),
        ],
      ),
    );
    notifier.addSet(1);
    final fresh = notifier.state.value!.exercises.first.sets.single;
    expect(fresh.reps, isNull);
    expect(fresh.weightKg, isNull);
    expect(fresh.setKind, TrainingSetKind.working);
  });

  test('完成本组耗时不累计会话起点，并给下一组重新开表', () async {
    final now = DateTime.now().toUtc();
    final sessionStart = now.subtract(const Duration(hours: 1));
    final setStart = now.subtract(const Duration(seconds: 40));
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: sessionStart,
        exercises: [
          TrainingExercise(
            exerciseId: 1,
            name: '深蹲',
            sets: [
              TrainingSet(
                setNumber: 1,
                reps: 5,
                startedAt: setStart,
                clientUuid: 's1',
              ),
              TrainingSet(setNumber: 2, reps: 5, clientUuid: 's2'),
            ],
          ),
        ],
      ),
    );

    notifier.toggleSetDone(1, 1);
    final sets = notifier.state.value!.exercises.first.sets;
    final first = sets.firstWhere((s) => s.setNumber == 1);
    final second = sets.firstWhere((s) => s.setNumber == 2);

    // 本组约 40 秒；若误用会话起点会接近 1 小时。
    expect(first.restSeconds, inInclusiveRange(35, 50));
    expect(first.completedAt, isNotNull);
    expect(second.startedAt, isNotNull);
    expect(second.startedAt!.isAfter(setStart), isTrue);
  });

  test('不能删掉动作的最后一组', () async {
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026),
        exercises: [
          TrainingExercise(
            exerciseId: 1,
            name: '深蹲',
            sets: [
              TrainingSet(setNumber: 1, clientUuid: 's1'),
              TrainingSet(setNumber: 2, clientUuid: 's2'),
            ],
          ),
        ],
      ),
    );

    notifier.removeSet(1, 2);
    expect(notifier.state.value!.exercises.first.sets, hasLength(1));
    notifier.removeSet(1, 1);
    expect(notifier.state.value!.exercises.first.sets, hasLength(1));
  });

  test('同一时间只展开一个动作；再点当前可收起', () async {
    TrainingExercise ex(int id, String name) => TrainingExercise(
      exerciseId: id,
      name: name,
      sets: [TrainingSet(setNumber: 1, clientUuid: 's$id')],
    );

    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026),
        exercises: [ex(1, '卧推'), ex(2, '深蹲'), ex(3, '硬拉')],
        focusedExerciseId: 1,
      ),
    );

    notifier.focusExercise(2);
    expect(notifier.state.value!.focusedExerciseId, 2);

    notifier.toggleExerciseExpanded(3);
    expect(notifier.state.value!.focusedExerciseId, 3);

    notifier.toggleExerciseExpanded(3);
    expect(notifier.state.value!.focusedExerciseId, isNull);

    notifier.focusExercise(2);
    notifier.removeExercise(2);
    expect(notifier.state.value!.focusedExerciseId, 3);
  });

  test('勾完一个动作的最后一组后收起它，并展开下一个未完成动作', () {
    TrainingSet open(String id) => TrainingSet(setNumber: 1, clientUuid: id);
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026),
        focusedExerciseId: 1,
        exercises: [
          TrainingExercise(
            exerciseId: 1,
            name: '卧推',
            sets: [
              TrainingSet(
                setNumber: 1,
                reps: 5,
                weightKg: 60,
                clientUuid: 'a1',
              ),
              TrainingSet(
                setNumber: 2,
                reps: 5,
                weightKg: 60,
                clientUuid: 'a2',
              ),
            ],
          ),
          TrainingExercise(exerciseId: 2, name: '深蹲', sets: [open('b1')]),
          TrainingExercise(exerciseId: 3, name: '硬拉', sets: [open('c1')]),
        ],
      ),
    );

    notifier.toggleSetDone(1, 1);
    expect(notifier.state.value!.focusedExerciseId, 1);

    notifier.toggleSetDone(1, 2);
    expect(notifier.state.value!.focusedExerciseId, 2);

    notifier.toggleSetDone(2, 1);
    expect(notifier.state.value!.focusedExerciseId, 3);

    notifier.toggleSetDone(3, 1);
    expect(notifier.state.value!.focusedExerciseId, isNull);
  });

  test('后面的动作都完成了，就回到前面还没做完的动作', () {
    TrainingSet done(String id) => TrainingSet(
      setNumber: 1,
      reps: 5,
      weightKg: 60,
      completedAt: DateTime.utc(2026, 1, 1),
      clientUuid: id,
    );
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026),
        focusedExerciseId: 2,
        exercises: [
          TrainingExercise(
            exerciseId: 1,
            name: '卧推',
            sets: [
              TrainingSet(
                setNumber: 1,
                reps: 5,
                weightKg: 60,
                clientUuid: 'a1',
              ),
            ],
          ),
          TrainingExercise(exerciseId: 2, name: '深蹲', sets: [done('b1')]),
          TrainingExercise(
            exerciseId: 3,
            name: '硬拉',
            sets: [
              TrainingSet(
                setNumber: 1,
                reps: 3,
                weightKg: 100,
                clientUuid: 'c1',
              ),
            ],
          ),
        ],
      ),
    );

    notifier.toggleSetDone(3, 1);
    expect(notifier.state.value!.focusedExerciseId, 1);
    expect(
      notifier.state.value!.exercises[1].sets.single.completedAt,
      isNotNull,
    );
  });

  ActiveTraining squatSession() => ActiveTraining(
    sessionId: 1,
    clientUuid: 'u',
    startedAt: DateTime.utc(2026),
    exercises: [
      TrainingExercise(
        exerciseId: 1,
        name: '杠铃深蹲',
        sets: [
          for (var i = 1; i <= 5; i++)
            TrainingSet(setNumber: i, clientUuid: 's$i'),
        ],
        ghostSets: const [
          GhostSet(setNumber: 1, reps: 8, weightKg: 100, rpe: 9.0),
        ],
        ghostSessionDate: DateTime(2026, 9, 3),
      ),
    ],
  );

  test('替换动作保留已填组并换身份', () async {
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026),
        focusedExerciseId: 1,
        exercises: [
          TrainingExercise(
            exerciseId: 1,
            name: '深蹲',
            notes: '腰带',
            restTargetSeconds: 150,
            weightUnit: 'lb',
            sets: [
              TrainingSet(
                setNumber: 1,
                reps: 5,
                weightKg: 100,
                clientUuid: 's1',
              ),
            ],
          ),
        ],
      ),
    );

    final ok = await notifier.replaceExercise(
      1,
      const Exercise(id: 2, name: '腿举', exerciseType: 'compound'),
    );
    expect(ok, isTrue);
    final ex = notifier.state.value!.exercises.single;
    expect(ex.exerciseId, 2);
    expect(ex.name, '腿举');
    expect(ex.sets.single.reps, 5);
    expect(ex.sets.single.weightKg, 100);
    expect(ex.notes, '腰带');
    expect(ex.restTargetSeconds, 150);
    expect(ex.weightUnit, 'lb');
    expect(notifier.state.value!.focusedExerciseId, 2);
  });

  test('新增动作时预填上次次数和重量', () async {
    repo.lastSets = LastSessionSets(
      sessionDate: DateTime(2026, 9, 3),
      sets: const [
        LastSessionSet(setNumber: 1, reps: 8, weightKg: 100, rpe: 8.0),
        LastSessionSet(setNumber: 2, reps: 6, weightKg: 102.5, rpe: 8.5),
      ],
    );
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026),
      ),
    );
    await notifier.addExercises(const [
      Exercise(id: 1, name: '杠铃深蹲', exerciseType: 'compound'),
    ]);

    final sets = notifier.state.value!.exercises.single.sets;
    expect(sets, hasLength(2));
    expect(sets[0].reps, 8);
    expect(sets[0].weightKg, 100);
    expect(sets[1].reps, 6);
    expect(sets[1].weightKg, 102.5);
  });

  test('RPE 8.0 完成本组后预填下一组建议重量 102.5kg', () {
    notifier.state = AsyncData(squatSession());
    notifier.updateSet(1, 1, reps: 8, weightKg: 100);
    final followUp = notifier.completeSetWithRpe(1, 1, 8.0);
    final sets = notifier.state.value!.exercises.first.sets;

    expect(sets[0].rpe, 8.0);
    expect(sets[0].completedAt, isNotNull);
    expect(followUp!.advice.suggestedWeightKg, 102.5);
    expect(sets[1].weightKg, 100);
    expect(sets[1].suggestedWeightKg, isNull);
    expect(notifier.state.value!.restBonusSeconds, 0);
  });

  test('勾完后再补记 RPE，不把下一组的开始时间推到现在', () {
    notifier.state = AsyncData(squatSession());
    notifier.updateSet(1, 1, reps: 8, weightKg: 100);
    notifier.toggleSetDone(1, 1);
    final started = notifier.state.value!.exercises.first.sets[1].startedAt;
    notifier.completeSetWithRpe(1, 1, 8.5);
    final sets = notifier.state.value!.exercises.first.sets;
    expect(sets[0].completedAt, isNotNull);
    expect(sets[0].rpe, 8.5);
    expect(sets[1].startedAt, started);
  });

  test('RPE 9.5 为组间休息加 60 秒', () {
    notifier.state = AsyncData(squatSession());
    notifier.updateSet(1, 1, reps: 8, weightKg: 100);
    final followUp = notifier.completeSetWithRpe(1, 1, 9.5);
    expect(followUp!.advice.extraRestSeconds, 60);
    expect(notifier.state.value!.restBonusSeconds, 60);
  });

  test('RPE 10 力竭且自动降重开启时立刻下调未完成组', () {
    notifier.state = AsyncData(squatSession());
    notifier.updateSet(1, 1, reps: 8, weightKg: 100);
    notifier.completeSetWithRpe(1, 1, 8.0);
    notifier.applySuggestedWeight(1, 2);
    notifier.updateSet(1, 2, reps: 8);
    notifier.completeSetWithRpe(1, 2, 8.0);
    notifier.updateSet(1, 3, reps: 8, weightKg: 102.5);
    final followUp = notifier.completeSetWithRpe(1, 3, 10.0);

    expect(followUp!.advice.fatigueWarning, isTrue);
    expect(followUp.autoReduced, isTrue);
    final sets = notifier.state.value!.exercises.first.sets;
    expect(sets[0].weightKg, 100);
    expect(sets[2].rpe, 10.0);
    expect(sets[2].weightKg, 102.5);
    expect(sets[3].weightKg, followUp.advice.suggestedWeightKg);
    expect(sets[4].weightKg, followUp.advice.suggestedWeightKg);
    expect(sets[3].weightKg, lessThan(102.5));
    expect(sets[3].weightKg, greaterThan(90));
  });

  test('关闭力竭自动降重后未完成组保持原重量', () async {
    await container
        .read(fatigueAutoReduceEnabledProvider.notifier)
        .setEnabled(false);
    notifier.state = AsyncData(squatSession());
    notifier.updateSet(1, 1, reps: 8, weightKg: 100);
    notifier.completeSetWithRpe(1, 1, 8.0);
    notifier.applySuggestedWeight(1, 2);
    notifier.updateSet(1, 2, reps: 8);
    notifier.completeSetWithRpe(1, 2, 8.0);
    notifier.updateSet(1, 3, reps: 8, weightKg: 102.5);
    final followUp = notifier.completeSetWithRpe(1, 3, 10.0);

    expect(followUp!.autoReduced, isFalse);
    final sets = notifier.state.value!.exercises.first.sets;
    expect(sets[3].weightKg, 102.5);
    expect(sets[4].weightKg, 102.5);
    expect(followUp.advice.message, isNotNull);
  });

  test('力竭只改不低于失败重量的正式组，更轻的递减组保持原重', () {
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026),
        exercises: [
          TrainingExercise(
            exerciseId: 1,
            name: '深蹲',
            sets: [
              TrainingSet(
                setNumber: 1,
                reps: 5,
                weightKg: 100,
                clientUuid: 's1',
              ),
              TrainingSet(
                setNumber: 2,
                reps: 5,
                weightKg: 100,
                clientUuid: 's2',
              ),
              TrainingSet(
                setNumber: 3,
                reps: 8,
                weightKg: 80,
                setKind: TrainingSetKind.drop,
                clientUuid: 's3',
              ),
              TrainingSet(
                setNumber: 4,
                reps: 5,
                weightKg: 90,
                clientUuid: 's4',
              ),
              TrainingSet(
                setNumber: 5,
                reps: 5,
                weightKg: 100,
                setKind: TrainingSetKind.cooldown,
                clientUuid: 's5',
              ),
            ],
          ),
        ],
      ),
    );

    final followUp = notifier.completeSetWithRpe(1, 1, 10);
    final sets = notifier.state.value!.exercises.first.sets;
    expect(followUp!.advice.suggestedWeightKg, isNotNull);
    expect(sets[1].weightKg, followUp.advice.suggestedWeightKg);
    expect(sets[2].weightKg, 80);
    expect(sets[3].weightKg, 90);
    expect(sets[4].weightKg, 100);
  });

  test('同一动作第二次力竭不再改未完成组', () {
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026),
        exercises: [
          TrainingExercise(
            exerciseId: 1,
            name: '深蹲',
            sets: [
              TrainingSet(
                setNumber: 1,
                reps: 5,
                weightKg: 100,
                clientUuid: 's1',
              ),
              TrainingSet(
                setNumber: 2,
                reps: 5,
                weightKg: 100,
                clientUuid: 's2',
              ),
              TrainingSet(
                setNumber: 3,
                reps: 5,
                weightKg: 100,
                clientUuid: 's3',
              ),
            ],
          ),
        ],
      ),
    );

    notifier.completeSetWithRpe(1, 1, 10);
    final afterFirst = notifier.state.value!.exercises.first.sets[2].weightKg;
    final followUp = notifier.completeSetWithRpe(1, 2, 10);
    final sets = notifier.state.value!.exercises.first.sets;
    expect(followUp!.advice.suggestedWeightKg, isNull);
    expect(followUp.autoReduced, isFalse);
    expect(followUp.advice.message, kFailureAgainMessage);
    expect(sets[2].weightKg, afterFirst);
  });

  test('结束训练时丢掉未完成组，已完成组按 1 起重编号', () async {
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026, 9, 11),
        exercises: [
          TrainingExercise(
            exerciseId: 1,
            name: '深蹲',
            sets: [
              TrainingSet(
                setNumber: 1,
                reps: 5,
                weightKg: 100,
                completedAt: DateTime.utc(2026, 9, 11, 10),
                clientUuid: 'done',
              ),
              TrainingSet(
                setNumber: 2,
                reps: 5,
                weightKg: 100,
                clientUuid: 'skip',
              ),
            ],
          ),
        ],
      ),
    );

    expect(await notifier.finish(), isTrue);
    final uploaded = repo.lastComplete!.sets;
    expect(uploaded, hasLength(1));
    expect(uploaded.single.clientUuid, 'done');
    expect(uploaded.single.setNumber, 1);
    expect(uploaded.single.completedAt, isNotNull);
  });

  test('徒手动作无历史时次数 8、重量留空以便显示自重', () async {
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026),
      ),
    );
    await notifier.addExercises(const [
      Exercise(id: 8, name: '俯卧撑', exerciseType: 'compound'),
    ]);

    final ex = notifier.state.value!.exercises.single;
    expect(ex.isBodyweight, isTrue);
    expect(ex.sets.single.reps, 8);
    expect(ex.sets.single.weightKg, isNull);
  });

  test('徒手动作有历史负重时不覆盖', () async {
    repo.lastSets = LastSessionSets(
      sessionDate: DateTime(2026, 9, 3),
      sets: const [LastSessionSet(setNumber: 1, reps: 8, weightKg: 20)],
    );
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026),
      ),
    );
    await notifier.addExercises(const [
      Exercise(id: 8, name: '俯卧撑', exerciseType: 'compound'),
    ]);

    expect(notifier.state.value!.exercises.single.sets.single.weightKg, 20);
  });

  test('器械动作没练过时默认 10kg × 8', () async {
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026),
      ),
    );
    await notifier.addExercises(const [
      Exercise(id: 1, name: '杠铃深蹲', exerciseType: 'compound', equipmentId: 1),
    ]);

    final ex = notifier.state.value!.exercises.single;
    expect(ex.isBodyweight, isFalse);
    expect(ex.sets.single.reps, 8);
    expect(ex.sets.single.weightKg, 10);
  });

  test('仅一组力竭后新增一组自动降重', () {
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026),
        exercises: [
          TrainingExercise(
            exerciseId: 1,
            name: '深蹲',
            sets: [
              TrainingSet(
                setNumber: 1,
                reps: 8,
                weightKg: 100,
                clientUuid: 's1',
              ),
            ],
          ),
        ],
      ),
    );

    notifier.completeSetWithRpe(1, 1, 10.0);
    notifier.addSet(1);
    final sets = notifier.state.value!.exercises.first.sets;
    expect(sets, hasLength(2));
    expect(sets.first.weightKg, 100);
    expect(sets.last.reps, 8);
    expect(sets.last.weightKg, lessThan(100));
    expect(sets.last.weightKg, greaterThan(90));
  });

  test('关闭力竭自动降重后新增一组保持原重量', () async {
    await container
        .read(fatigueAutoReduceEnabledProvider.notifier)
        .setEnabled(false);
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026),
        exercises: [
          TrainingExercise(
            exerciseId: 1,
            name: '深蹲',
            sets: [
              TrainingSet(
                setNumber: 1,
                reps: 8,
                weightKg: 100,
                clientUuid: 's1',
              ),
            ],
          ),
        ],
      ),
    );

    notifier.completeSetWithRpe(1, 1, 10.0);
    notifier.addSet(1);
    expect(notifier.state.value!.exercises.first.sets.last.weightKg, 100);
  });

  test('改当前组重量和次数时后续未完成同类型组跟随', () {
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026),
        exercises: [
          TrainingExercise(
            exerciseId: 1,
            name: '深蹲',
            sets: [
              TrainingSet(
                setNumber: 1,
                reps: 8,
                weightKg: 100,
                completedAt: DateTime.utc(2026),
                clientUuid: 's1',
              ),
              TrainingSet(
                setNumber: 2,
                reps: 8,
                weightKg: 100,
                clientUuid: 's2',
              ),
              TrainingSet(
                setNumber: 3,
                reps: 8,
                weightKg: 100,
                clientUuid: 's3',
              ),
              TrainingSet(
                setNumber: 4,
                reps: 8,
                weightKg: 80,
                setKind: TrainingSetKind.drop,
                clientUuid: 's4',
              ),
            ],
          ),
        ],
      ),
    );

    notifier.updateSet(1, 2, reps: 6, weightKg: 90);
    expect(setOf(1).reps, 8);
    expect(setOf(1).weightKg, 100);
    expect(setOf(2).reps, 6);
    expect(setOf(2).weightKg, 90);
    expect(setOf(3).reps, 6);
    expect(setOf(3).weightKg, 90);
    expect(setOf(4).reps, 8);
    expect(setOf(4).weightKg, 80);
  });

  test('自动更新带动同值的未完成组', () {
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026),
        exercises: [
          TrainingExercise(
            exerciseId: 1,
            name: '深蹲',
            sets: [
              TrainingSet(
                setNumber: 1,
                reps: 8,
                weightKg: 100,
                clientUuid: 's1',
              ),
              TrainingSet(
                setNumber: 2,
                reps: 8,
                weightKg: 100,
                clientUuid: 's2',
              ),
            ],
          ),
        ],
      ),
    );

    notifier.updateSet(1, 1, reps: 6, weightKg: 90, followRemaining: false, followMatching: true);
    expect(setOf(1).reps, 6);
    expect(setOf(1).weightKg, 90);
    expect(setOf(2).reps, 6);
    expect(setOf(2).weightKg, 90);
  });

  test('自动更新不覆盖已经改成别的数的组', () {
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026),
        exercises: [
          TrainingExercise(
            exerciseId: 1,
            name: '深蹲',
            sets: [
              TrainingSet(setNumber: 1, reps: 8, weightKg: 100, clientUuid: 's1'),
              TrainingSet(setNumber: 2, reps: 8, weightKg: 90, clientUuid: 's2'),
              TrainingSet(setNumber: 3, reps: 5, weightKg: 100, clientUuid: 's3'),
            ],
          ),
        ],
      ),
    );

    notifier.updateSet(1, 1, weightKg: 110, followRemaining: false, followMatching: true);
    expect(setOf(1).weightKg, 110);
    expect(setOf(2).weightKg, 90);
    expect(setOf(3).weightKg, 110);
    expect(setOf(3).reps, 5);
  });

  test('followRemaining 关闭且不自动跟随时只改当前组', () {
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026),
        exercises: [
          TrainingExercise(
            exerciseId: 1,
            name: '深蹲',
            sets: [
              TrainingSet(setNumber: 1, reps: 8, weightKg: 100, clientUuid: 's1'),
              TrainingSet(setNumber: 2, reps: 8, weightKg: 100, clientUuid: 's2'),
            ],
          ),
        ],
      ),
    );

    notifier.updateSet(1, 1, reps: 6, weightKg: 90, followRemaining: false);
    expect(setOf(1).reps, 6);
    expect(setOf(1).weightKg, 90);
    expect(setOf(2).reps, 8);
    expect(setOf(2).weightKg, 100);
  });

  test('所有组不改已完成组的次数和重量', () {
    final done = DateTime.utc(2026, 9, 1, 10);
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026),
        exercises: [
          TrainingExercise(
            exerciseId: 1,
            name: '深蹲',
            sets: [
              TrainingSet(
                setNumber: 1,
                reps: 8,
                weightKg: 100,
                completedAt: done,
                clientUuid: 's1',
              ),
              TrainingSet(
                setNumber: 2,
                reps: 8,
                weightKg: 100,
                clientUuid: 's2',
              ),
            ],
          ),
        ],
      ),
    );

    notifier.updateAllSets(1, reps: 5, weightKg: 80);
    expect(setOf(1).reps, 8);
    expect(setOf(1).weightKg, 100);
    expect(setOf(2).reps, 5);
    expect(setOf(2).weightKg, 80);
  });

  test('后加动作的第一组不从加入时刻累计整场时间', () {
    final sessionStart = DateTime.now().toUtc().subtract(
      const Duration(hours: 1),
    );
    final firstDone = DateTime.now().toUtc().subtract(
      const Duration(seconds: 80),
    );
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: sessionStart,
        exercises: [
          TrainingExercise(
            exerciseId: 1,
            name: '卧推',
            sets: [
              TrainingSet(
                setNumber: 1,
                reps: 8,
                completedAt: firstDone,
                startedAt: sessionStart,
                clientUuid: 's1',
              ),
            ],
          ),
          TrainingExercise(
            exerciseId: 2,
            name: '划船',
            sets: [
              TrainingSet(
                setNumber: 1,
                reps: 8,
                startedAt: sessionStart,
                clientUuid: 's2',
              ),
            ],
          ),
        ],
      ),
    );

    notifier.toggleSetDone(2, 1);
    final elapsed = notifier.state.value!.exercises[1].sets.single.restSeconds;
    expect(elapsed, inInclusiveRange(70, 100));
  });

  test('热身组完成不记 RPE，也不给后面的组建议重量', () {
    notifier.state = AsyncData(squatSession());
    notifier.updateSet(
      1,
      1,
      reps: 8,
      weightKg: 60,
      setKind: TrainingSetKind.warmup,
    );
    final followUp = notifier.completeSetWithRpe(1, 1, 9);
    final sets = notifier.state.value!.exercises.first.sets;
    expect(followUp, isNull);
    expect(sets.first.rpe, isNull);
    expect(sets.first.completedAt, isNotNull);
    expect(sets[1].suggestedWeightKg, isNull);
  });

  test('一次加入多个动作时只给当前这一个开表', () async {
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026),
      ),
    );
    await notifier.addExercises(const [
      Exercise(id: 1, name: '杠铃卧推', exerciseType: 'compound', equipmentId: 1),
      Exercise(id: 2, name: '杠铃划船', exerciseType: 'compound', equipmentId: 1),
    ]);
    final exercises = notifier.state.value!.exercises;
    expect(exercises.first.sets.single.startedAt, isNull);
    expect(exercises.last.sets.single.startedAt, isNotNull);
    expect(notifier.state.value!.focusedExerciseId, 2);
  });

  test('空会话一次加入建议动作时只给第一个动作开表，并跳过已有动作', () async {
    notifier.state = AsyncData(
      ActiveTraining(
        sessionId: 1,
        clientUuid: 'u',
        startedAt: DateTime.utc(2026),
      ),
    );
    final added = await notifier.addPlannedExercises([
      TrainingExercise(
        exerciseId: 1,
        name: '卧推',
        sets: [
          TrainingSet(
            setNumber: 1,
            reps: 8,
            weightKg: 80,
            clientUuid: 'pending',
          ),
          TrainingSet(
            setNumber: 2,
            reps: 8,
            weightKg: 80,
            clientUuid: 'pending',
          ),
        ],
      ),
      TrainingExercise(
        exerciseId: 2,
        name: '划船',
        sets: [
          TrainingSet(
            setNumber: 1,
            reps: 10,
            weightKg: 60,
            clientUuid: 'pending',
          ),
        ],
      ),
    ]);
    final exercises = notifier.state.value!.exercises;
    expect(added, 2);
    expect(exercises.map((item) => item.exerciseId), [1, 2]);
    expect(exercises.first.sets.first.startedAt, isNotNull);
    expect(exercises.first.sets.last.startedAt, isNull);
    expect(exercises.last.sets.single.startedAt, isNull);
    expect(exercises.first.sets.first.weightKg, 80);
    final uuids = [
      for (final exercise in exercises)
        for (final set in exercise.sets) set.clientUuid,
    ];
    expect(uuids.toSet(), hasLength(3));
    expect(uuids, isNot(contains('pending')));
    expect(notifier.state.value!.focusedExerciseId, 1);

    final again = await notifier.addPlannedExercises([
      TrainingExercise(
        exerciseId: 1,
        name: '卧推',
        sets: [
          TrainingSet(
            setNumber: 1,
            reps: 8,
            weightKg: 80,
            clientUuid: 'pending',
          ),
        ],
      ),
    ]);
    expect(again, 0);
    expect(notifier.state.value!.exercises, hasLength(2));
  });
}
