import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_icons.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/glyph_icon.dart';

class _Dest {
  const _Dest(this.icon, this.label);
  final Glyph icon;
  final String label;
}

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _items = [
    _Dest(AppIcons.home, 'Home'),
    _Dest(AppIcons.protection, 'Protection'),
    _Dest(AppIcons.history, 'Activity'),
    _Dest(AppIcons.recovery, 'Recovery'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = KeepOnTokens.of(context);
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border))),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: [
            for (final d in _items)
              NavigationDestination(
                icon: GlyphIcon(d.icon, size: AppSize.iconNav, color: t.textSecondary),
                selectedIcon: GlyphIcon(d.icon, size: AppSize.iconNav, color: t.primary),
                label: d.label,
              ),
          ],
        ),
      ),
    );
  }
}
