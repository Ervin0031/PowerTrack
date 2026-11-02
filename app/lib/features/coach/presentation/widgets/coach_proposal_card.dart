import 'package:app_flutter/features/coach/domain/coach_proposal.dart';
import 'package:app_flutter/features/coach/presentation/widgets/proposal_exercise_list.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// 教练排出的一堂课。标题、摘要和动作列表直接铺在对话里，下面一个开始按钮。
class CoachProposalCard extends StatelessWidget {
  const CoachProposalCard({
    super.key,
    required this.proposal,
    required this.busy,
    required this.onStart,
  });

  /// 要展示的课表。
  final CoachProposal proposal;

  /// 正在创建训练会话时为 true，按钮不可再点。
  final bool busy;

  /// 采纳这堂课并进入训练。
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final totalSets = proposal.exercises.fold<int>(0, (sum, exercise) => sum + exercise.sets.length);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(proposal.title, style: textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            proposal.summary,
            style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            '${proposal.estimatedMinutes} 分钟 · ${proposal.exercises.length} 个动作 · $totalSets 组',
            style: textTheme.labelLarge?.copyWith(color: scheme.primary),
          ),
          const SizedBox(height: 12),
          ProposalExerciseList(exercises: proposal.exercises),
          const SizedBox(height: 16),
          M3EButton.icon(
            onPressed: busy ? null : onStart,
            size: .md,
            icon: busy
                ? M3ELoadingIndicator(
                    color: scheme.onPrimary,
                    constraints: const BoxConstraints.tightFor(width: 22, height: 22),
                  )
                : const Icon(Symbols.play_arrow_rounded, fill: 1),
            label: Text(busy ? '正在准备' : '开始这堂训练'),
          ),
        ],
      ),
    );
  }
}
