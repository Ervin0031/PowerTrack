import 'package:app_flutter/features/coach/domain/coach_thread.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 左侧对话列表。当前这条用字重区分，不画选中底。
class CoachHistoryDrawer extends StatelessWidget {
  const CoachHistoryDrawer({
    super.key,
    required this.threads,
    required this.selectedId,
    required this.onNew,
    required this.onSelect,
  });

  /// 最近的对话，新的在前。
  final List<CoachThreadSummary> threads;

  /// 正在看的对话。没有时为空。
  final int? selectedId;

  /// 关掉抽屉并开始一条新对话。
  final VoidCallback onNew;

  /// 关掉抽屉并打开这条对话。
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Drawer(
      backgroundColor: scheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('对话', style: textTheme.headlineSmall),
              ),
              M3EButton.icon(
                style: M3EButtonStyle.text,
                onPressed: onNew,
                icon: const Icon(Symbols.add_rounded),
                label: const Text('新的对话'),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: threads.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '还没有聊过',
                          style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.builder(
                        itemCount: threads.length,
                        itemBuilder: (context, index) {
                          final thread = threads[index];
                          final selected = thread.id == selectedId;
                          return InkWell(
                            onTap: () => onSelect(thread.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Text(
                                thread.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleMedium?.copyWith(
                                  color: selected ? scheme.primary : scheme.onSurface,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
