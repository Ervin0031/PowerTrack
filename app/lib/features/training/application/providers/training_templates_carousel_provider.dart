import 'package:app_flutter/features/templates/data/repositories/template_repository.dart';
import 'package:app_flutter/features/templates/domain/entities/workout_template.dart';
import 'package:app_flutter/features/training/application/providers/training_session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 训练首页模板轮播：轻量拉取前几条，不复用列表页的筛选/分页状态。
///
/// 不用 autoDispose：它挂在首页长列表底部，滚出视口就被释放、滚回又重建，
/// 会造成滚动时反复打接口。训练开始/结束时按 sessionId 变化刷新（与首页
/// 其他数据源一致），下拉刷新经 invalidate 重拉。
final trainingTemplatesCarouselProvider = FutureProvider<List<WorkoutTemplate>>((ref) async {
  ref.watch(trainingSessionProvider.select((async) => async.value?.sessionId));
  final page = await ref.read(templateRepositoryProvider).listTemplates(limit: 8);
  return page.items;
});
