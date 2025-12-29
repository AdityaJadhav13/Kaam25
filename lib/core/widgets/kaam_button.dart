import 'package:flutter/material.dart';

enum KaamButtonVariant { primary, outline, ghost }

enum KaamButtonSize { normal, lg, icon }

class KaamButton extends StatelessWidget {
  const KaamButton({
    required this.onPressed,
    required this.child,
    this.variant = KaamButtonVariant.primary,
    this.size = KaamButtonSize.normal,
    this.fullWidth = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final KaamButtonVariant variant;
  final KaamButtonSize size;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final button = switch (variant) {
      KaamButtonVariant.primary => ElevatedButton(
          onPressed: onPressed,
          child: child,
        ),
      KaamButtonVariant.outline => OutlinedButton(
          onPressed: onPressed,
          child: child,
        ),
      KaamButtonVariant.ghost => TextButton(
          onPressed: onPressed,
          child: child,
        ),
    };

    final padded = switch (size) {
      KaamButtonSize.normal => button,
      KaamButtonSize.lg => Theme(
          data: Theme.of(context).copyWith(
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: Theme.of(context).elevatedButtonTheme.style?.copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
                  ) ??
                  const ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(Size(0, 52)),
                  ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: Theme.of(context).outlinedButtonTheme.style?.copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
                  ) ??
                  const ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(Size(0, 52)),
                  ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: Theme.of(context).textButtonTheme.style?.copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
                  ) ??
                  const ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(Size(0, 52)),
                  ),
            ),
          ),
          child: button,
        ),
      KaamButtonSize.icon => SizedBox(
          width: 44,
          height: 44,
          child: switch (variant) {
            KaamButtonVariant.primary => ElevatedButton(
                onPressed: onPressed,
                child: child,
              ),
            KaamButtonVariant.outline => OutlinedButton(
                onPressed: onPressed,
                child: child,
              ),
            KaamButtonVariant.ghost => TextButton(
                onPressed: onPressed,
                child: child,
              ),
          },
        ),
    };

    if (!fullWidth) return padded;
    return SizedBox(width: double.infinity, child: padded);
  }
}
