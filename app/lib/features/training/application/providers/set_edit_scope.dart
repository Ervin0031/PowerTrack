import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 键盘改次数或重量时怎么写入。已完成的组始终不动。
enum SetEditMode {
  /// 每敲一下写入当前组，并让还没完成、且这个字段仍是旧值的组跟着变。
  auto,

  /// 只改正在输入的这一组，点「完成」或切到这项时写入。
  thisSet,

  /// 这个动作里所有还没做的组。
  allOpen,
}

final setEditModeProvider = NotifierProvider<SetEditModeNotifier, SetEditMode>(
  SetEditModeNotifier.new,
);

class SetEditModeNotifier extends Notifier<SetEditMode> {
  @override
  SetEditMode build() => SetEditMode.auto;

  void select(SetEditMode value) => state = value;
}
