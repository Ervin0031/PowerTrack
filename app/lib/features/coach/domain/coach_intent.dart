/// 用户这句话想让教练做什么。纯文本判断，不依赖模型。
enum CoachIntent { plan, analysis, recovery, health, chat }

class CoachIntentRead {
  const CoachIntentRead({
    required this.kind,
    required this.label,
    required this.directive,
    required this.hint,
  });

  final CoachIntent kind;

  /// 给界面看的短标签，例如「排今天的课」。
  final String label;

  /// 拼进系统提示，约束这一轮用文字还是课表。
  final String directive;

  /// 折叠思考条里的一句说明。
  final String hint;
}

const _planWords = [
  '排课',
  '排今天',
  '排一',
  '生成',
  '安排',
  '课表',
  '训练计划',
  '今天练',
  '做一份',
  '帮我排',
  '来一堂',
  '出一堂',
];

const _recoveryWords = ['恢复', '疲劳', '酸痛', '酸了', '休息够'];
const _analysisWords = ['分析', '复盘', '数据', '趋势', '进步', '统计', '容量'];
const _healthWords = [
  '睡眠',
  '睡得',
  '精力',
  '健康',
  '热身',
  '放松',
  '拉伸',
  '心率',
  '步数',
  '体重',
  '压力',
  '适不适合',
  '状态怎么样',
];

/// 排课优先于恢复、复盘和健康，避免「排课并看恢复」被收成纯问答。
CoachIntentRead readCoachIntent(String text) {
  if (_planWords.any(text.contains)) {
    return const CoachIntentRead(
      kind: CoachIntent.plan,
      label: '排今天的课',
      hint: '要一份能开始练的课表',
      directive:
          '这是排课。先 get_profile、get_training_context、search_exercises、get_exercise_loads，最后 propose_session。'
          '动作 id 必须来自本轮搜索。遵守伤病、器械和单次时长，恢复低于 0.45 的肌群少排。',
    );
  }
  if (_recoveryWords.any(text.contains)) {
    return const CoachIntentRead(
      kind: CoachIntent.recovery,
      label: '看恢复',
      hint: '想知道肌群恢复和这周还能练多少',
      directive:
          '这是恢复问答。调用 get_profile 和 get_training_context，用文字说明肌群恢复和本周容量。'
          '不要调用 propose_session，不要输出动作组数课表。',
    );
  }
  if (_analysisWords.any(text.contains)) {
    return const CoachIntentRead(
      kind: CoachIntent.analysis,
      label: '训练复盘',
      hint: '想看最近练得怎么样',
      directive:
          '这是复盘。调用 get_profile、get_training_context，并按需调用 get_stats_overview、'
          'get_recent_sessions、get_exercise_stats。用文字回答。不要调用 propose_session。',
    );
  }
  if (_healthWords.any(text.contains)) {
    return const CoachIntentRead(
      kind: CoachIntent.health,
      label: '健康状态',
      hint: '想听睡眠、精力和练前练后怎么安排',
      directive:
          '这是健康教练。围绕睡眠、精力、热身、放松和今天适不适合加量，用文字给建议。'
          '可以调用 get_profile 和 get_training_context。不要 propose_session。'
          '不诊断、不开药、不给热量或医疗处方。',
    );
  }
  return const CoachIntentRead(
    kind: CoachIntent.chat,
    label: '随便聊聊',
    hint: '先直接回答',
    directive: '这是普通对话。先用文字回答。只有用户明确改口要排课时才 propose_session。缺数据再调用工具。',
  );
}
