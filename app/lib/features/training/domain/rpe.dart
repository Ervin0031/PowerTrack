/// RPE 自动调节规则（与后端 `app/services/rpe.py` 保持一致）。
///
/// 纯 Dart，零 Flutter / Riverpod 依赖。
library;

/// 配重片最小步进（kg）。
const double kPlateStepKg = 2.5;

/// 红区阈值：额外休息 60 秒。
const double kRpeRedZone = 9.5;

/// 彻底力竭。
const double kRpeFailure = 10.0;

/// 甜蜜区下限。
const double kRpeSweetMin = 8.0;

const int kExtraRestSeconds = 60;

/// 没记次数时的力竭降幅：复合 5%，孤立 7.5%。
const double kCompoundFailureFactor = 0.95;
const double kIsolationFailureFactor = 0.925;

const String kRestMessage = '极限力竭，休息 +60s';
const String kFailureAgainMessage = '已经力竭过，后面的组可以不做';

/// 力竭后下一组的具体重量。
String failureNextMessage(double kg, {String unit = 'kg'}) =>
    '力竭了，下一组 ${formatWeight(kg, unit: unit)}$unit';

/// 连续顶在红区时，下一组少一片。
String redRepeatMessage(double kg, {String unit = 'kg'}) =>
    '连续顶到极限，下一组 ${formatWeight(kg, unit: unit)}$unit';

/// 四舍五入到最近配重片。
double roundToPlate(double kg, {double step = kPlateStepKg}) {
  if (step <= 0) return kg;
  return (kg / step + 1e-9).round() * step;
}

/// 夹到 0.5–10.0，并对齐到 0.5 步进。
double normalizeRpe(double rpe) {
  final clamped = rpe.clamp(0.5, 10.0);
  return (clamped * 2).round() / 2;
}

/// 重量展示：先四舍五入到 0.1kg，整数不带小数（102.5 → `102.5`，14.306… → `14.3`）。
String formatWeightKg(double kg) {
  final rounded = (kg * 10).roundToDouble() / 10;
  if (rounded == rounded.roundToDouble()) return rounded.round().toString();
  return rounded.toStringAsFixed(1);
}

/// 按单位展示重量数值（不含单位后缀）。
String formatWeight(double kg, {String unit = 'kg'}) {
  if (unit == 'lb') return formatWeightKg(kg * 2.2046226218);
  return formatWeightKg(kg);
}

/// RPE 展示始终一位小数（`8.0` / `9.5`）。
String formatRpe(double rpe) => normalizeRpe(rpe).toStringAsFixed(1);

/// 幽灵行日期前缀：一周内用「上周」，否则「上次」。
String ghostDatePrefix(DateTime? sessionDate, {DateTime? now}) {
  if (sessionDate == null) return '上次';
  final days = (now ?? DateTime.now()).difference(sessionDate.toLocal()).inDays;
  if (days <= 13 && days >= 4) return '上周';
  return '上次';
}

/// 幽灵模式文案，如 `上周：100kg × 8下 (RPE 9.0)`。空数据返回 null。
String? ghostLine({
  DateTime? sessionDate,
  double? weightKg,
  int? reps,
  double? rpe,
  DateTime? now,
  String unit = 'kg',
}) {
  final parts = <String>[];
  if (weightKg != null) parts.add('${formatWeight(weightKg, unit: unit)}$unit');
  if (reps != null) parts.add('$reps下');
  var body = parts.join(' × ');
  if (rpe != null) {
    final tag = 'RPE ${formatRpe(rpe)}';
    body = body.isEmpty ? '($tag)' : '$body ($tag)';
  }
  if (body.isEmpty) return null;
  return '${ghostDatePrefix(sessionDate, now: now)}：$body';
}

const double kCompoundSweetFactor = 1.015;
const double kIsolationSweetFactor = 1.025;
const double kLightFactor = 1.075;
const double kRpeSweetBandMin = 7.0;
const double kRpeSweetBandMax = 8.5;

const String kReasonFailure = '力竭，同次数降到目标余力';
const String kReasonFailureAgain = '已经力竭过，不再降重';
const String kReasonRed = '红区，保持重量 + 60s';
const String kReasonRedRepeat = '连续红区，再降一片';
const String kReasonRising = '连续升 RPE，锁定重量';
const String kReasonCapped = '已到目标区上限，不再加码';
const String kReasonIsolation = '孤立动作，甜区微加';
const String kReasonCompound = '复合动作，甜区微加';
const String kReasonTable = '无 1RM 锚点，按 RPE 表';
const String kReasonHold = '接近极限，保持重量';

/// 完成本组后的自动调节建议。
class RpeAdvice {
  const RpeAdvice({
    this.suggestedWeightKg,
    this.extraRestSeconds = 0,
    this.fatigueWarning = false,
    this.reduceRemainingFactor,
    this.message,
    this.reason,
    this.cappedBy1rm = false,
    this.zone,
  });

  final double? suggestedWeightKg;
  final int extraRestSeconds;
  final bool fatigueWarning;
  final double? reduceRemainingFactor;
  final String? message;
  final String? reason;
  final bool cappedBy1rm;
  final List<double>? zone;
}

/// 交给 UI 的一次性后续动作（SnackBar / 休息加时）。
class RpeFollowUp {
  const RpeFollowUp({
    required this.exerciseId,
    required this.setNumber,
    required this.advice,
    this.autoReduced = false,
  });

  final int exerciseId;
  final int setNumber;
  final RpeAdvice advice;

  /// 已按设置自动下调未完成组重量。
  final bool autoReduced;
}

List<double>? rpeZoneForGoal(String? goal) {
  switch (goal) {
    case 'performance':
      return const [0.85, 0.95];
    case 'muscle_gain':
    case 'hypertrophy':
      return const [0.65, 0.80];
    case 'reshape':
    case 'both':
      return const [0.75, 0.85];
    default:
      return null;
  }
}

const _rpe10Pct = <double>[
  0,
  100.0,
  95.5,
  92.2,
  89.2,
  86.3,
  83.7,
  81.1,
  78.6,
  76.2,
  73.9,
  71.9,
  69.9,
];

double _rpe10Percent(double reps) {
  if (reps <= 1) return 100;
  if (reps >= 12) return _rpe10Pct[12];
  final lo = reps.floor();
  final t = reps - lo;
  return _rpe10Pct[lo] * (1 - t) + _rpe10Pct[lo + 1] * t;
}

/// 次数 + RPE → 该组占 1RM 的百分比。等效次数 = 次数 + (10 − RPE)。
double? percent1rm(int reps, double rpe) {
  if (reps < 1 || reps > 20) return null;
  if (rpe < 6 || rpe > 10) return null;
  return _rpe10Percent(reps + (10 - rpe));
}

/// 增肌留到 RPE 8，力量留到 RPE 9。其余目标跟增肌。
double targetRpeForGoal(String? goal) => goal == 'performance' ? 9.0 : 8.0;

bool _alreadyAt(List<double> prior, double threshold) {
  for (final rpe in prior) {
    if (normalizeRpe(rpe) >= threshold) return true;
  }
  return false;
}

/// 对齐配重片，并且至少比本组少一片，避免四舍五入后回到原重量。
double? _atLeastOnePlateDown(double weightKg, double raw) {
  var next = roundToPlate(raw);
  if (next >= weightKg - 1e-9) {
    next = roundToPlate(weightKg - kPlateStepKg);
  }
  if (next <= 0 || next >= weightKg - 1e-9) return null;
  return next;
}

double? _failureWeight({
  required double weightKg,
  required int? reps,
  required String exerciseType,
  required String? goal,
}) {
  final isolation = exerciseType == 'isolation';
  final fallback =
      weightKg * (isolation ? kIsolationFailureFactor : kCompoundFailureFactor);
  if (reps == null || reps < 1) return _atLeastOnePlateDown(weightKg, fallback);
  final from = percent1rm(reps, kRpeFailure);
  final to = percent1rm(reps, targetRpeForGoal(goal));
  if (from == null || to == null || from <= 0) {
    return _atLeastOnePlateDown(weightKg, fallback);
  }
  return _atLeastOnePlateDown(weightKg, weightKg * to / from);
}

double? _dropFactor(double weightKg, double? next) {
  if (next == null || weightKg <= 0 || next >= weightKg) return null;
  return ((weightKg - next) / weightKg * 10000).round() / 10000;
}

bool _risingRpes(List<double> prior, double current) {
  if (prior.length < 2) return false;
  final series = [...prior.map(normalizeRpe), current];
  for (var i = 0; i < series.length - 1; i++) {
    if (series[i] >= series[i + 1]) return false;
  }
  return true;
}

(double, String) _tableCandidate(
  double weightKg,
  double rpe,
  String exerciseType,
) {
  final isolation = exerciseType == 'isolation';
  if (rpe >= 9.0) return (weightKg, kReasonHold);
  if (rpe >= kRpeSweetBandMin && rpe <= kRpeSweetBandMax) {
    if (isolation) {
      return (roundToPlate(weightKg * kIsolationSweetFactor), kReasonIsolation);
    }
    return (roundToPlate(weightKg * kCompoundSweetFactor), kReasonCompound);
  }
  return (roundToPlate(weightKg * kLightFactor), kReasonTable);
}

/// 根据本组重量与 RPE 给出下一组建议。
RpeAdvice recommendNextSet({
  required double weightKg,
  required double rpe,
  int? reps,
  double? oneRmKg,
  String exerciseType = 'compound',
  List<double> priorRpes = const [],
  List<double>? targetZone,
  String? goal,
  String unit = 'kg',
}) {
  final normalized = normalizeRpe(rpe);
  final kind = exerciseType == 'isolation' ? 'isolation' : 'compound';
  final zone = targetZone ?? rpeZoneForGoal(goal);
  if (weightKg <= 0) return RpeAdvice(zone: zone);

  if (normalized >= kRpeFailure) {
    if (_alreadyAt(priorRpes, kRpeFailure)) {
      return RpeAdvice(
        extraRestSeconds: kExtraRestSeconds,
        fatigueWarning: true,
        message: kFailureAgainMessage,
        reason: kReasonFailureAgain,
        zone: zone,
      );
    }
    final next = _failureWeight(
      weightKg: weightKg,
      reps: reps,
      exerciseType: kind,
      goal: goal,
    );
    return RpeAdvice(
      suggestedWeightKg: next,
      extraRestSeconds: kExtraRestSeconds,
      fatigueWarning: true,
      reduceRemainingFactor: _dropFactor(weightKg, next),
      message: next == null
          ? kFailureAgainMessage
          : failureNextMessage(next, unit: unit),
      reason: kReasonFailure,
      zone: zone,
    );
  }
  if (normalized >= kRpeRedZone) {
    if (_alreadyAt(priorRpes, kRpeRedZone)) {
      final next = _atLeastOnePlateDown(weightKg, weightKg - kPlateStepKg);
      return RpeAdvice(
        suggestedWeightKg: next ?? weightKg,
        extraRestSeconds: kExtraRestSeconds,
        message: next == null
            ? kRestMessage
            : redRepeatMessage(next, unit: unit),
        reason: next == null ? kReasonRed : kReasonRedRepeat,
        zone: zone,
      );
    }
    return RpeAdvice(
      suggestedWeightKg: weightKg,
      extraRestSeconds: kExtraRestSeconds,
      message: kRestMessage,
      reason: kReasonRed,
      zone: zone,
    );
  }
  if (_risingRpes(priorRpes, normalized)) {
    return RpeAdvice(
      suggestedWeightKg: weightKg,
      reason: kReasonRising,
      zone: zone,
    );
  }

  var (candidate, reason) = _tableCandidate(weightKg, normalized, kind);
  if (oneRmKg == null && reason == kReasonHold) reason = kReasonTable;
  var capped = false;
  if (oneRmKg != null && oneRmKg > 0 && zone != null && zone.length == 2) {
    final low = zone[0] * oneRmKg;
    final high = zone[1] * oneRmKg;
    final clamped = roundToPlate(candidate.clamp(low, high));
    if (clamped != candidate) {
      capped = true;
      reason = kReasonCapped;
    }
    candidate = clamped;
  }

  return RpeAdvice(
    suggestedWeightKg: candidate,
    reason: reason,
    cappedBy1rm: capped,
    zone: zone,
  );
}

/// 滑块旁的区间文案。
String rpeZoneLabel(double rpe) {
  final n = normalizeRpe(rpe);
  if (n >= kRpeFailure) return '彻底力竭';
  if (n >= kRpeRedZone) return '红区';
  if (n >= 9.0) return '接近极限';
  if (n >= kRpeSweetMin) return '甜蜜区';
  if (n >= 7.0) return '还能做';
  return '轻松';
}

/// 上次训练中对应组的幽灵数据（对照行；新增动作时次数/重量已预填）。
class GhostSet {
  const GhostSet({required this.setNumber, this.reps, this.weightKg, this.rpe});

  factory GhostSet.fromJson(Map<String, dynamic> json) => GhostSet(
    setNumber: (json['setNumber'] as num).toInt(),
    reps: (json['reps'] as num?)?.toInt(),
    weightKg: (json['weightKg'] as num?)?.toDouble(),
    rpe: (json['rpe'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'setNumber': setNumber,
    'reps': reps,
    'weightKg': weightKg,
    'rpe': rpe,
  };

  final int setNumber;
  final int? reps;
  final double? weightKg;
  final double? rpe;
}
