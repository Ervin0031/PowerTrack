import 'package:app_flutter/features/coach/domain/coach_proposal.dart';
import 'package:app_flutter/features/coach/domain/coach_thought.dart';

class CoachThreadSummary {
  const CoachThreadSummary({required this.id, required this.title});

  final int id;
  final String title;

  factory CoachThreadSummary.fromJson(Map<String, dynamic> json) {
    return CoachThreadSummary(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '新对话',
    );
  }
}

class CoachStoredMessage {
  const CoachStoredMessage({required this.role, required this.text, this.proposal, this.trace = const []});

  final String role;
  final String text;
  final CoachProposal? proposal;
  final List<CoachThoughtStep> trace;

  factory CoachStoredMessage.fromJson(Map<String, dynamic> json) {
    final raw = json['proposal'];
    final trace = json['trace'];
    return CoachStoredMessage(
      role: json['role'] as String? ?? 'assistant',
      text: json['content'] as String? ?? '',
      proposal: raw is Map<String, dynamic> ? CoachProposal.fromJson(raw) : null,
      trace: trace is List
          ? [
              for (final item in trace)
                if (item is Map<String, dynamic>) CoachThoughtStep.fromJson(item),
            ]
          : const [],
    );
  }
}

class CoachThreadDetail {
  const CoachThreadDetail({required this.id, required this.title, required this.messages});

  final int id;
  final String title;
  final List<CoachStoredMessage> messages;

  factory CoachThreadDetail.fromJson(Map<String, dynamic> json) {
    final raw = json['messages'];
    return CoachThreadDetail(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '新对话',
      messages: raw is List
          ? [
              for (final item in raw)
                if (item is Map<String, dynamic>) CoachStoredMessage.fromJson(item),
            ]
          : const [],
    );
  }

  CoachProposal? get proposal {
    for (final message in messages.reversed) {
      if (message.proposal != null) return message.proposal;
    }
    return null;
  }
}
