/// 相对力量与体型对称度（纯 Dart，对应 `GET /stats/strength-standards`）。
///
/// 边界：未提交健身档案时 [hasProfile] 为 false、倍体重比与系数均为 null；
/// 性别为 undisclosed 时 [dots]/[wilks] 为 null；三大项不全时 [totalKg] 为 null
/// 并在 [missing] 列出缺失项。
class StrengthStandards {
  const StrengthStandards({
    required this.hasProfile,
    required this.gender,
    this.bodyweightKg,
    this.relativeStrength = const [],
    this.bigThree = const BigThree(),
    this.dots,
    this.wilks,
    this.pushPull,
  });

  factory StrengthStandards.fromJson(Map<String, dynamic> json) {
    return StrengthStandards(
      hasProfile: json['has_profile'] as bool? ?? false,
      gender: json['gender'] as String? ?? 'undisclosed',
      bodyweightKg: (json['bodyweight_kg'] as num?)?.toDouble(),
      relativeStrength: (json['relative_strength'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RelativeStrengthItem.fromJson)
          .toList(),
      bigThree: json['big_three'] is Map<String, dynamic>
          ? BigThree.fromJson(json['big_three'] as Map<String, dynamic>)
          : const BigThree(),
      dots: (json['dots'] as num?)?.toDouble(),
      wilks: (json['wilks'] as num?)?.toDouble(),
      pushPull: json['push_pull'] is Map<String, dynamic>
          ? PushPull.fromJson(json['push_pull'] as Map<String, dynamic>)
          : null,
    );
  }

  final bool hasProfile;
  final String gender;
  final double? bodyweightKg;
  final List<RelativeStrengthItem> relativeStrength;
  final BigThree bigThree;
  final double? dots;
  final double? wilks;
  final PushPull? pushPull;

  bool get isEmpty => relativeStrength.isEmpty;
}

class RelativeStrengthItem {
  const RelativeStrengthItem({
    required this.exerciseId,
    required this.name,
    required this.estimated1rmKg,
    this.ratio,
    this.isBigThree = false,
  });

  factory RelativeStrengthItem.fromJson(Map<String, dynamic> json) {
    return RelativeStrengthItem(
      exerciseId: (json['exercise_id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      estimated1rmKg: (json['estimated_1rm_kg'] as num?)?.toDouble() ?? 0,
      ratio: (json['ratio'] as num?)?.toDouble(),
      isBigThree: json['is_big_three'] as bool? ?? false,
    );
  }

  final int exerciseId;
  final String name;
  final double estimated1rmKg;
  final double? ratio;
  final bool isBigThree;
}

/// 三大项（深蹲 / 卧推 / 硬拉）与总和。
class BigThree {
  const BigThree({
    this.squat,
    this.bench,
    this.deadlift,
    this.totalKg,
    this.complete = false,
    this.missing = const [],
  });

  factory BigThree.fromJson(Map<String, dynamic> json) {
    BigThreeLift? lift(String key) {
      final raw = json[key];
      if (raw is! Map<String, dynamic>) return null;
      return BigThreeLift.fromJson(raw);
    }

    return BigThree(
      squat: lift('squat'),
      bench: lift('bench'),
      deadlift: lift('deadlift'),
      totalKg: (json['total_kg'] as num?)?.toDouble(),
      complete: json['complete'] as bool? ?? false,
      missing: (json['missing'] as List<dynamic>? ?? const []).map((e) => e.toString()).toList(),
    );
  }

  final BigThreeLift? squat;
  final BigThreeLift? bench;
  final BigThreeLift? deadlift;
  final double? totalKg;
  final bool complete;
  final List<String> missing;
}

class BigThreeLift {
  const BigThreeLift({this.estimated1rmKg, this.ratio});

  factory BigThreeLift.fromJson(Map<String, dynamic> json) {
    return BigThreeLift(
      estimated1rmKg: (json['estimated_1rm_kg'] as num?)?.toDouble(),
      ratio: (json['ratio'] as num?)?.toDouble(),
    );
  }

  final double? estimated1rmKg;
  final double? ratio;
}

/// 近 28 天推/拉容量比。
class PushPull {
  const PushPull({
    required this.windowDays,
    required this.pushVolumeKg,
    required this.pullVolumeKg,
    required this.pushHardSets,
    required this.pullHardSets,
    this.ratio,
    this.verdict = 'unknown',
  });

  factory PushPull.fromJson(Map<String, dynamic> json) {
    return PushPull(
      windowDays: (json['window_days'] as num?)?.toInt() ?? 28,
      pushVolumeKg: (json['push_volume_kg'] as num?)?.toDouble() ?? 0,
      pullVolumeKg: (json['pull_volume_kg'] as num?)?.toDouble() ?? 0,
      pushHardSets: (json['push_hard_sets'] as num?)?.toInt() ?? 0,
      pullHardSets: (json['pull_hard_sets'] as num?)?.toInt() ?? 0,
      ratio: (json['ratio'] as num?)?.toDouble(),
      verdict: json['verdict'] as String? ?? 'unknown',
    );
  }

  final int windowDays;
  final double pushVolumeKg;
  final double pullVolumeKg;
  final int pushHardSets;
  final int pullHardSets;
  final double? ratio;

  /// `unknown` / `balanced` / `push_dominant` / `pull_dominant`。
  final String verdict;

  String get verdictLabel => switch (verdict) {
        'balanced' => '推拉均衡',
        'push_dominant' => '推力偏多',
        'pull_dominant' => '拉力偏多',
        _ => '样本不足',
      };
}
