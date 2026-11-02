import 'package:app_flutter/features/coach/domain/coach_thought.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 思考过程。收起时是一行字，展开后是步骤文字，没有面板。
class CoachThoughtPanel extends StatefulWidget {
  const CoachThoughtPanel({super.key, required this.steps, required this.live});

  /// 已经产生的步骤。进行中可以为空。
  final List<CoachThoughtStep> steps;

  /// 为 true 时标题跟着最后一步走，并显示形变动效。
  final bool live;

  @override
  State<CoachThoughtPanel> createState() => _CoachThoughtPanelState();
}

class _CoachThoughtPanelState extends State<CoachThoughtPanel> {
  var _open = false;

  @override
  void didUpdateWidget(covariant CoachThoughtPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.live && oldWidget.live) _open = false;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = widget.steps.isNotEmpty ? widget.steps.last.title : '正在想';
    final title = widget.live ? last : '想了 ${widget.steps.length} 步';
    final canToggle = widget.steps.isNotEmpty || widget.live;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: !canToggle ? null : () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.live)
                    const M3ELoadingIndicator(
                      constraints: BoxConstraints.tightFor(width: 20, height: 20),
                    )
                  else
                    Icon(Symbols.check_rounded, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: widget.live ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (canToggle)
                    Icon(
                      _open ? Symbols.expand_less_rounded : Symbols.expand_more_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(left: 28, top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.steps.isEmpty && widget.live)
                          Text(
                            '正在看档案和最近的训练',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        for (final step in widget.steps)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  step.running ? '${step.title}…' : step.title,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: step.running ? scheme.primary : scheme.onSurface,
                                  ),
                                ),
                                if (step.detail.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      step.detail,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
