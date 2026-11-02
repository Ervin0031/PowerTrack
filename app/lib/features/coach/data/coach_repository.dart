import 'package:app_flutter/features/coach/domain/coach_proposal.dart';
import 'package:app_flutter/features/coach/domain/coach_thought.dart';
import 'package:app_flutter/features/coach/domain/coach_thread.dart';
import 'package:dio/dio.dart';

/// 教练会话接口。推理在客户端完成，这里只读写对话记录。
class CoachRepository {
  CoachRepository(this._dio);

  final Dio _dio;

  Future<int> createThread() async {
    final response = await _dio.post<Map<String, dynamic>>('/api/v1/coach/threads');
    final id = response.data?['id'];
    if (id is! num) {
      throw StateError('教练没有返回对话');
    }
    return id.toInt();
  }

  Future<List<CoachThreadSummary>> listThreads() async {
    final response = await _dio.get<dynamic>('/api/v1/coach/threads');
    final data = response.data;
    if (data is! List) return const [];
    return [
      for (final item in data)
        if (item is Map<String, dynamic>)
          CoachThreadSummary.fromJson(item)
        else if (item is Map)
          CoachThreadSummary.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<CoachThreadDetail> fetchThread(int id) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/coach/threads/$id');
    return CoachThreadDetail.fromJson(response.data ?? const {});
  }

  /// 把客户端已经生成的一轮对话写回服务端，不触发模型推理。
  Future<void> importTurn({
    required int threadId,
    required String userContent,
    required String assistantContent,
    CoachProposal? proposal,
    List<CoachThoughtStep> trace = const [],
  }) async {
    await _dio.post<void>(
      '/api/v1/coach/threads/$threadId/messages/import',
      data: {
        'user_content': userContent,
        'assistant_content': assistantContent,
        if (proposal != null) 'proposal': proposal.toJson(),
        'trace': [for (final step in trace) step.toJson()],
      },
    );
  }
}
