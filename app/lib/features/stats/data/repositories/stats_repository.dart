import 'package:app_flutter/core/providers/dio_provider.dart';
import 'package:app_flutter/features/stats/domain/entities/stats_overview.dart';
import 'package:app_flutter/features/stats/domain/entities/strength_standards.dart';
import 'package:app_flutter/features/stats/domain/entities/volume_landmarks.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepository(ref.watch(dioProvider)),
);

class StatsRepository {
  StatsRepository(this._dio);

  final Dio _dio;

  /// `GET /api/v1/stats/overview?days=`
  Future<StatsOverview> getOverview({int days = 30}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/stats/overview',
      queryParameters: {'days': days},
    );
    final data = response.data;
    if (data == null) throw const FormatException('数据总览响应缺少数据');
    return StatsOverview.fromJson(data);
  }

  /// `GET /api/v1/volume/landmarks`：本周各肌群 hard set 数与 MEV/MAV/MRV 区间。
  Future<VolumeLandmarks> getVolumeLandmarks() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/volume/landmarks');
    final data = response.data;
    if (data == null) throw const FormatException('容量地标响应缺少数据');
    return VolumeLandmarks.fromJson(data);
  }

  /// `GET /api/v1/stats/strength-standards`：倍体重比、三大项、Dots/Wilks、推拉比。
  Future<StrengthStandards> getStrengthStandards() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/stats/strength-standards');
    final data = response.data;
    if (data == null) throw const FormatException('力量标准响应缺少数据');
    return StrengthStandards.fromJson(data);
  }
}
