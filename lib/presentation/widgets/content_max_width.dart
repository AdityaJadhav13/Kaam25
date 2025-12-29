import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

class ContentMaxWidth extends StatelessWidget {
  const ContentMaxWidth({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppConstants.contentMaxWidth),
        child: child,
      ),
    );
  }
}
