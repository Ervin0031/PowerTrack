import 'dart:convert';

import 'package:app_flutter/core/providers/dio_provider.dart';
import 'package:app_flutter/features/templates/domain/entities/workout_template.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final templateRepositoryProvider = Provider<TemplateRepository>((ref) {
  return TemplateRepository(ref.watch(dioProvider));
});

class TemplateRepository {
  TemplateRepository(this._dio);

  final Dio _dio;

  Future<TemplatePage> listTemplates({
    String? search,
    String? difficulty,
    int? muscleGroupId,
    int? equipmentId,
    bool? isPublic,
    String scope = 'all',
    int skip = 0,
    int limit = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/templates',
      queryParameters: {
        'skip': skip,
        'limit': limit,
        'scope': scope,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'difficulty': ?difficulty,
        'muscle_group_id': ?muscleGroupId,
        'equipment_id': ?equipmentId,
        'is_public': ?isPublic,
      },
    );
    final data = response.data;
    if (data == null) throw const FormatException('模板列表响应缺少数据');
    return TemplatePage.fromJson(data);
  }

  Future<WorkoutTemplate> getTemplate(int id) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/templates/$id');
    final data = response.data;
    if (data == null) throw const FormatException('模板详情响应缺少数据');
    return WorkoutTemplate.fromJson(data);
  }

  Future<WorkoutTemplate> saveTemplate({
    int? id,
    required Map<String, dynamic> payload,
    String? coverPath,
  }) async {
    final form = FormData.fromMap({
      'data': jsonEncode(payload),
      if (coverPath != null) 'image': await MultipartFile.fromFile(coverPath, filename: 'cover.jpg'),
    });
    final response = id == null
        ? await _dio.post<Map<String, dynamic>>('/api/v1/templates', data: form)
        : await _dio.put<Map<String, dynamic>>('/api/v1/templates/$id', data: form);
    final data = response.data;
    if (data == null) throw const FormatException('保存模板响应缺少数据');
    return WorkoutTemplate.fromJson(data);
  }

  Future<void> deleteTemplate(int id) async {
    await _dio.delete<void>('/api/v1/templates/$id');
  }

  Future<TemplateCompletionPage> listCompletions(int id, {int skip = 0, int limit = 20}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/templates/$id/completions',
      queryParameters: {'skip': skip, 'limit': limit},
    );
    final data = response.data;
    if (data == null) throw const FormatException('完成列表响应缺少数据');
    return TemplateCompletionPage.fromJson(data);
  }
}
