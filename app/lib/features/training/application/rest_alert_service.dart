import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 组间休息结束提醒：系统本地通知（后台）+ 前台音效/震动。
///
/// 不用 AlarmKit（仅 iOS 26+、需 Widget Extension）；本地通知是 Strong / Hevy
/// 同类 App 的常见做法，锁屏与后台均可响。
class RestAlertService {
  RestAlertService._();
  static final RestAlertService instance = RestAlertService._();

  static const _notificationId = 42001;
  static const _channelId = 'rest_timer';
  static const _channelName = '休息闹钟';
  static const _channelDesc = '组间休息结束时提醒开始下一组';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _tzReady = false;

  Future<void> ensureInitialized() async {
    if (_ready) return;
    if (!_tzReady) {
      tzdata.initializeTimeZones();
      _tzReady = true;
    }

    const android = AndroidInitializationSettings('ic_stat_rest');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: true,
      defaultPresentSound: true,
      defaultPresentBadge: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
    _ready = true;
  }

  /// 请求通知 / 精确闹钟权限；返回是否已允许通知。
  Future<bool> requestPermissions() async {
    await ensureInitialized();
    if (kIsWeb) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final notif = await android?.requestNotificationsPermission() ?? false;
      await android?.requestExactAlarmsPermission();
      return notif;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, badge: false, sound: true) ?? false;
    }
    return false;
  }

  /// 当前系统是否已允许通知（不弹窗）。
  Future<bool> areNotificationsEnabled() async {
    await ensureInitialized();
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final opts = await ios?.checkPermissions();
      return opts?.isEnabled ?? false;
    }
    return false;
  }

  /// 在 [endsAt] 触发「休息结束」通知；若时间已过则立即提醒。
  Future<void> scheduleRestEnd({
    required DateTime endsAt,
    String? exerciseName,
  }) async {
    await ensureInitialized();
    await cancel();

    const title = '休息结束';
    final body = exerciseName == null || exerciseName.isEmpty ? '可以开始下一组了' : '下一组：$exerciseName';
    final details = _details(title: title, body: body);

    final now = DateTime.now();
    if (!endsAt.isAfter(now.add(const Duration(milliseconds: 400)))) {
      await _fireNow(title: title, body: body, details: details);
      return;
    }

    final when = tz.TZDateTime.from(endsAt.toUtc(), tz.UTC);
    try {
      await _plugin.zonedSchedule(
        id: _notificationId,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      try {
        await _plugin.zonedSchedule(
          id: _notificationId,
          title: title,
          body: body,
          scheduledDate: when,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e, st) {
        debugPrint('RestAlertService.scheduleRestEnd failed: $e\n$st');
      }
    }
  }

  /// 前台倒计时到 0：取消待发通知，改用系统音效 + 震动，避免重复弹通知。
  Future<void> notifyForegroundRestEnded() async {
    await cancel();
    await SystemSound.play(SystemSoundType.alert);
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.mediumImpact();
  }

  Future<void> cancel() async {
    if (!_ready) {
      try {
        await ensureInitialized();
      } catch (_) {
        return;
      }
    }
    try {
      await _plugin.cancel(id: _notificationId);
    } catch (_) {}
  }

  Future<void> _fireNow({
    required String title,
    required String body,
    required NotificationDetails details,
  }) async {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
      await SystemSound.play(SystemSoundType.alert);
      await HapticFeedback.heavyImpact();
      return;
    }
    await _plugin.show(
      id: _notificationId,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  NotificationDetails _details({required String title, required String body}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
        icon: 'ic_stat_rest',
        ticker: title,
        styleInformation: BigTextStyleInformation(body, contentTitle: title),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }
}
