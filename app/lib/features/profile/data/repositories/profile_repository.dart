import 'package:app_flutter/core/providers/dio_provider.dart';
import 'package:app_flutter/features/profile/domain/entities/fitness_profile.dart';
import 'package:app_flutter/features/profile/domain/entities/weight_history.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 健身档案仓库。
final fitnessProfileRepositoryProvider = Provider<FitnessProfileRepository>(
  (ref) => FitnessProfileRepository(ref.watch(dioProvider)),
);

class FitnessProfileRepository {
  FitnessProfileRepository(this._dio);

  final Dio _dio;

  /// `GET /api/v1/users/me/profile`。未引导返回 null。
  Future<FitnessProfile?> fetch() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/users/me/profile');
    final data = response.data;
    if (data == null || data['complete'] != true) return null;
    final profile = data['profile'];
    if (profile is! Map<String, dynamic>) return null;
    return FitnessProfile.fromJson(profile);
  }

  /// `PUT /api/v1/users/me/profile`。
  Future<FitnessProfile> upsert(FitnessProfile profile) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/api/v1/users/me/profile',
      data: profile.toJson(),
    );
    final data = response.data;
    final raw = data?['profile'];
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('提交档案响应缺少数据');
    }
    return FitnessProfile.fromJson(raw);
  }

  /// `GET /api/v1/users/me/weight-history`。从未提交档案时返回空列表。
  Future<WeightHistory> fetchWeightHistory({int days = 90}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/users/me/weight-history',
      queryParameters: {'days': days},
    );
    final data = response.data;
    if (data == null) throw const FormatException('体重历史响应缺少数据');
    return WeightHistory.fromJson(data);
  }
}
