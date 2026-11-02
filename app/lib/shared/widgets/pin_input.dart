import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:m3e_core/m3e_core.dart';

/// 单个 PIN 格子的展示数据。
///
/// 由 [PinInput] 在每次重建时计算后传给 [PinCellBuilder]：
/// - [character]：该格当前字符（未填为 `null`）。
/// - [isFocused]：是否为当前输入焦点格（即「下一个要填」的格子）。
/// - [shape]：本格当前使用的 m3e 形状（[Shapes]），每次成为焦点格会随机变化。
class PinCell {
  const PinCell({this.character, required this.isFocused, required this.shape});

  final String? character;
  final bool isFocused;
  final Shapes shape;
}

/// 单格渲染回调：根据 [PinCell] 返回该格的可视化（通常是 [M3EContainer]）。
///
/// 注意：此回调只负责「画」，真正的文本输入由 [PinInput] 内部覆盖在最上层的
/// 透明 [TextField] 捕获（点任意处即可聚焦），无需在 builder 里放可编辑控件。
typedef PinCellBuilder = Widget Function(BuildContext context, PinCell cell, int index);

/// m3e 风格的 PIN 输入框。
///
/// 设计要点：
/// - **单个隐藏输入框捕获输入**：避免「每格独立 TextField + requestFocus」在移动端
///   焦点不前进、输到第 2 格就卡住的坑；这里只用一个 [TextField]，按文本长度推导
///   「当前焦点格」，输入永不卡顿。
/// - **焦点格随机变形状**：[Shapes] 取自 [shapePool]，每当某格成为焦点格
///   （获焦或随输入推进）就给它随机分配一个形状；已填/失焦的格子保持原形状，不抖动。
/// - **修复 m3e 不重绘**：[M3EContainer] 底层的 `M3EClipper.shouldReclip` 恒为
///   `false`，换形状时 `ClipPath` 会复用旧裁剪路径（仅热重载才刷新）。因此每个格子
///   的视觉子树用随形状变化的 `Key` 重建，强制重新裁剪。
///
/// 用法见文件底部示例。
class PinInput extends StatefulWidget {
  const PinInput({
    super.key,
    required this.length,
    required this.cellBuilder,
    this.onCompleted,
    this.onChanged,
    this.keyboardType,
    this.autoFocus = false,
    this.obscure = false,
    this.spacing = 12,
    this.shapePool = _defaultShapePool,
  }) : assert(length > 0, 'length 必须大于 0');

  /// 格子数量（验证码位数）。
  final int length;

  /// 单格可视化渲染回调（只画，不接收输入）。
  final PinCellBuilder cellBuilder;

  /// 全部填满时回调，参数为完整 PIN 字符串。
  final ValueChanged<String>? onCompleted;

  /// 每次输入变化（未满）时回调。
  final ValueChanged<String>? onChanged;

  final TextInputType? keyboardType;
  final bool autoFocus;

  /// 是否用圆点遮挡字符（如密码型验证码）。
  final bool obscure;

  /// 格子之间的间距。
  final double spacing;

  /// 焦点格随机选用的形状池。
  final List<Shapes> shapePool;

  static const _defaultShapePool = [
    Shapes.square,
    Shapes.circle,
    Shapes.pill,
    Shapes.arch,
    Shapes.slanted,
    Shapes.diamond,
    Shapes.pentagon,
    Shapes.gem,
    Shapes.sunny,
    Shapes.flower,
    Shapes.burst,
    Shapes.triangle,
    Shapes.oval,
    Shapes.semicircle,
  ];

  @override
  State<PinInput> createState() => _PinInputState();
}

class _PinInputState extends State<PinInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _rng = Random();

  String _pin = '';
  List<Shapes> _shapes = [];
  bool _hasFocus = false;

  /// 当前焦点格索引：PIN 长度未到上限时为已填长度，否则为最后一格。
  int get _activeIndex => _pin.length < widget.length ? _pin.length : widget.length - 1;

  @override
  void initState() {
    super.initState();
    _shapes = List.filled(widget.length, widget.shapePool.first);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant PinInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.length != widget.length) {
      _shapes = List.filled(widget.length, widget.shapePool.first);
      if (_pin.length > widget.length) {
        _pin = _pin.substring(0, widget.length);
        _controller.text = _pin;
      }
    }
  }

  void _onFocusChanged() {
    final focused = _focusNode.hasFocus;
    if (focused == _hasFocus) return;
    _hasFocus = focused;
    if (focused) _assignRandomShape(_activeIndex);
    setState(() {});
  }

  void _onChanged(String value) {
    _pin = value;
    // 随输入推进，新的焦点格重新随机分配形状；已填格保持形状不变。
    _assignRandomShape(_activeIndex);
    if (_pin.length >= widget.length) {
      widget.onCompleted?.call(_pin);
    } else {
      widget.onChanged?.call(_pin);
    }
    setState(() {});
  }

  void _assignRandomShape(int index) {
    if (widget.shapePool.isEmpty) return;
    if (index < 0 || index >= _shapes.length) return;
    var next = widget.shapePool[_rng.nextInt(widget.shapePool.length)];
    // 池大于 1 时排除当前形状，保证「每次都看得见变化」。
    if (widget.shapePool.length > 1) {
      while (next == _shapes[index]) {
        next = widget.shapePool[_rng.nextInt(widget.shapePool.length)];
      }
    }
    _shapes[index] = next;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: widget.spacing,
          children: List.generate(widget.length, (i) {
            final raw = i < _pin.length ? _pin[i] : null;
            final cell = PinCell(
              character: widget.obscure && raw != null ? '•' : raw,
              isFocused: _hasFocus && i == _activeIndex,
              shape: _shapes[i],
            );
            // 随 shape 变化的 Key 强行重建本格视觉子树，绕过 m3e 的 shouldReclip=false。
            return KeyedSubtree(
              key: ValueKey('pin_cell_${i}_${_shapes[i]}'),
              child: widget.cellBuilder(context, cell, i),
            );
          }),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: widget.autoFocus,
              keyboardType: widget.keyboardType ?? TextInputType.text,
              maxLength: widget.length,
              onChanged: _onChanged,
              enableSuggestions: false,
              autocorrect: false,
              showCursor: false,
              cursorColor: Colors.transparent,
              decoration: const InputDecoration(
                border: InputBorder.none,
                counterText: '',
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(color: Colors.transparent, fontSize: 1),
            ),
          ),
        ),
      ],
    );
  }
}

/*
使用示例：

PinInput(
  length: 6,
  autoFocus: true,
  keyboardType: TextInputType.number,
  onChanged: (pin) => print('current: $pin'),
  onCompleted: (pin) => print('PIN: $pin'),
  cellBuilder: (context, cell, index) {
    final cs = Theme.of(context).colorScheme;
    return M3EContainer(
      cell.shape, // 焦点格每次聚焦会自动换成随机形状
      width: 48,
      height: 48,
      color: cell.isFocused ? cs.primary : cs.primaryContainer,
      child: Center(
        child: Text(
          cell.character ?? '',
          style: TextStyle(
            fontSize: 24,
            color: cell.isFocused ? cs.onPrimary : cs.onPrimaryContainer,
          ),
        ),
      ),
    );
  },
)
*/
