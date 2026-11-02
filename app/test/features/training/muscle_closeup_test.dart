import 'package:app_flutter/features/dynamic/presentation/widgets/workout_muscle_anatomy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('肌群特写能画在卡片尺寸里', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 168,
          height: 180,
          child: Column(
            children: [
              Expanded(child: MuscleGroupCloseup(female: false, name: '胸部', nameEn: 'Chest')),
              Expanded(child: MuscleGroupCloseup(female: true, name: '背阔肌', nameEn: 'Lats')),
              Expanded(child: MuscleGroupCloseup(female: false, name: '股四头肌', nameEn: 'Quads')),
              Expanded(child: MuscleGroupCloseup(female: false, name: '竖脊肌', nameEn: 'Erector Spinae')),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(MuscleGroupCloseup), findsNWidgets(4));
  });
}
