import 'dart:io';

import 'package:flutter/services.dart';

/// 苹果健康读写（通过 Runner 原生 HealthKit MethodChannel）。
class AppleHealthService {
  AppleHealthService._();
  static final instance = AppleHealthService._();

  static const _channel = MethodChannel('powertrack/health');

  Future<bool> isAvailable() async {
    if (!Platform.isIOS) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('isAvailable');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestAuthorization() async {
    if (!Platform.isIOS) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('requestAuthorization');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<HealthDailySummary> fetchDailySummary() async {
    if (!Platform.isIOS) return const HealthDailySummary();
    try {
      final raw = await _channel.invokeMethod<Map>('fetchDailySummary');
      if (raw == null) return const HealthDailySummary();
      return HealthDailySummary(
        steps: (raw['steps'] as num?)?.toDouble(),
        activeEnergyKcal: (raw['activeEnergyKcal'] as num?)?.toDouble(),
        bodyMassKg: (raw['bodyMassKg'] as num?)?.toDouble(),
        restingHeartRate: (raw['restingHeartRate'] as num?)?.toDouble(),
      );
    } catch (_) {
      return const HealthDailySummary();
    }
  }

  Future<void> saveStrengthWorkout({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod('saveStrengthWorkout', {
        'startMs': start.millisecondsSinceEpoch,
        'endMs': end.millisecondsSinceEpoch,
      });
    } catch (_) {}
  }
}

class HealthDailySummary {
  const HealthDailySummary({
    this.steps,
    this.activeEnergyKcal,
    this.bodyMassKg,
    this.restingHeartRate,
  });

  final double? steps;
  final double? activeEnergyKcal;
  final double? bodyMassKg;
  final double? restingHeartRate;

  bool get hasAny =>
      steps != null || activeEnergyKcal != null || bodyMassKg != null || restingHeartRate != null;
}
