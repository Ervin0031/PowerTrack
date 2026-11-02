// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rest_timer_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$restTimerSettingsHash() => r'd18eb3580b9fb1237b529407684cd50212066fa2';

/// 全局组间休息目标时长（秒）。
///
/// 每完成一组，底部的休息计时条按此目标计时：未到目标为正常色进度条，
/// 超过目标继续计时且进度条变红提示休息过头。
/// 持久化到 SharedPreferences，重启保持。
///
/// `null` 表示休息计时已关闭（计时条隐藏）；非 null 为开启的秒数。
///
/// Copied from [RestTimerSettings].
@ProviderFor(RestTimerSettings)
final restTimerSettingsProvider =
    NotifierProvider<RestTimerSettings, int?>.internal(
      RestTimerSettings.new,
      name: r'restTimerSettingsProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$restTimerSettingsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$RestTimerSettings = Notifier<int?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
