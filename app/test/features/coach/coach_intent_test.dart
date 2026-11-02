import 'package:app_flutter/features/coach/domain/coach_intent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('排课优先于同一句话里的恢复', () {
    final intent = readCoachIntent('按恢复排今天这一堂');
    expect(intent.kind, CoachIntent.plan);
  });

  test('复盘、恢复、健康和闲聊分开', () {
    expect(readCoachIntent('给我分析最近训练数据').kind, CoachIntent.analysis);
    expect(readCoachIntent('看看我的肌群恢复').kind, CoachIntent.recovery);
    expect(readCoachIntent('今天适不适合加量').kind, CoachIntent.health);
    expect(readCoachIntent('卧推怎么发力').kind, CoachIntent.chat);
  });
}
