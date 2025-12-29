import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class KaamAvatar extends StatelessWidget {
  const KaamAvatar({
    required this.initials,
    this.size = 40,
    this.background,
    super.key,
  });

  final String initials;
  final double size;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? AppColors.primary;
    final fg = AppColors.primaryForeground;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
