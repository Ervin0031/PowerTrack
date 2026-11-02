import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:material_ui/material_ui.dart';

/// 教练回复正文。按主题色渲染 Markdown，不另加底和边。
///
/// [streaming] 为 true 时，短增量直接出现，一次涌进来的长文本按打字机展开。
/// 模型已经说完后，打字机仍会把剩下的字打完，再调用 [onSettled]。
class CoachMarkdownBody extends StatefulWidget {
  const CoachMarkdownBody({
    super.key,
    required this.text,
    this.streaming = false,
    this.onProgress,
    this.onSettled,
  });

  /// 到目前为止的 Markdown。生成过程中会变长。
  final String text;

  /// 模型还在继续输出。
  final bool streaming;

  /// 可见文字变长时调用，用来把列表跟到底部。
  final VoidCallback? onProgress;

  /// 这一段已经全部显示出来。
  final VoidCallback? onSettled;

  @override
  State<CoachMarkdownBody> createState() => _CoachMarkdownBodyState();
}

class _CoachMarkdownBodyState extends State<CoachMarkdownBody> with SingleTickerProviderStateMixin {
  static const _burst = 18;
  static const _charsPerSecond = 90.0;

  late final Ticker _ticker;
  var _shown = 0;
  var _armed = false;
  var _settled = false;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    if (widget.streaming) {
      _armed = true;
      _catchUp();
    } else {
      _shown = widget.text.characters.length;
    }
  }

  @override
  void didUpdateWidget(covariant CoachMarkdownBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.streaming) _armed = true;
    if (!_armed) {
      _shown = widget.text.characters.length;
      return;
    }
    final extended = widget.text.startsWith(oldWidget.text);
    if (!extended) {
      _shown = 0;
      _settled = false;
    }
    _catchUp();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _catchUp() {
    final total = widget.text.characters.length;
    if (_shown > total) _shown = total;
    final backlog = total - _shown;
    if (backlog <= 0) {
      _ticker.stop();
      if (_armed && !widget.streaming) _finish();
      return;
    }
    if (backlog <= _burst) {
      _shown = total;
      widget.onProgress?.call();
      if (!widget.streaming) _finish();
      return;
    }
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1000000;
    _last = elapsed;
    if (dt <= 0) return;
    final total = widget.text.characters.length;
    final step = math.max(1, (_charsPerSecond * dt).round());
    final next = math.min(total, _shown + step);
    if (next == _shown) return;
    setState(() => _shown = next);
    widget.onProgress?.call();
    if (_shown >= total) {
      _ticker.stop();
      if (!widget.streaming) _finish();
    }
  }

  void _finish() {
    if (_settled) return;
    _settled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSettled?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = Theme.of(context).textTheme.bodyLarge;
    final visible = widget.text.characters.take(_shown).toString();
    final typing = _armed && _shown < widget.text.characters.length;
    return GptMarkdownTheme(
      gptThemeData: GptMarkdownThemeData(
        brightness: Theme.of(context).brightness,
        h1: Theme.of(context).textTheme.headlineSmall,
        h2: Theme.of(context).textTheme.titleLarge,
        h3: Theme.of(context).textTheme.titleMedium,
      ),
      child: GptMarkdown(
        visible,
        style: body?.copyWith(color: scheme.onSurface, height: 1.55),
        isStreaming: typing || widget.streaming,
      ),
    );
  }
}
