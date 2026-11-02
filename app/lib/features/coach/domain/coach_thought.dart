/// 一轮思考里的一步：理解、推理，或一次工具调用。
class CoachThoughtStep {
  const CoachThoughtStep({
    required this.kind,
    required this.title,
    this.detail = '',
    this.state = 'done',
  });

  final String kind;
  final String title;
  final String detail;
  final String state;

  bool get running => state == 'running';

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'title': title,
        'detail': detail,
        'state': state,
      };

  factory CoachThoughtStep.fromJson(Map<String, dynamic> json) {
    return CoachThoughtStep(
      kind: json['kind'] as String? ?? 'tool',
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
      state: json['state'] as String? ?? 'done',
    );
  }
}

/// 并行工具会同时有多个 running 步骤，按标题替换最近一个，而不是只看末尾。
List<CoachThoughtStep> mergeThought(List<CoachThoughtStep> current, CoachThoughtStep step) {
  for (var i = current.length - 1; i >= 0; i--) {
    final item = current[i];
    if (item.title == step.title && item.running) {
      return [...current]..[i] = step;
    }
  }
  return [...current, step];
}
