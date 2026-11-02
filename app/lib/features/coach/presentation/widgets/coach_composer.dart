import 'package:expressive_snack/expressive_snack.dart';
import 'package:flutter/rendering.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 贴在底部的输入条。单行时麦克风、文字、发送并排；放不下就改成文字在上。
///
/// 三个孩子始终是同一组，换行只改位置，输入框不会被拆掉，焦点和键盘保持住。
class CoachComposer extends StatefulWidget {
  const CoachComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.canSend,
    required this.onSend,
  });

  /// 草稿。发送成功后由外面清空。
  final TextEditingController controller;

  /// 没配 Key、正在回复或档案没写完时为 false。
  final bool enabled;

  /// 有文字且允许发送。
  final bool canSend;

  /// 把当前草稿发出去。
  final VoidCallback onSend;

  @override
  State<CoachComposer> createState() => _CoachComposerState();
}

class _CoachComposerState extends State<CoachComposer> {
  final _speech = SpeechToText();
  var _listening = false;
  var _ready = false;
  var _dictationBase = '';

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onDraft);
  }

  @override
  void didUpdateWidget(covariant CoachComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onDraft);
    widget.controller.addListener(_onDraft);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onDraft);
    if (_listening) _speech.stop();
    super.dispose();
  }

  void _onDraft() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleMic() async {
    if (!widget.enabled) return;
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!_ready) {
      final ok = await _speech.initialize(
        onError: (_) {
          if (!mounted) return;
          setState(() => _listening = false);
          showExpressiveSnack(context: context, message: '语音识别中断了', icon: Symbols.mic_off_rounded);
        },
        onStatus: (status) {
          if (!mounted) return;
          if (status == 'done' || status == 'notListening') {
            setState(() => _listening = false);
          }
        },
      );
      if (!ok) {
        if (!mounted) return;
        showExpressiveSnack(context: context, message: '这台设备暂时用不了语音输入', icon: Symbols.mic_off_rounded);
        return;
      }
      _ready = true;
    }
    _dictationBase = widget.controller.text.trim();
    final localeId = await _chineseLocale();
    if (!mounted) return;
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        final spoken = result.recognizedWords.trim();
        final next = spoken.isEmpty
            ? _dictationBase
            : _dictationBase.isEmpty
            ? spoken
            : '$_dictationBase $spoken';
        widget.controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      },
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        localeId: localeId,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 30),
      ),
    );
  }

  Future<void> _send() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
    }
    widget.onSend();
  }

  Future<String?> _chineseLocale() async {
    final locales = await _speech.locales();
    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith('zh')) return locale.localeId;
    }
    return null;
  }

  /// 单行时文字夹在两个按钮中间。放不下就改成文字在上、按钮在下。
  bool _needsStack(double maxWidth, TextStyle style) {
    final text = widget.controller.text;
    if (text.contains('\n')) return true;
    if (text.isEmpty) return false;
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    // sm 图标按钮的最小宽度是 56。
    const micWidth = 56.0;
    const sendWidth = 56.0;
    final inlineWidth = maxWidth - micWidth - sendWidth - 8;
    if (inlineWidth <= 8) return true;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout(maxWidth: inlineWidth);
    return painter.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fade = scheme.surface;
    final fieldStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurface, height: 1.35);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fade.withValues(alpha: 0), fade],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: _listening ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = _needsStack(constraints.maxWidth, fieldStyle ?? const TextStyle());
                      return _ComposerSlots(
                        stacked: stacked,

                        children: [_micButton(), _draftField(scheme, fieldStyle), _sendButton()],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '内容由 AI 生成，请仔细辨别',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _draftField(ColorScheme scheme, TextStyle? style) {
    return TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      minLines: 1,
      maxLines: 5,
      textInputAction: TextInputAction.send,
      keyboardType: TextInputType.text,
      style: style,
      cursorColor: scheme.primary,
      decoration: InputDecoration(
        hintText: !widget.enabled
            ? '先完成上面的设置'
            : _listening
            ? '在听'
            : '问教练',
        hintStyle: style?.copyWith(color: scheme.onSurfaceVariant),
        border: InputBorder.none,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onSubmitted: widget.canSend ? (_) => _send() : null,
    );
  }

  Widget _micButton() {
    return IconButton(
      tooltip: _listening ? '停止' : '语音',

      onPressed: widget.enabled ? _toggleMic : null,
      icon: Icon(_listening ? Symbols.stop_rounded : Symbols.mic_rounded),
    );
  }

  Widget _sendButton() {
    return IconButton(
      tooltip: '发送',
      style: ButtonStyle(backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.primaryContainer)),
      color: Theme.of(context).colorScheme.primary,
      onPressed: widget.canSend ? _send : null,
      icon: const Icon(Symbols.arrow_upward_rounded),
    );
  }
}

class _ComposerSlots extends MultiChildRenderObjectWidget {
  const _ComposerSlots({required this.stacked, required super.children});

  final bool stacked;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderComposerSlots(stacked: stacked);

  @override
  void updateRenderObject(BuildContext context, _RenderComposerSlots renderObject) {
    renderObject.stacked = stacked;
  }
}

class _ComposerSlotData extends ContainerBoxParentData<RenderBox> {}

class _RenderComposerSlots extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ComposerSlotData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ComposerSlotData> {
  _RenderComposerSlots({required this._stacked});

  bool _stacked;

  set stacked(bool value) {
    if (_stacked == value) return;
    _stacked = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ComposerSlotData) {
      child.parentData = _ComposerSlotData();
    }
  }

  @override
  void performLayout() {
    final mic = firstChild!;
    final field = childAfter(mic)!;
    final send = childAfter(field)!;
    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
    final loose = BoxConstraints(maxWidth: width);

    mic.layout(loose, parentUsesSize: true);
    send.layout(loose, parentUsesSize: true);
    final fieldWidth = _stacked ? width : (width - mic.size.width - send.size.width).clamp(0.0, width);
    field.layout(BoxConstraints(minWidth: fieldWidth, maxWidth: fieldWidth), parentUsesSize: true);

    final buttonHeight = mic.size.height > send.size.height ? mic.size.height : send.size.height;
    if (_stacked) {
      const gap = 4.0;
      size = Size(width, field.size.height + gap + buttonHeight);
      _place(field, Offset.zero);
      final top = field.size.height + gap;
      _place(mic, Offset(0, top + (buttonHeight - mic.size.height) / 2));
      _place(send, Offset(width - send.size.width, top + (buttonHeight - send.size.height) / 2));
    } else {
      final height = field.size.height > buttonHeight ? field.size.height : buttonHeight;
      size = Size(width, height);
      _place(mic, Offset(0, (height - mic.size.height) / 2));
      _place(field, Offset(mic.size.width, (height - field.size.height) / 2));
      _place(send, Offset(width - send.size.width, (height - send.size.height) / 2));
    }
  }

  void _place(RenderBox child, Offset offset) {
    (child.parentData! as _ComposerSlotData).offset = offset;
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
