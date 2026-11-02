import 'package:app_flutter/core/ui/format.dart';
import 'package:app_flutter/features/dynamic/domain/entities/feed_post.dart';
import 'package:app_flutter/features/dynamic/domain/entities/workout_feed_item.dart';
import 'package:app_flutter/features/dynamic/domain/workout_feed.dart';
import 'package:app_flutter/features/dynamic/presentation/widgets/workout_muscle_anatomy.dart';
import 'package:app_flutter/features/exercises/domain/entities/exercise.dart';
import 'package:app_flutter/features/profile/domain/entities/fitness_profile.dart';
import 'package:flutter_muscle_anatomy/flutter_muscle_anatomy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generateWorkoutTitle 用备注', () {
    expect(
      generateWorkoutTitle(startedAt: DateTime(2026, 9, 2, 20, 51), notes: '  推日  '),
      '推日',
    );
  });

  test('generateWorkoutTitle 按星期、时段和主肌群', () {
    expect(
      generateWorkoutTitle(
        startedAt: DateTime(2026, 9, 2, 20, 51),
        primaryMuscleNames: ['背阔肌', '斜方肌'],
      ),
      '周三晚间背阔肌与斜方肌专项训练',
    );
    expect(
      generateWorkoutTitle(startedAt: DateTime(2026, 9, 2, 8, 0), primaryMuscleNames: const []),
      '周三上午力量训练',
    );
  });

  test('estimateSessionKcal 用 MET 6', () {
    expect(estimateSessionKcal(duration: const Duration(hours: 1), weightKg: 70), 420);
    expect(estimateSessionKcal(duration: Duration.zero, weightKg: 70), 0);
  });

  test('restIntervalsSeconds 过滤过短和过长间隔', () {
    final t0 = DateTime(2026, 9, 2, 20, 0, 0);
    final gaps = restIntervalsSeconds([
      WorkoutSetRecord(id: 1, exerciseId: 1, setNumber: 1, completedAt: t0),
      WorkoutSetRecord(id: 2, exerciseId: 1, setNumber: 2, completedAt: t0.add(const Duration(seconds: 10))),
      WorkoutSetRecord(id: 3, exerciseId: 1, setNumber: 3, completedAt: t0.add(const Duration(seconds: 100))),
      WorkoutSetRecord(id: 4, exerciseId: 1, setNumber: 4, completedAt: t0.add(const Duration(minutes: 40))),
    ]);
    expect(gaps, [90]);
  });

  test('WorkoutSessionDetail.fromJson 解析组', () {
    final session = WorkoutSessionDetail.fromJson({
      'id': 12,
      'client_uuid': 'abc',
      'user_id': 3,
      'status': 'completed',
      'started_at': '2026-09-02T12:51:00Z',
      'completed_at': '2026-09-02T14:09:00Z',
      'notes': null,
      'sets': [
        {
          'id': 1,
          'exercise_id': 8,
          'set_number': 1,
          'reps': 8,
          'weight_kg': 85,
          'completed_at': '2026-09-02T13:00:00Z',
        },
      ],
    });
    expect(session.id, 12);
    expect(session.sets.single.volume, 680);
    expect(session.duration, const Duration(hours: 1, minutes: 18));
  });

  test('buildWorkoutFeedItem 聚合肌群、容量和标题', () {
    final started = DateTime(2026, 9, 2, 20, 51);
    final session = WorkoutSessionDetail(
      id: 1,
      clientUuid: 'u',
      userId: 1,
      status: 'completed',
      startedAt: started,
      completedAt: started.add(const Duration(hours: 1, minutes: 18)),
      sets: [
        WorkoutSetRecord(
          id: 1,
          exerciseId: 8,
          setNumber: 1,
          reps: 5,
          weightKg: 85,
          completedAt: started.add(const Duration(minutes: 10)),
        ),
        WorkoutSetRecord(
          id: 2,
          exerciseId: 8,
          setNumber: 2,
          reps: 5,
          weightKg: 80,
          completedAt: started.add(const Duration(minutes: 13)),
        ),
        WorkoutSetRecord(
          id: 3,
          exerciseId: 9,
          setNumber: 1,
          reps: 8,
          weightKg: 60,
          completedAt: started.add(const Duration(minutes: 20)),
        ),
      ],
    );
    final item = buildWorkoutFeedItem(
      session: session,
      exercises: {
        8: ExerciseDetail(
          id: 8,
          name: '引体向上',
          exerciseType: 'compound',
          primaryMuscleGroupId: 1,
          createdAt: DateTime(2026, 1, 1),
          primaryMuscleName: '背阔肌',
          primaryMuscleNameEn: 'Lats',
          secondaryMuscles: const [
            MuscleGroup(id: 2, name: '肱二头肌', nameEn: 'Biceps', category: 'upper'),
          ],
        ),
        9: ExerciseDetail(
          id: 9,
          name: '器械划船',
          exerciseType: 'compound',
          primaryMuscleGroupId: 3,
          createdAt: DateTime(2026, 1, 1),
          primaryMuscleName: '斜方肌',
          primaryMuscleNameEn: 'Traps',
        ),
      },
      bodyWeightKg: 70,
    );

    expect(item.title, '周三晚间背阔肌与斜方肌专项训练');
    expect(item.volumeKg, 85 * 5 + 80 * 5 + 60 * 8);
    expect(item.exercises.map((e) => e.name), ['引体向上', '器械划船']);
    expect(item.primaryMuscles.map((m) => m.name), ['背阔肌', '斜方肌']);
    expect(item.secondaryMuscles.single.name, '肱二头肌');
    expect(item.highlights.first.maxWeightKg, 85);
    expect(item.estimatedKcal, closeTo(6 * 70 * 78 / 60, 0.001));
    expect(item.restSeconds, [180, 420]);
    expect(item.exercises.first.sets, hasLength(2));
    expect(item.hardSetCount, 0);
    expect(item.averageRpe, isNull);
  });

  group('feedItemFromPost', () {
    FeedPost post({Map<String, dynamic>? highlights, String? caption, int userId = 7, int? sessionId = 3}) {
      return FeedPost.fromJson({
        'id': 1,
        'user_id': userId,
        'author_username': 'ervin',
        'session_id': sessionId,
        'caption': caption,
        'highlights': highlights,
        'created_at': '2026-09-02T12:00:00',
        'like_count': 2,
        'comment_count': 1,
        'liked_by_me': false,
      });
    }

    Map<String, dynamic> snapshot() => {
          'schema_version': 1,
          'session_id': 3,
          // 后端存 naive UTC，客户端按 +8 显示，故这里写 UTC 时刻。
          'started_at': '2026-09-02T12:51:00',
          'completed_at': '2026-09-02T14:09:00',
          'duration_seconds': 4680,
          'notes': null,
          'total_volume_kg': 5200.0,
          'hard_sets': 9,
          'total_sets': 14,
          'exercises_count': 4,
          'muscles': [
            {'name': '背阔肌', 'hard_sets': 5, 'volume': 2600.0},
            {'name': '斜方肌', 'hard_sets': 4, 'volume': 1300.0},
          ],
          'prs': [
            {
              'exercise_id': 11,
              'exercise_name': '高位下拉',
              'set_id': 91,
              'set_number': 3,
              'weight_kg': 85.0,
              'reps': 8,
              'rpe': 9.0,
              'estimated_1rm_kg': 107.7,
              'previous_best_kg': 104.0,
              'improvement_kg': 3.7,
            },
          ],
        };

    test('快照转卡片：肌群为主动作、PR 进 highlights，热量只算自己', () {
      final mine = feedItemFromPost(post(highlights: snapshot()), myUserId: 7, bodyWeightKg: 70)!;
      expect(mine.volumeKg, 5200);
      expect(mine.hardSetCount, 9);
      expect(mine.duration, const Duration(minutes: 78));
      expect(mine.primaryMuscles.map((m) => m.name), ['背阔肌', '斜方肌']);
      expect(mine.secondaryMuscles, isEmpty);
      expect(mine.highlights.single.name, '高位下拉');
      expect(mine.highlights.single.maxWeightKg, 85);
      expect(mine.title, '周三晚间背阔肌与斜方肌专项训练');
      expect(mine.estimatedKcal, closeTo(6 * 70 * 78 / 60, 0.001));

      final others = feedItemFromPost(post(highlights: snapshot()), myUserId: 999, bodyWeightKg: 70)!;
      expect(others.estimatedKcal, isNull, reason: '别人的体重算不出，不该用我的体重猜');
    });

    test('配文取代自动标题；无快照降级为 null', () {
      final withCaption = feedItemFromPost(post(highlights: snapshot(), caption: ' 拉背日 '), myUserId: 7);
      expect(withCaption!.title, '拉背日');

      expect(feedItemFromPost(post(highlights: null), myUserId: 7), isNull);
      final unknownSchema = snapshot()..['schema_version'] = 99;
      expect(feedItemFromPost(post(highlights: unknownSchema), myUserId: 7), isNull, reason: '不认识的快照版本宁可降级');
    });

    test('快照时间缺失时退回动态创建时间', () {
      final noStart = snapshot()..remove('started_at');
      final item = feedItemFromPost(post(highlights: noStart), myUserId: 7)!;
      expect(item.startedAt, post(highlights: noStart).createdAt);
    });
  });

  test('formatFeedTimestamp / formatSpokenDuration', () {
    expect(formatFeedTimestamp(DateTime(2026, 9, 2, 20, 51)), '2026年9月2日 下午 8:51');
    expect(formatSpokenDuration(const Duration(minutes: 4, seconds: 6)), '4分钟6秒');
    expect(formatRestSummary(const [20]), '组间休息 20秒');
    expect(formatRestSummary(const [120, 246]), '组间平均 3分钟3秒 · 最长 4分钟6秒');
  });

  test('hardSetCount / averageRpe / formatLoggedSet', () {
    final sets = [
      const WorkoutSetRecord(id: 1, exerciseId: 1, setNumber: 1, reps: 8, weightKg: 80, rpe: 7),
      const WorkoutSetRecord(id: 2, exerciseId: 1, setNumber: 2, reps: 6, weightKg: 85, rpe: 8.5),
      const WorkoutSetRecord(id: 3, exerciseId: 1, setNumber: 3, reps: 5, weightKg: 90, rpe: 9),
    ];
    expect(hardSetCount(sets), 2);
    expect(averageRpe(sets), closeTo(8.1666, 0.01));
    expect(formatLoggedSet(sets[1]), '85 kg × 6 次 · RPE 8.5');
    expect(formatIntensityLine(hardSets: 2, averageRpe: 8.5), '2 个有效组 · 平均 RPE 8.5');
  });

  test('vsLastFromHistory 跳过当前会话并取更早的一次', () {
    final now = DateTime(2026, 9, 2, 20);
    final vs = vsLastFromHistory(
      currentSessionId: 3,
      currentStartedAt: now,
      history: [
        WorkoutPreviousSession(
          sessionId: 3,
          startedAt: now,
          sets: const [WorkoutSetRecord(id: 1, exerciseId: 1, setNumber: 1, reps: 5, weightKg: 90)],
        ),
        WorkoutPreviousSession(
          sessionId: 2,
          startedAt: now.subtract(const Duration(days: 4)),
          sets: const [
            WorkoutSetRecord(id: 2, exerciseId: 1, setNumber: 1, reps: 8, weightKg: 80),
            WorkoutSetRecord(id: 3, exerciseId: 1, setNumber: 2, reps: 8, weightKg: 80),
          ],
        ),
        WorkoutPreviousSession(
          sessionId: 1,
          startedAt: now.subtract(const Duration(days: 20)),
          sets: const [WorkoutSetRecord(id: 4, exerciseId: 1, setNumber: 1, reps: 10, weightKg: 60)],
        ),
      ],
    );
    expect(vs, isNotNull);
    expect(vs!.previousVolume, 1280);
    expect(vs.previousMaxWeightKg, 80);
    expect(vs.previousRepsAtMax, 8);
    expect(formatVsLast(currentVolume: 1500, last: vs), '容量比上次 +220 kg');
    expect(formatPreviousTopSet(vs), '上次 80 kg × 8 次');
  });

  test('isFemaleAnatomy 仅女性用女模', () {
    expect(isFemaleAnatomy(FitnessGender.female), isTrue);
    expect(isFemaleAnatomy(FitnessGender.male), isFalse);
    expect(isFemaleAnatomy(FitnessGender.undisclosed), isFalse);
    expect(isFemaleAnatomy(null), isFalse);
  });

  test('musclesForHit 把胸部映射到胸大肌', () {
    const chest = WorkoutMuscleHit(name: '胸部', nameEn: 'Chest', isPrimary: true, setCount: 4, volume: 100);
    const chineseOnly = WorkoutMuscleHit(name: '胸部', nameEn: '', isPrimary: true, setCount: 4, volume: 100);
    expect(musclesForHit(chest), [Muscle.pectoralisMajor]);
    expect(musclesForHit(chineseOnly), [Muscle.pectoralisMajor]);
    expect(isChestHit(chest), isTrue);
  });

  test('musclesForHit 不把竖脊肌错映到斜方', () {
    const erector = WorkoutMuscleHit(
      name: '竖脊肌',
      nameEn: 'Erector Spinae',
      isPrimary: false,
      setCount: 4,
      volume: 50,
    );
    expect(musclesForHit(erector), isEmpty);
  });

  test('musclesForHit 股四头肌覆盖三块前侧大腿', () {
    const quads = WorkoutMuscleHit(
      name: '股四头肌',
      nameEn: 'Quadriceps',
      isPrimary: true,
      setCount: 5,
      volume: 200,
    );
    expect(
      musclesForHit(quads),
      [Muscle.rectusFemoris, Muscle.vastusMedialis, Muscle.vastusLateralis],
    );
  });
}
