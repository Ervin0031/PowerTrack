import 'package:app_flutter/core/network/api_datetime.dart';

/// 动态下的一条评论（纯 Dart，对应 `GET /feed/posts/{id}/comments`）。
///
/// [set] 仅在评论针对某一组时存在；该组被删后为 null。
class FeedComment {
  const FeedComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.authorUsername,
    required this.body,
    this.set,
    required this.createdAt,
  });

  factory FeedComment.fromJson(Map<String, dynamic> json) {
    final rawSet = json['set'];
    return FeedComment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      postId: (json['post_id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      authorUsername: json['author_username'] as String? ?? '',
      body: json['body'] as String? ?? '',
      set: rawSet is Map<String, dynamic> ? CommentSetRef.fromJson(rawSet) : null,
      createdAt: parseApiDateTimeOrNull(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final int id;
  final int postId;
  final int userId;
  final String authorUsername;
  final String body;
  final CommentSetRef? set;
  final DateTime createdAt;
}

/// 评论引用的某一组（`动作名 60kg × 8`）。
class CommentSetRef {
  const CommentSetRef({
    required this.setId,
    this.setNumber,
    this.exerciseName,
    this.weightKg,
    this.reps,
  });

  factory CommentSetRef.fromJson(Map<String, dynamic> json) {
    return CommentSetRef(
      setId: (json['set_id'] as num?)?.toInt() ?? 0,
      setNumber: (json['set_number'] as num?)?.toInt(),
      exerciseName: json['exercise_name'] as String?,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      reps: (json['reps'] as num?)?.toInt(),
    );
  }

  final int setId;
  final int? setNumber;
  final String? exerciseName;
  final double? weightKg;
  final int? reps;

  /// 一行文字摘要，如 `卧推 60 kg × 8`；信息不足时为空串。
  String get label {
    final parts = <String>[];
    if (weightKg != null && weightKg! > 0) {
      final kg = weightKg! % 1 == 0 ? weightKg!.toInt().toString() : weightKg!.toStringAsFixed(1);
      parts.add('$kg kg');
    }
    if (reps != null && reps! > 0) parts.add('$reps 次');
    final body = parts.join(' × ');
    final name = exerciseName?.trim() ?? '';
    if (name.isEmpty) return body;
    return body.isEmpty ? name : '$name $body';
  }
}
