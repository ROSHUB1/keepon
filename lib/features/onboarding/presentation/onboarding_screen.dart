import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/glyph_icon.dart';
import 'animated_art.dart';

class _PageData {
  const _PageData(this.title, this.body, this.asset, this.icon);
  final String title;
  final String body;
  final String asset;
  final Glyph icon;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _PageData(
      'Your Device, More Protected.',
      "Stay aware of your phone's activities with KEEPON's built-in protection features.",
      'assets/animations/onboarding_1.json',
      AppIcons.protection,
    ),
    _PageData(
      'Stay Alert. Stay in Control.',
      'Monitor device activities with motion detection, charger alerts, headphone alerts, and SIM monitoring.',
      'assets/animations/onboarding_2.json',
      AppIcons.motion,
    ),
    _PageData(
      'Be Ready for the Unexpected.',
      'Access helpful recovery information and resources if your phone goes missing.',
      'assets/animations/onboarding_3.json',
      AppIcons.recovery,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pages.length - 1) {
      context.go('/setup');
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = KeepOnTokens.of(context);
    final text = Theme.of(context).textTheme;
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.s, AppSpace.xl, AppSpace.xl),
          child: Column(
            children: [
              Row(
                children: [
                  Image.asset('assets/brand/k_mark.png', height: 28, semanticLabel: 'KEEPON logo'),
                  const Spacer(),
                  if (!last) TextButton(onPressed: () => context.go('/setup'), child: const Text('Skip')),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    final d = _pages[i];
                    return LayoutBuilder(
                      builder: (context, c) => SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: c.maxHeight),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedArt(asset: d.asset, fallback: d.icon),
                              const SizedBox(height: AppSpace.xl),
                              Text(d.title, style: text.headlineMedium, textAlign: TextAlign.center),
                              const SizedBox(height: AppSpace.m),
                              Text(
                                d.body,
                                style: text.bodyLarge?.copyWith(color: t.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 16),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? t.primary : t.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              PrimaryButton(label: last ? 'Get Started' : 'Next', onPressed: _next),
            ],
          ),
        ),
      ),
    );
  }
}
