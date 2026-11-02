import 'package:material_ui/material_ui.dart';

import 'snack_view.dart';

/// One shown snack and the key that reaches its live view.
class Snack {
  Snack({
    required this.message,
    required this.icon,
    required this.duration,
    this.actionLabel,
    this.onAction,
  });

  final GlobalKey<SnackViewState> key = GlobalKey();
  final String message;
  final IconData? icon;
  final Duration duration;

  /// Optional action button label shown at the trailing end of the pill.
  /// Tapping it runs [onAction] and then dismisses the pill.
  final String? actionLabel;
  final VoidCallback? onAction;
}
