import 'package:app_flutter/core/network/api_datetime.dart';

/// 训练会话摘要实体（纯 Dart）。
///
/// 对应后端列表项 `SessionResponse`，供首页统计与历史列表复用。
class SessionRecord {
  const SessionRecord({
    required this.id,
    required this.clientUuid,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.notes,
  });

  factory SessionRecord.fromJson(Map<String, dynamic> json) {
    return SessionRecord(
      id: json['id'] as int,
      clientUuid: json['client_uuid'] as String,
      status: json['status'] as String,
      startedAt: parseApiDateTime(json['started_at'] as String),
      completedAt: parseApiDateTimeOrNull(json['completed_at']),
      notes: json['notes'] as String?,
    );
  }

  final int id;
  final String clientUuid;
  final String status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? notes;

  /// 已完成会话的时长；进行中或无结束时间时为 null。
  Duration? get duration {
    final end = completedAt;
    if (end == null) return null;
    final d = end.difference(startedAt);
    return d.isNegative ? Duration.zero : d;
  }
}
