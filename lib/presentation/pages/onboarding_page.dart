import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kaam_button.dart';
import '../controllers/auth_controller.dart';
import '../controllers/onboarding_provider.dart';
import '../widgets/content_max_width.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pageController = PageController();
  int _index = 0;

  static const _slides = <_OnboardingSlideModel>[
    _OnboardingSlideModel(
      icon: Icons.shield_outlined,
      title: 'Welcome to KAAM25',
      description:
          'A private collaboration platform designed for your closed group. This is not social media—it\'s a controlled digital workspace.',
    ),
    _OnboardingSlideModel(
      icon: Icons.lock_outline,
      title: 'Privacy & Access Control',
      description:
          'Only approved users can access. Every action is tied to your account. Nothing is anonymous. Access can be granted or revoked.',
    ),
    _OnboardingSlideModel(
      icon: Icons.groups_outlined,
      title: 'Core Features',
      description:
          'Share notes and documents, make official announcements, communicate via group chat, and post temporary status updates.',
    ),
    _OnboardingSlideModel(
      icon: Icons.notifications_outlined,
      title: 'Approval-Based System',
      description:
          'New users must be approved by admins. All devices must be approved. Important announcements require acknowledgment.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    // Sign out any existing session to ensure clean login flow
    await ref.read(authControllerProvider.notifier).logout();
    ref.read(hasSeenOnboardingProvider.notifier).state = true;
  }

  void _next() {
    if (_index < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: ContentMaxWidth(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              slide.icon,
                              size: 64,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            slide.description,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.mutedForeground),
                          ),
                          const SizedBox(height: 40),
                          _Dots(current: _index, total: _slides.length),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: [
                    KaamButton(
                      fullWidth: true,
                      size: KaamButtonSize.lg,
                      onPressed: _next,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(isLast ? 'Get Started' : 'Next'),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                    if (!isLast) ...[
                      const SizedBox(height: 10),
                      KaamButton(
                        fullWidth: true,
                        variant: KaamButtonVariant.ghost,
                        onPressed: _complete,
                        child: const Text('Skip'),
                      ),
                    ],
                    const SizedBox(height: 6),
                    const Text(
                      AppConstants.appName,
                      style: TextStyle(color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 8,
            width: i == current ? 28 : 8,
            decoration: BoxDecoration(
              color: i == current ? AppColors.primary : AppColors.muted,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}

class _OnboardingSlideModel {
  const _OnboardingSlideModel({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
