// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_set_edit_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$activeSetEditNotifierHash() =>
    r'543a2bf65a17c5545eb3977e2706c47d5e708cd1';

/// 当前聚焦编辑的组字段；无聚焦时返回 null。
///
/// Copied from [ActiveSetEditNotifier].
@ProviderFor(ActiveSetEditNotifier)
final activeSetEditNotifierProvider =
    NotifierProvider<ActiveSetEditNotifier, ActiveSetEdit?>.internal(
      ActiveSetEditNotifier.new,
      name: r'activeSetEditNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$activeSetEditNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ActiveSetEditNotifier = Notifier<ActiveSetEdit?>;
String _$autoUpdateHash() => r'c1d668c0f1b0e22deb408e2830bc5725573d315e';

/// 输入即写入开关：开（默认）时每次按键直接写入；关时需点「完成」或菜单项才生效。
///
/// Copied from [AutoUpdate].
@ProviderFor(AutoUpdate)
final autoUpdateProvider = NotifierProvider<AutoUpdate, bool>.internal(
  AutoUpdate.new,
  name: r'autoUpdateProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$autoUpdateHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AutoUpdate = Notifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
