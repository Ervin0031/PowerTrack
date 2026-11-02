import 'package:app_flutter/core/providers/dio_provider.dart';
import 'package:app_flutter/core/network/api_datetime.dart';
import 'package:app_flutter/features/training/domain/entities/exercise_stats.dart';
import 'package:app_flutter/features/training/domain/entities/muscle_group_status.dart';
import 'package:app_flutter/features/training/domain/entities/one_rm.dart';
import 'package:app_flutter/features/training/domain/entities/session_record.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/session_models.dart';

part 'session_repository.g.dart';

/// [SessionRepository] 组装 Provider。
///
/// 与 Repository 同文件维护，由 `@riverpod` 生成 `sessionRepositoryProvider`。
@Riverpod(keepAlive: true)
SessionRepository sessionRepository(Ref ref) {
  return SessionRepository(ref.watch(dioProvider));
}

/// 训练会话数据仓库：负责会话的创建与完成上传。
///
/// 只做「网络请求 + 响应解析」，不涉及 UI 与状态管理；
/// 依赖（[Dio]）由上方 Provider 注入。鉴权由全局拦截器自动附带。
class SessionRepository {
  SessionRepository(this._dio);

  final Dio _dio;

  /// 创建训练会话：`POST /api/v1/sessions`。
  ///
  /// 轻量创建（仅需 clientUuid + 开始时间），返回后端生成的会话 id。
  /// 同 UUID 重复请求幂等返回已有记录。
  Future<int> createSession(SessionCreate body, {int? templateId}) async {
    final payload = {
      ...body.toJson(),
      if (templateId != null) 'templateId': templateId,
    };
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/sessions',
      data: payload,
    );
    final data = response.data;
    if (data == null) throw const FormatException('创建会话响应缺少数据');
    final id = data['id'];
    if (id is! int) throw const FormatException('创建会话响应缺少 id');
    return id;
  }

  /// 完成训练：`PUT /api/v1/sessions/{id}/complete`。
  ///
  /// 批量上传完整数据（会话信息 + 所有组），整体在一个数据库事务中写入。
  /// 每个组按 clientUuid 幂等。返回后端写入后的会话 id 列表（此处仅确认成功）。
  ///
  /// 网络类失败会自动重试（见 [_withRetry]）：后端按 clientUuid 幂等，重放安全，
  /// 而这次失败意味着整场训练卡在本地，值得多试几次。
  Future<void> completeSession(int sessionId, SessionComplete body, {int? templateId}) async {
    final payload = {
      ...body.toJson(),
      if (templateId != null) 'templateId': templateId,
    };
    await _withRetry(() async {
      final response = await _dio.put<Map<String, dynamic>>(
        '/api/v1/sessions/$sessionId/complete',
        data: payload,
      );
      if (response.statusCode != 200) {
        throw const FormatException('完成训练失败');
      }
    });
  }

  /// 重试等待时长：共重试 3 次（首次尝试不计），给弱网和瞬时抖动留足恢复时间。
  static const _retryDelays = [
    Duration(milliseconds: 250),
    Duration(seconds: 1),
    Duration(seconds: 3),
  ];

  /// 只对「重试可能有用」的失败重试：连接失败、超时、5xx。
  /// 4xx 是请求本身的问题，重试多少次都一样，直接抛。
  Future<T> _withRetry<T>(Future<T> Function() action) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await action();
      } on DioException catch (error) {
        if (attempt >= _retryDelays.length || !_isTransient(error)) rethrow;
        await Future<void>.delayed(_retryDelays[attempt]);
      }
    }
  }

  bool _isTransient(DioException error) {
    final status = error.response?.statusCode;
    if (status != null) return status >= 500;
    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        true,
      _ => false,
    };
  }

  /// 查询进行中的会话：`GET /api/v1/sessions/in-progress`。
  ///
  /// App 冷启动恢复用；无进行中会话（404）时返回 null。
  Future<InProgressSession?> getInProgressSession() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/sessions/in-progress',
      // 无进行中会话时后端返回 404，属预期结果，放行避免抛异常。
      options: Options(validateStatus: (code) => code == 200 || code == 404),
    );
    final data = response.data;
    if (response.statusCode == 404 || data == null) return null;
    return InProgressSession.fromJson(data);
  }

  /// 删除训练会话：`DELETE /api/v1/sessions/{id}`。
  Future<void> deleteSession(int sessionId) async {
    await _dio.delete<void>('/api/v1/sessions/$sessionId');
  }

  /// 分页获取训练历史：`GET /api/v1/sessions`。
  ///
  /// 响应字段为 snake_case；[status] 传 `completed` / `in_progress`。
  Future<SessionListPage> listSessions({
    int skip = 0,
    int limit = 50,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/sessions',
      queryParameters: <String, dynamic>{
        'skip': skip,
        'limit': limit,
        'status': ?status,
        'start_date': ?startDate?.toUtc().toIso8601String(),
        'end_date': ?endDate?.toUtc().toIso8601String(),
      },
    );
    final data = response.data;
    if (data == null) throw const FormatException('训练历史响应缺少数据');
    final rawItems = data['items'] as List<dynamic>? ?? const [];
    return SessionListPage(
      items: rawItems
          .map((e) => SessionRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (data['total'] as num?)?.toInt() ?? rawItems.length,
    );
  }

  /// 获取某动作最近一次训练记录：`GET /api/v1/exercises/{exId}/last-performance`。
  ///
  /// 用于训练中参考上次表现；无记录时返回 null。
  Future<LastPerformance?> getLastPerformance(int exId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/exercises/$exId/last-performance',
    );
    final data = response.data;
    if (data == null) return null;
    return LastPerformance.fromJson(data);
  }

  /// 获取某动作最近一次已完成训练的全部组：`GET /api/v1/exercises/{exId}/last-session-sets`。
  ///
  /// 训练中把动作加入当前列表时预填上次重量/次数/时长/距离；无历史（404）返回 null。
  Future<LastSessionSets?> getLastSessionSets(int exId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/exercises/$exId/last-session-sets',
      // 无训练历史时后端返回 404，属预期结果，放行避免抛异常。
      options: Options(validateStatus: (code) => code == 200 || code == 404),
    );
    final data = response.data;
    if (response.statusCode == 404 || data == null) return null;
    return LastSessionSets.fromJson(data);
  }

  /// 近 8 周容量：`GET /api/v1/volume/weekly`。
  Future<WeeklyVolumeSummary> getWeeklyVolume() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/volume/weekly');
    final data = response.data;
    if (data == null) throw const FormatException('容量响应缺少数据');
    return WeeklyVolumeSummary.fromJson(data);
  }

  /// 动作数据图表：`GET /api/v1/exercises/{exId}/stats`。
  Future<ExerciseStats> getExerciseStats(int exId, {int days = 30}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/exercises/$exId/stats',
      queryParameters: {'days': days},
    );
    final data = response.data;
    if (data == null) throw const FormatException('动作统计响应缺少数据');
    return ExerciseStats.fromJson(data);
  }

  /// 动作估算 1RM：`GET /api/v1/exercises/{exId}/one-rm`。
  ///
  /// 无该动作的估算（404）返回 null。
  Future<OneRmEstimate?> getOneRm(int exId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/exercises/$exId/one-rm',
      // 暂无 1RM 估算时后端返回 404，属预期结果，放行避免抛异常。
      options: Options(validateStatus: (code) => code == 200 || code == 404),
    );
    final data = response.data;
    if (response.statusCode == 404 || data == null) return null;
    return OneRmEstimate.fromJson(data);
  }

  /// 由历史组反推的 1RM 时间序列：`GET /api/v1/exercises/{exId}/one-rm/history`。
  Future<List<OneRmPoint>> getOneRmHistory(int exId, {int limit = 50}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/exercises/$exId/one-rm/history',
      queryParameters: {'limit': limit},
    );
    final data = response.data;
    if (data == null) return const [];
    return (data['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(OneRmPoint.fromJson)
        .toList();
  }

  /// 训练详情：`GET /api/v1/sessions/{id}`。
  Future<Map<String, dynamic>> getSessionDetail(int sessionId) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/sessions/$sessionId');
    final data = response.data;
    if (data == null) throw const FormatException('训练详情响应缺少数据');
    return data;
  }

  /// 肌群恢复状态：`GET /api/v1/muscle-groups/status`。
  Future<MuscleGroupStatusSummary> getMuscleGroupStatus() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/muscle-groups/status');
    final data = response.data;
    if (data == null) throw const FormatException('肌群状态响应缺少数据');
    return MuscleGroupStatusSummary.fromJson(data);
  }
}

/// 训练历史分页结果。
class SessionListPage {
  const SessionListPage({required this.items, required this.total});

  final List<SessionRecord> items;
  final int total;
}

/// 进行中的训练会话（冷启动恢复用，仅取恢复所需字段）。
class InProgressSession {
  const InProgressSession({
    required this.id,
    required this.clientUuid,
    required this.startedAt,
  });

  factory InProgressSession.fromJson(Map<String, dynamic> json) {
    return InProgressSession(
      id: json['id'] as int,
      clientUuid: json['client_uuid'] as String,
      startedAt: parseApiDateTime(json['started_at'] as String),
    );
  }

  /// 后端生成的会话 id。
  final int id;

  /// 创建时的客户端 UUID（结束训练上传时须原样带回）。
  final String clientUuid;

  /// 训练开始时间（恢复计时用）。
  final DateTime startedAt;
}

/// 上一次训练记录（轻量、非 freezed，仅用于本地展示）。
class LastPerformance {
  const LastPerformance({this.reps, this.weightKg, this.completedAt, this.rpe});

  factory LastPerformance.fromJson(Map<String, dynamic> json) {
    final rawWeight = json['weight_kg'];
    final rawRpe = json['rpe'];
    return LastPerformance(
      reps: json['reps'] as int?,
      weightKg: rawWeight is num ? rawWeight.toDouble() : null,
      completedAt: parseApiDateTimeOrNull(json['completed_at']),
      rpe: rawRpe is num ? rawRpe.toDouble() : null,
    );
  }

  final int? reps;
  final double? weightKg;
  final DateTime? completedAt;
  final double? rpe;
}

/// 某动作最近一次已完成训练的全部组（预填用）。
class LastSessionSets {
  const LastSessionSets({required this.sessionDate, required this.sets});

  factory LastSessionSets.fromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'] as List<dynamic>? ?? const [];
    return LastSessionSets(
      sessionDate: parseApiDateTimeOrNull(json['session_date']),
      sets: rawSets
          .map((e) => LastSessionSet.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final DateTime? sessionDate;
  final List<LastSessionSet> sets;
}

/// 最近一次训练中的单个组（仅保留预填所需的字段）。
class LastSessionSet {
  const LastSessionSet({
    required this.setNumber,
    this.reps,
    this.weightKg,
    this.durationSeconds,
    this.distanceMeters,
    this.rpe,
  });

  factory LastSessionSet.fromJson(Map<String, dynamic> json) {
    final rawWeight = json['weight_kg'];
    final rawDistance = json['distance_meters'];
    final rawRpe = json['rpe'];
    return LastSessionSet(
      setNumber: json['set_number'] as int,
      reps: json['reps'] as int?,
      weightKg: rawWeight is num ? rawWeight.toDouble() : null,
      durationSeconds: json['duration_seconds'] as int?,
      distanceMeters: rawDistance is num ? rawDistance.toDouble() : null,
      rpe: rawRpe is num ? rawRpe.toDouble() : null,
    );
  }

  final int setNumber;
  final int? reps;
  final double? weightKg;
  final int? durationSeconds;
  final double? distanceMeters;
  final double? rpe;
}

class MuscleVolume {
  const MuscleVolume({required this.name, required this.volume, required this.hardSets});

  factory MuscleVolume.fromJson(Map<String, dynamic> json) => MuscleVolume(
        name: json['name'] as String? ?? '',
        volume: (json['volume'] as num?)?.toDouble() ?? 0,
        hardSets: (json['hard_sets'] as num?)?.toInt() ?? 0,
      );

  final String name;
  final double volume;
  final int hardSets;
}

class WeekVolume {
  const WeekVolume({
    required this.weekStart,
    required this.volume,
    required this.hardVolume,
    required this.hardSets,
    this.avgRpe,
    this.byMuscle = const [],
  });

  factory WeekVolume.fromJson(Map<String, dynamic> json) => WeekVolume(
        weekStart: json['week_start'] as String? ?? '',
        volume: (json['volume'] as num?)?.toDouble() ?? 0,
        hardVolume: (json['hard_volume'] as num?)?.toDouble() ?? 0,
        hardSets: (json['hard_sets'] as num?)?.toInt() ?? 0,
        avgRpe: (json['avg_rpe'] as num?)?.toDouble(),
        byMuscle: (json['by_muscle'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(MuscleVolume.fromJson)
            .toList(),
      );

  final String weekStart;
  final double volume;
  final double hardVolume;
  final int hardSets;
  final double? avgRpe;
  final List<MuscleVolume> byMuscle;
}

class WeeklyVolumeSummary {
  const WeeklyVolumeSummary({
    required this.weeks,
    required this.suggestDeload,
    this.deloadReason,
  });

  factory WeeklyVolumeSummary.fromJson(Map<String, dynamic> json) => WeeklyVolumeSummary(
        weeks: (json['weeks'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(WeekVolume.fromJson)
            .toList(),
        suggestDeload: json['suggest_deload'] == true,
        deloadReason: json['deload_reason'] as String?,
      );

  final List<WeekVolume> weeks;
  final bool suggestDeload;
  final String? deloadReason;

  WeekVolume? get thisWeek => weeks.isEmpty ? null : weeks.last;
}
