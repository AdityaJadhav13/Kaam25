import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum KaamBadgeVariant { primary, secondary, outline, destructive }

class KaamBadge extends StatelessWidget {
  const KaamBadge({
    required this.label,
    this.variant = KaamBadgeVariant.secondary,
    this.compact = true,
    super.key,
  });

  final String label;
  final KaamBadgeVariant variant;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      KaamBadgeVariant.primary => (AppColors.primary, AppColors.primaryForeground, AppColors.primary),
      KaamBadgeVariant.secondary => (AppColors.muted, AppColors.foreground, AppColors.border),
      KaamBadgeVariant.outline => (Colors.transparent, AppColors.foreground, AppColors.border),
      KaamBadgeVariant.destructive => (AppColors.destructive, AppColors.destructiveForeground, AppColors.destructive),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}
