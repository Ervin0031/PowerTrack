import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'active_set_edit_provider.g.dart';

/// 正在编辑的组字段（次数 / 重量）。
enum EditField { reps, weight }

/// 当前聚焦的组字段编辑状态。
///
/// 键盘升起时底部的编辑栏据此选择「自动更新 / 这组 / 全部未做」；
/// `text` 为输入框当前文本，用于批量填充与手动提交。
class ActiveSetEdit {
  const ActiveSetEdit({
    required this.exerciseId,
    required this.setNumber,
    required this.field,
    required this.text,
  });

  final int exerciseId;
  final int setNumber;
  final EditField field;
  final String text;

  ActiveSetEdit copyWith({String? text}) => ActiveSetEdit(
        exerciseId: exerciseId,
        setNumber: setNumber,
        field: field,
        text: text ?? this.text,
      );
}

/// 当前聚焦编辑的组字段；无聚焦时返回 null。
@Riverpod(keepAlive: true)
class ActiveSetEditNotifier extends _$ActiveSetEditNotifier {
  @override
  ActiveSetEdit? build() => null;

  void update(ActiveSetEdit edit) => state = edit;
  void clear() => state = null;
}

/// 输入即写入开关：开（默认）时每次按键直接写入；关时需点「完成」或菜单项才生效。
@Riverpod(keepAlive: true)
class AutoUpdate extends _$AutoUpdate {
  @override
  bool build() => true;
  void toggle() => state = !state;
}