import 'package:app_flutter/features/templates/domain/entities/workout_template.dart';
import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:app_flutter/features/training/presentation/widgets/session_exercise_list.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('模板 JSON 解析封面、难度、超级组和肌群', () {
    final template = WorkoutTemplate.fromJson({
      'id': 3,
      'user_id': 1,
      'owner_username': 'ervin',
      'title': '推日',
      'description': '胸肩',
      'cover_url': 'https://example.com/cover.jpg',
      'difficulty': 'hard',
      'is_public': true,
      'exercise_count': 2,
      'set_count': 4,
      'completion_count': 7,
      'is_owner': true,
      'created_at': '2026-09-11T10:00:00Z',
      'updated_at': '2026-09-11T11:00:00Z',
      'primary_muscles': [
        {'name': '胸部', 'name_en': 'Chest', 'is_primary': true, 'set_count': 4},
      ],
      'equipment': [
        {'id': 1, 'name': '杠铃', 'name_en': 'Barbell'},
      ],
      'exercises': [
        {
          'id': 10,
          'exercise_id': 1,
          'name': '卧推',
          'superset_id': 9,
          'sets': [
            {'id': 1, 'set_number': 1, 'reps': 8, 'weight_kg': 60},
          ],
        },
        {
          'id': 11,
          'exercise_id': 2,
          'name': '飞鸟',
          'superset_id': 9,
          'sets': [
            {'id': 2, 'set_number': 1, 'reps': 12, 'weight_kg': 12},
          ],
        },
      ],
    });

    expect(template.title, '推日');
    expect(template.difficulty, TemplateDifficulty.hard);
    expect(template.difficulty.label, '高难度');
    expect(template.isPublic, isTrue);
    expect(template.coverUrl, contains('cover.jpg'));
    expect(template.primaryMuscles.single.name, '胸部');
    expect(template.equipment.single.name, '杠铃');
    expect(template.exercises.map((e) => e.supersetId), [9, 9]);
    expect(template.exercises.first.toTrainingExercise().sets.single.reps, 8);
  });

  test('连续相同 supersetId 收成超级组，单个标记不当成超级组', () {
    TrainingExercise ex(int id, {int? supersetId}) => TrainingExercise(
          exerciseId: id,
          name: '$id',
          supersetId: supersetId,
        );

    final blocks = groupExercises([
      ex(1, supersetId: 8),
      ex(2, supersetId: 8),
      ex(3),
      ex(4, supersetId: 9),
    ]);

    expect(blocks, hasLength(3));
    expect(blocks[0].isSuperset, isTrue);
    expect(blocks[0].exercises.map((e) => e.exerciseId), [1, 2]);
    expect(blocks[1].isSuperset, isFalse);
    expect(blocks[1].exercises.single.exerciseId, 3);
    expect(blocks[2].isSuperset, isFalse);
  });
}
