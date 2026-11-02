import 'package:app_flutter/core/ui/ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 分 / 秒滚轮选择休息时长；确认返回秒数，取消返回 null。
class RestDurationPickerSheet extends StatefulWidget {
  const RestDurationPickerSheet({super.key, required this.initialSeconds});

  final int initialSeconds;

  @override
  State<RestDurationPickerSheet> createState() => _RestDurationPickerSheetState();
}

class _RestDurationPickerSheetState extends State<RestDurationPickerSheet> {
  static const _maxMinutes = 10;
  static const _secondStep = 5;
  static const _secondValues = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];

  late int _minutes;
  late int _seconds;
  late final FixedExtentScrollController _minuteCtrl;
  late final FixedExtentScrollController _secondCtrl;

  @override
  void initState() {
    super.initState();
    final aligned = (widget.initialSeconds ~/ _secondStep) * _secondStep;
    _minutes = (aligned ~/ 60).clamp(0, _maxMinutes);
    _seconds = aligned % 60;
    if (!_secondValues.contains(_seconds)) _seconds = 0;
    _minuteCtrl = FixedExtentScrollController(initialItem: _minutes);
    _secondCtrl = FixedExtentScrollController(initialItem: _secondValues.indexOf(_seconds));
  }

  @override
  void dispose() {
    _minuteCtrl.dispose();
    _secondCtrl.dispose();
    super.dispose();
  }

  int get _totalSeconds => _minutes * 60 + _seconds;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return M3EBottomSheet(
      title: Text("休息时间"),
      padding: EdgeInsets.zero,
      actions: [
        M3EButton.icon(
          style: M3EButtonStyle.filled,
          shape: M3EButtonShape.round,
          size: M3EButtonSize.sm,
          onPressed: () => Navigator.pop(context, _totalSeconds <= 0 ? _secondStep : _totalSeconds),
          icon: const Icon(Symbols.check_rounded, size: 20),
          label: Text("完成"),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 选中区胶囊高亮（跨两列）。
                IgnorePointer(
                  child: Container(
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.field),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: _minuteCtrl,
                        itemExtent: 40,
                        magnification: 1.05,
                        useMagnifier: true,
                        selectionOverlay: const SizedBox.shrink(),
                        onSelectedItemChanged: (i) => setState(() => _minutes = i),
                        children: [
                          for (var m = 0; m <= _maxMinutes; m++)
                            Center(child: Text('$m分钟', style: Theme.of(context).textTheme.titleMedium)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: _secondCtrl,
                        itemExtent: 40,
                        magnification: 1.05,
                        useMagnifier: true,
                        selectionOverlay: const SizedBox.shrink(),
                        onSelectedItemChanged: (i) => setState(() => _seconds = _secondValues[i]),
                        children: [
                          for (final s in _secondValues)
                            Center(child: Text('$s秒', style: Theme.of(context).textTheme.titleMedium)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
