// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise_local_dao.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$exerciseLocalDaoHash() => r'f29c05dfa7ea20bfb88c83d1b1cc75a8c48911f1';

/// exercises 模块的本地数据访问对象。
///
/// 负责肌群 / 器械 / 动作 / 动作详情的本地读写与缓存。所有写操作由
/// [ExerciseRepository] 在「首次从后端拉取」时调用；读操作供 UI 直接使用。
///
/// Copied from [exerciseLocalDao].
@ProviderFor(exerciseLocalDao)
final exerciseLocalDaoProvider = Provider<ExerciseLocalDao>.internal(
  exerciseLocalDao,
  name: r'exerciseLocalDaoProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$exerciseLocalDaoHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ExerciseLocalDaoRef = ProviderRef<ExerciseLocalDao>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
