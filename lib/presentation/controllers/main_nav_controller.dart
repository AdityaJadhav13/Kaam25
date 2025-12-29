import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MainTab { home, chat, announcements, profile }

final mainTabProvider = StateProvider<MainTab>((ref) => MainTab.home);
