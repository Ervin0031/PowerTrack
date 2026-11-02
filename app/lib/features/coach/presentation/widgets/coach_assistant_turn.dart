import 'package:app_flutter/features/coach/domain/coach_intent.dart';
import 'package:app_flutter/features/coach/domain/coach_proposal.dart';
import 'package:app_flutter/features/coach/domain/coach_thought.dart';
import 'package:app_flutter/features/coach/presentation/widgets/coach_markdown_body.dart';
import 'package:app_flutter/features/coach/presentation/widgets/coach_proposal_card.dart';
import 'package:app_flutter/features/coach/presentation/widgets/coach_thought_panel.dart';
import 'package:material_ui/material_ui.dart';

/// 教练的一轮回复：思考、正文、课表顺着往下排，不包在卡片里。
class CoachAssistantTurn extends StatelessWidget {
  const CoachAssistantTurn({
    super.key,
    required this.text,
    required this.thoughts,
    required this.intent,
    this.proposal,
    this.live = false,
    this.startingProposal = false,
    this.onStartProposal,
    this.markdownKey,
    this.onReveal,
    this.onRevealSettled,
  });

  /// 回复正文。生成过程中可以为空。
  final String text;

  /// 这一轮的思考步骤。
  final List<CoachThoughtStep> thoughts;

  /// 用户上一句被识别出的意图，用来决定要不要标一句主题。
  final CoachIntentRead intent;

  /// 排出的课表。没有课表时不显示。
  final CoachProposal? proposal;

  /// 这一轮还在生成。
  final bool live;

  /// 正在用课表开练。
  final bool startingProposal;

  /// 采纳课表。没有课表时为空。
  final VoidCallback? onStartProposal;

  /// 打字机状态要跨「生成中」和「已写入消息」保留时使用。
  final Key? markdownKey;

  /// 打出新的字时调用。
  final VoidCallback? onReveal;

  /// 这一段已经全部显示。
  final VoidCallback? onRevealSettled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showTopic = intent.kind == CoachIntent.analysis ||
        intent.kind == CoachIntent.recovery ||
        intent.kind == CoachIntent.health;

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (live || thoughts.isNotEmpty) CoachThoughtPanel(steps: thoughts, live: live),
          if (showTopic && text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                intent.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.tertiary),
              ),
            ),
          if (text.isNotEmpty)
            CoachMarkdownBody(
              key: markdownKey,
              text: text,
              streaming: live,
              onProgress: onReveal,
              onSettled: onRevealSettled,
            ),
          if (proposal != null)
            CoachProposalCard(
              proposal: proposal!,
              busy: startingProposal,
              onStart: onStartProposal ?? () {},
            ),
        ],
      ),
    );
  }
}
