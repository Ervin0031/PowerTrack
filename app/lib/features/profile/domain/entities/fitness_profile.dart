/// 健身档案枚举与实体。纯 Dart，零 Flutter / Riverpod。
library;

class FitnessGender {
  static const male = 'male';
  static const female = 'female';
  static const undisclosed = 'undisclosed';

  static const labels = {
    male: '男',
    female: '女',
    undisclosed: '不愿透露',
  };
}

class FitnessGoal {
  static const fatLoss = 'fat_loss';
  static const muscleGain = 'muscle_gain';
  static const reshape = 'reshape';
  static const health = 'health';
  static const performance = 'performance';

  static const labels = {
    fatLoss: '减脂',
    muscleGain: '增肌',
    reshape: '塑形',
    health: '保持健康',
    performance: '提升体能',
  };
}

class FitnessExperience {
  static const beginner = 'beginner';
  static const intermediate = 'intermediate';
  static const advanced = 'advanced';

  static const labels = {
    beginner: '从没练过',
    intermediate: '偶尔练',
    advanced: '规律练',
  };

  static const hints = {
    beginner: '从零开始，动作会更简单、重量更轻',
    intermediate: '有一点基础，能跟上常规训练',
    advanced: '长期规律训练，需要更高强度',
  };
}

class FitnessInjury {
  static const knee = 'knee';
  static const back = 'back';
  static const shoulder = 'shoulder';

  static const labels = {
    knee: '膝盖',
    back: '腰',
    shoulder: '肩',
  };
}

class ProfileMetrics {
  const ProfileMetrics({
    required this.age,
    required this.bmr,
    required this.tdee,
    required this.calorieTarget,
    required this.maxHr,
    required this.activityFactor,
    required this.splitName,
  });

  factory ProfileMetrics.fromJson(Map<String, dynamic> json) => ProfileMetrics(
        age: (json['age'] as num).toInt(),
        bmr: (json['bmr'] as num).toDouble(),
        tdee: (json['tdee'] as num).toDouble(),
        calorieTarget: (json['calorie_target'] as num).toDouble(),
        maxHr: (json['max_hr'] as num).toDouble(),
        activityFactor: (json['activity_factor'] as num).toDouble(),
        splitName: json['split_name'] as String? ?? '',
      );

  final int age;
  final double bmr;
  final double tdee;
  final double calorieTarget;
  final double maxHr;
  final double activityFactor;
  final String splitName;
}

class FitnessProfile {
  const FitnessProfile({
    required this.gender,
    required this.birthYear,
    required this.heightCm,
    required this.weightKg,
    required this.goal,
    required this.experience,
    this.injuryTags = const [],
    this.weeklyDays,
    this.sessionMinutes,
    this.equipment,
    this.preferences = const [],
    this.metrics,
  });

  factory FitnessProfile.fromJson(Map<String, dynamic> json) {
    final rawMetrics = json['metrics'];
    return FitnessProfile(
      gender: json['gender'] as String,
      birthYear: (json['birth_year'] as num).toInt(),
      heightCm: (json['height_cm'] as num).toDouble(),
      weightKg: (json['weight_kg'] as num).toDouble(),
      goal: json['goal'] as String,
      experience: json['experience'] as String,
      injuryTags: _stringList(json['injury_tags']),
      weeklyDays: (json['weekly_days'] as num?)?.toInt(),
      sessionMinutes: (json['session_minutes'] as num?)?.toInt(),
      equipment: json['equipment'] as String?,
      preferences: _stringList(json['preferences']),
      metrics: rawMetrics is Map<String, dynamic> ? ProfileMetrics.fromJson(rawMetrics) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'gender': gender,
        'birthYear': birthYear,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'goal': goal,
        'experience': experience,
        'injuryTags': injuryTags,
        'weeklyDays': weeklyDays,
        'sessionMinutes': sessionMinutes,
        'equipment': equipment,
        'preferences': preferences,
      };

  bool get isCoreComplete =>
      gender.isNotEmpty &&
      birthYear >= 1926 &&
      heightCm >= 100 &&
      weightKg >= 30 &&
      goal.isNotEmpty &&
      experience.isNotEmpty;

  FitnessProfile copyWith({
    String? gender,
    int? birthYear,
    double? heightCm,
    double? weightKg,
    String? goal,
    String? experience,
    List<String>? injuryTags,
    int? weeklyDays,
    int? sessionMinutes,
    String? equipment,
    List<String>? preferences,
    ProfileMetrics? metrics,
  }) {
    return FitnessProfile(
      gender: gender ?? this.gender,
      birthYear: birthYear ?? this.birthYear,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      goal: goal ?? this.goal,
      experience: experience ?? this.experience,
      injuryTags: injuryTags ?? this.injuryTags,
      weeklyDays: weeklyDays ?? this.weeklyDays,
      sessionMinutes: sessionMinutes ?? this.sessionMinutes,
      equipment: equipment ?? this.equipment,
      preferences: preferences ?? this.preferences,
      metrics: metrics ?? this.metrics,
    );
  }

  final String gender;
  final int birthYear;
  final double heightCm;
  final double weightKg;
  final String goal;
  final String experience;
  final List<String> injuryTags;
  final int? weeklyDays;
  final int? sessionMinutes;
  final String? equipment;
  final List<String> preferences;
  final ProfileMetrics? metrics;
}

class FitnessProfileDraft {
  const FitnessProfileDraft({
    this.gender,
    this.birthYear = 1998,
    this.heightCm = 170,
    this.weightKg = 65,
    this.goal,
    this.experience,
    this.injuryTags = const [],
    this.weeklyDays = 3,
    this.sessionMinutes = 45,
  });

  factory FitnessProfileDraft.fromJson(Map<String, dynamic> json) => FitnessProfileDraft(
        gender: json['gender'] as String?,
        birthYear: (json['birthYear'] as num?)?.toInt() ?? 1998,
        heightCm: (json['heightCm'] as num?)?.toDouble() ?? 170,
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 65,
        goal: json['goal'] as String?,
        experience: json['experience'] as String?,
      injuryTags: _stringList(json['injuryTags']),
        weeklyDays: (json['weeklyDays'] as num?)?.toInt() ?? 3,
        sessionMinutes: (json['sessionMinutes'] as num?)?.toInt() ?? 45,
      );

  Map<String, dynamic> toJson() => {
        'gender': gender,
        'birthYear': birthYear,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'goal': goal,
        'experience': experience,
        'injuryTags': injuryTags,
        'weeklyDays': weeklyDays,
        'sessionMinutes': sessionMinutes,
      };

  factory FitnessProfileDraft.fromProfile(FitnessProfile profile) => FitnessProfileDraft(
        gender: profile.gender,
        birthYear: profile.birthYear,
        heightCm: profile.heightCm,
        weightKg: profile.weightKg,
        goal: profile.goal,
        experience: profile.experience,
        injuryTags: profile.injuryTags,
        weeklyDays: profile.weeklyDays ?? 3,
        sessionMinutes: profile.sessionMinutes ?? 45,
      );

  bool get canSubmit =>
      gender != null && goal != null && experience != null && heightCm >= 100 && weightKg >= 30;

  FitnessProfile toProfile() => FitnessProfile(
        gender: gender!,
        birthYear: birthYear,
        heightCm: heightCm,
        weightKg: weightKg,
        goal: goal!,
        experience: experience!,
        injuryTags: injuryTags,
        weeklyDays: weeklyDays,
        sessionMinutes: sessionMinutes,
      );

  FitnessProfileDraft copyWith({
    String? gender,
    int? birthYear,
    double? heightCm,
    double? weightKg,
    String? goal,
    String? experience,
    List<String>? injuryTags,
    int? weeklyDays,
    int? sessionMinutes,
  }) {
    return FitnessProfileDraft(
      gender: gender ?? this.gender,
      birthYear: birthYear ?? this.birthYear,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      goal: goal ?? this.goal,
      experience: experience ?? this.experience,
      injuryTags: injuryTags ?? this.injuryTags,
      weeklyDays: weeklyDays ?? this.weeklyDays,
      sessionMinutes: sessionMinutes ?? this.sessionMinutes,
    );
  }

  final String? gender;
  final int birthYear;
  final double heightCm;
  final double weightKg;
  final String? goal;
  final String? experience;
  final List<String> injuryTags;
  final int weeklyDays;
  final int sessionMinutes;
}

List<String> _stringList(dynamic raw) {
  if (raw is List) return raw.map((e) => e.toString()).toList();
  return const [];
}
