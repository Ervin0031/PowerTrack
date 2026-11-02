/// 根据本场动作和最近训练，选出下一个动作。纯数据，不访问网络。
class NextLift {
  const NextLift({
    required this.exerciseId,
    required this.name,
    this.muscleGroupId,
    this.muscleName,
    this.exerciseType = 'compound',
    this.imageUrl,
  });

  final int exerciseId;
  final String name;
  final int? muscleGroupId;
  final String? muscleName;
  final String exerciseType;
  final String? imageUrl;
}

class NextExerciseChoice {
  const NextExerciseChoice({required this.lift, required this.reason});

  final NextLift lift;
  final String reason;
}

const _equipmentPrefixes = ['史密斯机', '史密斯', '杠铃', '哑铃', '壶铃', '绳索', '器械', '杠杆'];

/// 去掉器械前缀，用来判断「卧推」和「上斜杠铃卧推」是不是同一类。
String exerciseStem(String name) {
  var text = name.trim();
  for (final prefix in _equipmentPrefixes) {
    if (text.startsWith(prefix)) {
      text = text.substring(prefix.length).trim();
      break;
    }
  }
  return text;
}

bool sameExerciseFamily(String a, String b) {
  final left = exerciseStem(a);
  final right = exerciseStem(b);
  if (left.length < 2 || right.length < 2) return false;
  return left == right || left.contains(right) || right.contains(left);
}

/// [recentSessions] 从新到旧。没有和本场肌群或历史顺序接得上的动作时返回 null。
NextExerciseChoice? pickNextExercise({
  required List<NextLift> session,
  int? focusedExerciseId,
  required List<List<NextLift>> recentSessions,
  required List<NextLift> catalog,
  Set<int> excludeIds = const {},
}) {
  final blocked = {for (final lift in session) lift.exerciseId, ...excludeIds};
  if (session.isEmpty) {
    for (final past in recentSessions) {
      for (final lift in past) {
        if (blocked.contains(lift.exerciseId)) continue;
        return NextExerciseChoice(lift: lift, reason: '沿用上次训练开始的动作');
      }
    }
    return null;
  }

  NextLift? focused;
  for (final lift in session) {
    if (lift.exerciseId == focusedExerciseId) focused = lift;
  }
  focused ??= session.last;
  final muscles = {
    for (final lift in session)
      if (lift.muscleGroupId != null) lift.muscleGroupId!,
  };

  NextLift? best;
  var bestScore = 0;
  var bestReason = '';

  void consider(NextLift lift, int score, String reason, {bool allowOtherMuscle = false}) {
    if (blocked.contains(lift.exerciseId)) return;
    final muscle = lift.muscleGroupId;
    final inSession = muscle == null || muscles.isEmpty || muscles.contains(muscle);
    if (!inSession && !allowOtherMuscle) return;
    final imageBonus = lift.imageUrl != null && lift.imageUrl!.isNotEmpty ? 1 : 0;
    final total = score + imageBonus;
    if (total <= bestScore) return;
    best = lift;
    bestScore = total;
    bestReason = reason;
  }

  for (var index = 0; index < recentSessions.length; index++) {
    final past = recentSessions[index];
    final recency = (recentSessions.length - index) * 5;
    for (var i = 0; i < past.length; i++) {
      final current = past[i].exerciseId;
      final inThisSession = session.any((lift) => lift.exerciseId == current);
      if (!inThisSession) continue;
      final followedFocus = current == focused.exerciseId;
      for (var j = i + 1; j < past.length; j++) {
        final next = past[j];
        if (blocked.contains(next.exerciseId)) continue;
        final sameMuscle = next.muscleGroupId != null && next.muscleGroupId == focused.muscleGroupId;
        consider(
          next,
          90 + recency + (followedFocus ? 20 : 0) + (sameMuscle ? 10 : 0),
          followedFocus ? '上次${focused.name}之后就是这个' : '接上次这场训练的下一个动作',
          allowOtherMuscle: true,
        );
        break;
      }
    }
  }

  for (final past in recentSessions) {
    for (final lift in past) {
      if (lift.muscleGroupId != null && lift.muscleGroupId == focused.muscleGroupId) {
        consider(lift, 60, '继续练${lift.muscleName ?? focused.muscleName ?? '这个肌群'}');
      } else if (lift.muscleGroupId != null && muscles.contains(lift.muscleGroupId)) {
        consider(lift, 45, '接着练${lift.muscleName ?? '这场已经在练的肌群'}');
      }
    }
  }

  for (final lift in catalog) {
    final muscle = lift.muscleGroupId;
    if (muscle == null || !muscles.contains(muscle)) continue;
    if (!sameExerciseFamily(focused.name, lift.name)) continue;
    final same = muscle == focused.muscleGroupId;
    consider(lift, same ? 50 : 40, '和${focused.name}是同一类动作');
  }

  final chosen = best;
  if (chosen == null || bestScore < 40) return null;
  return NextExerciseChoice(lift: chosen, reason: bestReason);
}
