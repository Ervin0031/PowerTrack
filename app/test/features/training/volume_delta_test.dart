import 'package:app_flutter/features/training/domain/volume_delta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('没有上一周或上周为 0 时不显示百分比', () {
    expect(weekVolumeDeltaPercent(previousWeek: null, thisWeek: 1000), isNull);
    expect(weekVolumeDeltaPercent(previousWeek: 0, thisWeek: 1000), isNull);
    expect(weekVolumeDeltaLabel(null), isNull);
  });

  test('上升、下降与持平', () {
    expect(weekVolumeDeltaPercent(previousWeek: 1000, thisWeek: 1120), 12);
    expect(weekVolumeDeltaLabel(12), '▲ 12%');
    expect(weekVolumeDeltaPercent(previousWeek: 1000, thisWeek: 920), -8);
    expect(weekVolumeDeltaLabel(-8), '▼ 8%');
    expect(weekVolumeDeltaPercent(previousWeek: 1000, thisWeek: 1000), 0);
    expect(weekVolumeDeltaLabel(0), '与上周持平');
  });
}
