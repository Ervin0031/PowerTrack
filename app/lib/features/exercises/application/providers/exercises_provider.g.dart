// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercises_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$exerciseDetailHash() => r'c39486c4914eae8d7bdce9c03f7a2cc8ae15864b';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// 按动作 ID 获取详情：`GET /api/v1/exercises/{id}`。
///
/// Copied from [exerciseDetail].
@ProviderFor(exerciseDetail)
const exerciseDetailProvider = ExerciseDetailFamily();

/// 按动作 ID 获取详情：`GET /api/v1/exercises/{id}`。
///
/// Copied from [exerciseDetail].
class ExerciseDetailFamily extends Family<AsyncValue<ExerciseDetail>> {
  /// 按动作 ID 获取详情：`GET /api/v1/exercises/{id}`。
  ///
  /// Copied from [exerciseDetail].
  const ExerciseDetailFamily();

  /// 按动作 ID 获取详情：`GET /api/v1/exercises/{id}`。
  ///
  /// Copied from [exerciseDetail].
  ExerciseDetailProvider call(int id) {
    return ExerciseDetailProvider(id);
  }

  @override
  ExerciseDetailProvider getProviderOverride(
    covariant ExerciseDetailProvider provider,
  ) {
    return call(provider.id);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'exerciseDetailProvider';
}

/// 按动作 ID 获取详情：`GET /api/v1/exercises/{id}`。
///
/// Copied from [exerciseDetail].
class ExerciseDetailProvider extends AutoDisposeFutureProvider<ExerciseDetail> {
  /// 按动作 ID 获取详情：`GET /api/v1/exercises/{id}`。
  ///
  /// Copied from [exerciseDetail].
  ExerciseDetailProvider(int id)
    : this._internal(
        (ref) => exerciseDetail(ref as ExerciseDetailRef, id),
        from: exerciseDetailProvider,
        name: r'exerciseDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$exerciseDetailHash,
        dependencies: ExerciseDetailFamily._dependencies,
        allTransitiveDependencies:
            ExerciseDetailFamily._allTransitiveDependencies,
        id: id,
      );

  ExerciseDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final int id;

  @override
  Override overrideWith(
    FutureOr<ExerciseDetail> Function(ExerciseDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ExerciseDetailProvider._internal(
        (ref) => create(ref as ExerciseDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<ExerciseDetail> createElement() {
    return _ExerciseDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ExerciseDetailProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ExerciseDetailRef on AutoDisposeFutureProviderRef<ExerciseDetail> {
  /// The parameter `id` of this provider.
  int get id;
}

class _ExerciseDetailProviderElement
    extends AutoDisposeFutureProviderElement<ExerciseDetail>
    with ExerciseDetailRef {
  _ExerciseDetailProviderElement(super.provider);

  @override
  int get id => (origin as ExerciseDetailProvider).id;
}

String _$exercisesControllerHash() =>
    r'b62e2054097202c205906b44a218753ba5c6955c';

/// 动作列表控制器（分页 + 筛选联动）。
///
/// `build` 监听 [exercisesFilterProvider]，筛选条件变化即重置并重新拉取第一页；
/// [loadMore] 在现有列表末尾追加下一页，供滚动到底部时调用。
///
/// Copied from [ExercisesController].
@ProviderFor(ExercisesController)
final exercisesControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      ExercisesController,
      ExercisesPageState
    >.internal(
      ExercisesController.new,
      name: r'exercisesControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$exercisesControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ExercisesController = AutoDisposeAsyncNotifier<ExercisesPageState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
