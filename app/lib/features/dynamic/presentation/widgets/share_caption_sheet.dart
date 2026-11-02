import 'package:m3e_core/m3e_core.dart';
import 'package:material_ui/material_ui.dart';

/// 弹出分享配文面板；确认返回配文（可为空串），取消返回 null。
Future<String?> showShareCaptionSheet(BuildContext context) {
  return showM3EModalBottomSheet<String>(
    context: context,
    builder: (_) => const ShareCaptionSheet(),
  );
}

/// 分享训练为动态时的配文输入（≤500 字符，可留空直接发）。
class ShareCaptionSheet extends StatefulWidget {
  const ShareCaptionSheet({super.key});

  @override
  State<ShareCaptionSheet> createState() => _ShareCaptionSheetState();
}

class _ShareCaptionSheetState extends State<ShareCaptionSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return M3EBottomSheet(
      title: const Text('分享这次训练'),
      actions: [
        M3EButton(
          style: M3EButtonStyle.filled,
          size: M3EButtonSize.sm,
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('发布'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: TextField(
          controller: _controller,
          maxLength: 500,
          maxLines: 3,
          minLines: 2,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '说点什么（可留空）',
            border: OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}
