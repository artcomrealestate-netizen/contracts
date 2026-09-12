import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum BannerSeverity { error, warning }

/// Theme-aware replacement for the identical hand-rolled
/// `Colors.red.shade50` / `Colors.orange.shade50` Container block that used
/// to be copy-pasted into every form/detail screen — centralizing it means
/// one consistent look, and dark mode works correctly (see AppStatusColors)
/// instead of a hardcoded light-mode-only color.
class InlineBanner extends StatelessWidget {
  final String? message;
  final Widget? child;
  final BannerSeverity severity;

  const InlineBanner({super.key, required String this.message, this.severity = BannerSeverity.error})
      : child = null;

  /// For content richer than one line (e.g. a title plus a bulleted list) —
  /// still gets the same icon/background/border treatment as [message].
  const InlineBanner.content({super.key, required Widget this.child, this.severity = BannerSeverity.error})
      : message = null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = AppStatusColors.of(context);
    final isError = severity == BannerSeverity.error;
    final background = isError ? colorScheme.errorContainer : status.warningContainer;
    final foreground = isError ? colorScheme.onErrorContainer : status.onWarningContainer;
    final border = isError ? colorScheme.error.withValues(alpha: 0.4) : status.warningBorder;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isError ? Icons.error_outline : Icons.info_outline, color: foreground, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: DefaultTextStyle.merge(
              style: TextStyle(color: foreground),
              child: child ?? Text(message!),
            ),
          ),
        ],
      ),
    );
  }
}
