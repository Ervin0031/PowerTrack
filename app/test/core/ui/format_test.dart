import 'package:app_flutter/core/ui/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatBytes', () {
    test('小于 1 KB 显示字节', () {
      expect(formatBytes(512), '512 B');
    });

    test('KB / MB 保留合适小数', () {
      expect(formatBytes(1536), '1.5 KB');
      expect(formatBytes(2 * 1024 * 1024), '2.0 MB');
    });
  });
}
