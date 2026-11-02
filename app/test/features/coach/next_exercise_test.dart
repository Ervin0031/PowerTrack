import 'package:app_flutter/features/coach/domain/next_exercise.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const bench = NextLift(
    exerciseId: 1,
    name: '杠铃卧推',
    muscleGroupId: 1,
    muscleName: '胸部',
  );
  const incline = NextLift(
    exerciseId: 2,
    name: '上斜杠铃卧推',
    muscleGroupId: 1,
    muscleName: '胸部',
    imageUrl: 'https://cdn.test/incline.gif',
  );
  const squat = NextLift(
    exerciseId: 3,
    name: '杠铃深蹲',
    muscleGroupId: 2,
    muscleName: '股四头肌',
  );
  const fly = NextLift(
    exerciseId: 4,
    name: '哑铃飞鸟',
    muscleGroupId: 1,
    muscleName: '胸部',
  );

  test('接着上次这个动作后面的下一个，而不是别的部位', () {
    final choice = pickNextExercise(
      session: const [bench],
      focusedExerciseId: 1,
      recentSessions: const [
        [bench, incline, squat],
      ],
      catalog: const [squat, incline],
    );
    expect(choice?.lift.exerciseId, 2);
    expect(choice?.reason, contains('卧推'));
  });

  test('没有历史时只收同一类动作，不收动作库里排第一的别的部位', () {
    final choice = pickNextExercise(
      session: const [bench],
      focusedExerciseId: 1,
      recentSessions: const [],
      catalog: const [squat, incline],
    );
    expect(choice?.lift.exerciseId, 2);
  });

  test('动作库里没有同类动作时不随机推荐', () {
    final choice = pickNextExercise(
      session: const [bench],
      focusedExerciseId: 1,
      recentSessions: const [],
      catalog: const [squat],
    );
    expect(choice, isNull);
  });

  test('本场还没有动作时沿用最近一次训练的第一个', () {
    final choice = pickNextExercise(
      session: const [],
      recentSessions: const [
        [squat, bench],
      ],
      catalog: const [incline],
    );
    expect(choice?.lift.exerciseId, 3);
  });

  test('同一个动作已经在练时改推同肌群的下一个', () {
    final choice = pickNextExercise(
      session: const [bench, incline],
      focusedExerciseId: 1,
      recentSessions: const [
        [bench, incline, fly],
      ],
      catalog: const [],
    );
    expect(choice?.lift.exerciseId, 4);
  });

  test('换一个时跳过已经看过的动作', () {
    final choice = pickNextExercise(
      session: const [bench],
      focusedExerciseId: 1,
      recentSessions: const [
        [bench, incline, fly],
      ],
      catalog: const [incline, fly],
      excludeIds: const {2},
    );
    expect(choice?.lift.exerciseId, 4);
  });
}
