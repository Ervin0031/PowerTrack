import 'package:app_flutter/core/network/api_datetime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('naive ISO is treated as UTC', () {
    final dt = parseApiDateTime('2026-09-12T14:00:00');
    expect(dt.isUtc, isTrue);
    expect(dt.hour, 14);
    // 中国 UTC+8 → 本地 22:00
    final local = dt.toLocal();
    expect(local.timeZoneOffset, isNot(Duration.zero)); // skip if runner is UTC
    if (local.timeZoneOffset == const Duration(hours: 8)) {
      expect(local.hour, 22);
    }
  });

  test('Z suffix stays UTC', () {
    final dt = parseApiDateTime('2026-09-12T14:00:00.000Z');
    expect(dt.isUtc, isTrue);
    expect(dt.hour, 14);
  });

  test('date-only is not tagged as naive datetime', () {
    expect(isNaiveApiDateTime('2026-09-12'), isFalse);
    expect(isNaiveApiDateTime('2026-09-12T14:00:00'), isTrue);
  });

  test('tagNaiveUtcInJson patches nested maps', () {
    final tagged = tagNaiveUtcInJson({
      'started_at': '2026-09-12T14:00:00',
      'week_start': '2026-09-08',
      'items': [
        {'at': '2026-09-12T22:00:00.123'},
      ],
    });
    expect(tagged['started_at'], '2026-09-12T14:00:00Z');
    expect(tagged['week_start'], '2026-09-08');
    expect(tagged['items'][0]['at'], '2026-09-12T22:00:00.123Z');
  });
}
