// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'training_session_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$trainingSessionHash() => r'707d052ea9c56937afca2f6b5c381ccd27839fcf';

/// 全局共享的训练会话状态。
///
/// 由 `@riverpod` 生成 `trainingSessionProvider`（keepAlive，与应用生命周期一致），
/// 跨页面跳转保持同一份进行中会话。
///
/// 状态为 `AsyncValue<ActiveTraining?>`：
/// - `AsyncData(null)`：当前无进行中会话（未开始 / 已结束）。
/// - `AsyncData(非null)`：进行中会话（新建或冷启动恢复）。
/// - `AsyncLoading`：恢复检查 / 创建 / 完成请求进行中。
/// - `AsyncError`：请求异常，由页面转成用户可读文案。
///
/// Copied from [TrainingSession].
@ProviderFor(TrainingSession)
final trainingSessionProvider =
    AsyncNotifierProvider<TrainingSession, ActiveTraining?>.internal(
      TrainingSession.new,
      name: r'trainingSessionProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$trainingSessionHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$TrainingSession = AsyncNotifier<ActiveTraining?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
