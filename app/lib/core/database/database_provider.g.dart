// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$databaseHash() => r'e641c468d93ebfa2727e85a0633a0bd758825877';

/// 应用级 SQLite 数据库 Provider。
///
/// `keepAlive: true`：作为基础设施依赖，生命周期跟随应用，整个进程共享同一
/// 打开的 [Database] 实例。
///
/// Copied from [database].
@ProviderFor(database)
final databaseProvider = FutureProvider<Database>.internal(
  database,
  name: r'databaseProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$databaseHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DatabaseRef = FutureProviderRef<Database>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
