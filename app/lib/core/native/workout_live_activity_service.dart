import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:app_flutter/features/training/domain/bodyweight_load.dart';
import 'package:app_flutter/features/training/domain/entities/training_session.dart';
import 'package:app_flutter/features/training/domain/rpe.dart';
import 'package:app_flutter/features/training/domain/strength.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:live_activities/live_activities.dart';
import 'package:live_activities/models/alert_config.dart';
import 'package:live_activities/models/live_activity_file.dart';

/// 灵动岛负荷行，例如 `8 x 5 kg`。重量按动作单位从 kg 换算。
String workoutIslandLoadLabel({
  int? reps,
  double? weightKg,
  required bool isBodyweight,
  String weightUnit = 'kg',
}) {
  final hasWeight = weightKg != null && weightKg > 0;
  final weightText = hasWeight
      ? '${formatWeight(weightKg, unit: weightUnit)} ${weightUnitLabel(weightUnit)}'
      : (isBodyweight ? kBodyweightLoadLabel : null);
  if (weightText == null && reps == null) return '';
  if (weightText != null && reps != null) return '$reps x $weightText';
  if (weightText != null) return weightText;
  return '$reps 次';
}

/// 休息结束时灵动岛提示。空名字只写「开始下一组」。
String workoutIslandRestPrompt(String? exerciseName) {
  final name = exerciseName?.trim() ?? '';
  if (name.isEmpty || name == '训练进行中') return '开始下一组';
  return '开始下一组：$name';
}

/// 休息时前缀 `Next:`，与参考灵动岛一致；训练中直接显示当前组负荷。
String workoutIslandNextLine({
  required bool resting,
  required String loadLabel,
  required int currentSet,
  required int exerciseSets,
}) {
  if (resting) return loadLabel.isEmpty ? 'Next' : 'Next: $loadLabel';
  if (loadLabel.isNotEmpty) return loadLabel;
  if (exerciseSets >= 1 && currentSet >= 1) return '第 $currentSet/$exerciseSets 组';
  return '训练中';
}

/// App Group：必须与 iOS Runner / Widget Extension entitlements 一致。
const kLiveActivityAppGroupId = 'group.com.ervin.PowerTrack';

/// 训练 Live Activity / 灵动岛：开始训练启用，结束/放弃释放。
class WorkoutLiveActivityService with WidgetsBindingObserver {
  WorkoutLiveActivityService._();
  static final instance = WorkoutLiveActivityService._();

  /// 休息结束提示发出前取消本地通知，避免和灵动岛各响一次。
  Future<void> Function()? cancelOverlappingRestAlert;

  final _plugin = LiveActivities();
  final _restIsland = const MethodChannel('powertrack/rest_island');
  String? _activityId;
  var _inited = false;
  var _observing = false;
  var _backgrounded = false;
  String? _imageCacheUrl;
  Uint8List? _imageCacheBytes;
  String _exerciseName = '';
  DateTime? _restEndsAt;
  DateTime? _promptedFor;
  Timer? _restEndTimer;
  var _promptGeneration = 0;

  Future<void> _ensureInit() async {
    if (!Platform.isIOS) return;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    if (_inited) return;
    await _plugin.init(appGroupId: kLiveActivityAppGroupId);
    _inited = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _backgrounded = false;
      unawaited(_cancelBackgroundPrompt());
      return;
    }
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _backgrounded = true;
      unawaited(_scheduleBackgroundPrompt());
    }
  }

  Map<String, dynamic> _payload(ActiveTraining session, {int? globalRestSeconds}) {
    final exercises = session.exercises;
    final focused = session.focusedExerciseId == null
        ? null
        : exercises.where((e) => e.exerciseId == session.focusedExerciseId).firstOrNull;
    TrainingExercise? current = focused;
    if (current == null) {
      for (final e in exercises) {
        if (e.sets.any((s) => s.completedAt == null)) {
          current = e;
          break;
        }
      }
      current ??= exercises.isEmpty ? null : exercises.last;
    }

    final exercise = current;
    final exerciseSets = exercise?.sets.length ?? 0;
    final nextSet = exercise?.sets.where((s) => s.completedAt == null).firstOrNull;
    final currentSetNumber = nextSet?.setNumber ?? (exercise?.sets.length ?? 0);

    final restInfo = _restWindow(session, globalRestSeconds: globalRestSeconds);
    final resting = restInfo != null;

    return {
      'exerciseName': exercise?.name ?? '训练进行中',
      'nextLine': workoutIslandNextLine(
        resting: resting,
        loadLabel: workoutIslandLoadLabel(
          reps: nextSet?.reps,
          weightKg: nextSet?.weightKg,
          isBodyweight: exercise?.isBodyweight ?? false,
          weightUnit: exercise?.weightUnit ?? 'kg',
        ),
        currentSet: currentSetNumber,
        exerciseSets: exerciseSets,
      ),
      'phase': resting ? 'rest' : 'work',
      'exerciseImageUrl': exercise?.imageUrl ?? '',
      'exerciseImageId': exercise?.exerciseId ?? 0,
      'restEndsAtMs': restInfo?.endsAt.millisecondsSinceEpoch ?? 0,
      'restStartedAtMs': restInfo?.startedAt.millisecondsSinceEpoch ?? 0,
      'startedAtMs': session.startedAt.millisecondsSinceEpoch,
    };
  }

  /// 把动作图放进 App Group。灵动岛不能自己拉网络图。
  ///
  /// 签名链接会过期，优先用训练页已经缓存的文件，再缩成 120px 的 PNG。
  /// 原图有 2000px 以上，直接塞进岛里会解码失败。再大一点时，灵动岛归档会以
  /// 超过约 157pt 为由丢掉这一帧，顶部岛变成 notReady，锁屏还能留着上一帧。
  Future<LiveActivityFile?> _exerciseImage(String? url, int exerciseId) async {
    final value = url?.trim();
    if (value == null || value.isEmpty || exerciseId <= 0) return null;
    try {
      final bytes = await _thumbnailBytes(value);
      if (bytes == null) return null;
      return LiveActivityFileFromMemory.image(bytes, 'exercise_$exerciseId.png');
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _thumbnailBytes(String url) async {
    if (_imageCacheUrl == url && _imageCacheBytes != null) return _imageCacheBytes;
    final raw = await _rawImageBytes(url);
    if (raw == null) return null;
    final thumb = await _thumbnail(raw);
    if (thumb == null) return null;
    _imageCacheUrl = url;
    _imageCacheBytes = thumb;
    return thumb;
  }

  Future<Uint8List?> _rawImageBytes(String url) async {
    try {
      final cached = await DefaultCacheManager().getFileFromCache(url);
      final file = cached?.file;
      if (file != null && file.existsSync()) {
        final bytes = await file.readAsBytes();
        if (bytes.length >= 32) return bytes;
      }
    } catch (_) {}

    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) return null;
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 5));
      final response = await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
        if (builder.length > 4 * 1024 * 1024) return null;
      }
      final bytes = builder.takeBytes();
      if (bytes.length < 32) return null;
      return bytes;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<Uint8List?> _thumbnail(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 120);
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final out = data?.buffer.asUint8List();
        if (out == null || out.isEmpty) return null;
        return out;
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  Future<Map<String, dynamic>> _activityData(
    ActiveTraining session, {
    int? globalRestSeconds,
  }) async {
    final data = _payload(session, globalRestSeconds: globalRestSeconds);
    final url = data.remove('exerciseImageUrl') as String?;
    final exerciseId = data.remove('exerciseImageId') as int? ?? 0;
    final image = await _exerciseImage(url, exerciseId);
    if (image != null) data['exerciseImage'] = image;
    return data;
  }

  Future<void> _send(
    Map<String, dynamic> data,
    Future<void> Function(Map<String, dynamic> data) send,
  ) async {
    try {
      await send(data);
    } catch (_) {
      if (!data.containsKey('exerciseImage')) rethrow;
      await send(Map<String, dynamic>.from(data)..remove('exerciseImage'));
    }
  }

  /// 最近一次完成组后的休息窗口；已超时、已关闭或不在休息则返回 null。
  ///
  /// 与底部 [RestTimerBar] 对齐：全局休息关闭（[globalRestSeconds] 为 null）时
  /// 不进入休息态，避免灵动岛仍显示倒计时。
  ({DateTime startedAt, DateTime endsAt})? _restWindow(
    ActiveTraining session, {
    int? globalRestSeconds,
  }) {
    if (globalRestSeconds == null) return null;

    DateTime? latest;
    TrainingExercise? host;
    for (final e in session.exercises) {
      for (final s in e.sets) {
        final at = s.completedAt;
        if (at != null && (latest == null || at.isAfter(latest))) {
          latest = at;
          host = e;
        }
      }
    }
    if (latest == null || host == null) return null;
    final hasIncomplete = session.exercises.any((e) => e.sets.any((s) => s.completedAt == null));
    if (!hasIncomplete) return null;

    final target = (host.restTargetSeconds ?? globalRestSeconds) + session.restBonusSeconds;
    if (target <= 0) return null;
    final ends = latest.add(Duration(seconds: target));
    if (!DateTime.now().isBefore(ends)) return null;
    return (startedAt: latest, endsAt: ends);
  }

  /// 开始或恢复训练时调用。
  Future<void> start(ActiveTraining session, {int? globalRestSeconds}) async {
    if (!Platform.isIOS) return;
    try {
      await _ensureInit();
      final enabled = await _plugin.areActivitiesEnabled();
      if (!enabled) return;
      final data = await _activityData(session, globalRestSeconds: globalRestSeconds);
      if (_activityId != null) {
        await _send(data, (payload) => _plugin.updateActivity(_activityId!, payload));
      } else {
        await _plugin.endAllActivities();
        await _send(data, (payload) async {
          _activityId = await _plugin.createActivity(
            session.clientUuid,
            payload,
            removeWhenAppIsKilled: false,
            iOSEnableRemoteUpdates: false,
          );
        });
      }
      _noteRest(
        session,
        globalRestSeconds: globalRestSeconds,
        exerciseName: data['exerciseName'] as String? ?? '',
      );
    } catch (_) {
      // 灵动岛为增强体验，失败不打断训练
    }
  }

  /// 换动作 / 完成组时刷新展示。
  Future<void> update(ActiveTraining session, {int? globalRestSeconds}) async {
    if (!Platform.isIOS) return;
    try {
      await _ensureInit();
      if (_activityId == null) {
        await start(session, globalRestSeconds: globalRestSeconds);
        return;
      }
      final data = await _activityData(session, globalRestSeconds: globalRestSeconds);
      _noteRest(
        session,
        globalRestSeconds: globalRestSeconds,
        exerciseName: data['exerciseName'] as String? ?? '',
      );
      await _send(data, (payload) => _plugin.updateActivity(_activityId!, payload));
    } catch (_) {}
  }

  /// 结束或放弃训练时释放。
  Future<void> end() async {
    if (!Platform.isIOS) return;
    _restEndsAt = null;
    await _cancelBackgroundPrompt();
    try {
      await _ensureInit();
      if (_activityId != null) {
        await _plugin.endActivity(_activityId!);
      }
      await _plugin.endAllActivities();
    } catch (_) {
    } finally {
      _activityId = null;
    }
  }

  void _noteRest(
    ActiveTraining session, {
    int? globalRestSeconds,
    required String exerciseName,
  }) {
    final window = _restWindow(session, globalRestSeconds: globalRestSeconds);
    _exerciseName = exerciseName;
    if (window == null) {
      _restEndsAt = null;
      _promptedFor = null;
      unawaited(_cancelBackgroundPrompt());
      return;
    }
    if (_restEndsAt == window.endsAt) return;
    _restEndsAt = window.endsAt;
    _promptedFor = null;
    if (_backgrounded) unawaited(_scheduleBackgroundPrompt());
  }

  Future<void> _scheduleBackgroundPrompt() async {
    final ends = _restEndsAt;
    final activityId = _activityId;
    if (ends == null || activityId == null || _promptedFor == ends) return;
    final generation = ++_promptGeneration;
    _restEndTimer?.cancel();
    final delay = ends.difference(DateTime.now());
    if (delay < const Duration(milliseconds: 500)) {
      await _fireExpandedPrompt();
      return;
    }

    try {
      await _restIsland.invokeMethod<void>('hold');
    } catch (_) {}
    if (generation != _promptGeneration) return;
    _restEndTimer = Timer(delay, () {
      if (generation != _promptGeneration) return;
      unawaited(_fireExpandedPrompt());
    });
  }

  Future<void> _cancelBackgroundPrompt() async {
    _promptGeneration++;
    _restEndTimer?.cancel();
    _restEndTimer = null;
    try {
      await _restIsland.invokeMethod<void>('endHold');
    } catch (_) {}
  }

  /// 进程还在时用 Live Activity 提示把已有的岛展开。
  Future<void> _fireExpandedPrompt() async {
    final ends = _restEndsAt;
    final activityId = _activityId;
    if (ends == null || activityId == null || _promptedFor == ends) return;
    _promptedFor = ends;
    _restEndTimer?.cancel();
    _restEndTimer = null;
    try {
      await _restIsland.invokeMethod<void>('endHold');
    } catch (_) {}
    await cancelOverlappingRestAlert?.call();
    try {
      await _plugin.updateActivity(
        activityId,
        {'phase': 'ready'},
        alertConfig: AlertConfig(title: '休息结束', body: workoutIslandRestPrompt(_exerciseName)),
      );
    } catch (_) {}
  }
}
