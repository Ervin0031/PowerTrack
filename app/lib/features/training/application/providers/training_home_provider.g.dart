// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'training_home_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$trainingHomeHash() => r'976425981ae057c9fb590af05d95716a196f1c21';

/// 训练首页统计：拉取近 12 周已完成会话并聚合。
///
/// 监听进行中会话 id，结束训练后自动刷新。
///
/// Copied from [trainingHome].
@ProviderFor(trainingHome)
final trainingHomeProvider =
    AutoDisposeFutureProvider<TrainingHomeStats>.internal(
      trainingHome,
      name: r'trainingHomeProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$trainingHomeHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TrainingHomeRef = AutoDisposeFutureProviderRef<TrainingHomeStats>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
