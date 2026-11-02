import 'package:intl/intl.dart';

/// 按用户区域格式化整数（计数 / 组数等），如 `1234567` → `1,234,567`。
final _countFormat = NumberFormat.decimalPattern();

String formatCount(int value) => _countFormat.format(value);

/// 字节数的可读展示，如 `1536` → `1.5 KB`、`2_097_152` → `2.0 MB`。
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = value >= 10 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}

final _kcalFormat = NumberFormat('#,##0');

/// 千卡展示，如 `1295` → `1,295 kcal`。
String formatKcal(num value) => '${_kcalFormat.format(value.round())} kcal';

/// 秒 → `m:ss` 休息时长显示，如 `150` → `2:30`；null → 空串。
String formatRestSeconds(int? seconds) {
  if (seconds == null) return '-';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// 秒 → `MM:SS` 计时显示，如 `150` → `02:30`（分钟补零，与训练计时钟一致）。
String formatMmSs(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// 训练时长，如 `1小时18分钟` / `36分钟`。
String formatSessionDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  if (hours > 0) {
    if (minutes == 0) return '$hours 小时';
    return '$hours 小时 $minutes 分钟';
  }
  if (minutes > 0) return '$minutes 分钟';
  return '${d.inSeconds} 秒';
}

/// 口语化时长，如 `4分钟6秒` / `1小时18分钟`。
String formatSpokenDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60);
  final seconds = d.inSeconds.remainder(60);
  if (hours > 0) {
    if (minutes == 0) return '$hours小时';
    return '$hours小时$minutes分钟';
  }
  if (minutes > 0) {
    if (seconds == 0) return '$minutes分钟';
    return '$minutes分钟$seconds秒';
  }
  return '$seconds秒';
}

/// 组间休息摘要，如 `组间平均 4分钟6秒 · 最长 8分钟`。
String formatRestSummary(List<int> restSeconds) {
  if (restSeconds.isEmpty) return '';
  String dur(int seconds) => formatSpokenDuration(Duration(seconds: seconds));
  if (restSeconds.length == 1) return '组间休息 ${dur(restSeconds.first)}';
  final avg = restSeconds.reduce((a, b) => a + b) ~/ restSeconds.length;
  final longest = restSeconds.reduce((a, b) => a > b ? a : b);
  return '组间平均 ${dur(avg)} · 最长 ${dur(longest)}';
}
