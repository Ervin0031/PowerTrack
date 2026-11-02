// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'training_session_local_dao.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$trainingSessionLocalDaoHash() =>
    r'425987ae75bcecefa96cebdf940ee70e81c54172';

/// 训练会话模块的本地数据访问对象。
///
/// 将进行中会话（含全部动作与组）整体序列化为单行 JSON 缓存到 SQLite，
/// 保证离线可用、冷启动可恢复。会话结束或放弃时清除。
///
/// Copied from [trainingSessionLocalDao].
@ProviderFor(trainingSessionLocalDao)
final trainingSessionLocalDaoProvider =
    Provider<TrainingSessionLocalDao>.internal(
      trainingSessionLocalDao,
      name: r'trainingSessionLocalDaoProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$trainingSessionLocalDaoHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TrainingSessionLocalDaoRef = ProviderRef<TrainingSessionLocalDao>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
