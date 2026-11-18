import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../shared/providers/protection_controller.dart';
import '../shared/providers/providers.dart';
import 'router.dart';

class KeepOnApp extends ConsumerStatefulWidget {
  const KeepOnApp({super.key});

  @override
  ConsumerState<KeepOnApp> createState() => _KeepOnAppState();
}

class _KeepOnAppState extends ConsumerState<KeepOnApp> with WidgetsBindingObserver {
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The native service pings us when it records an event or the alarm changes.
    _sub = ref.read(bridgeProvider).changes.listen(
          (_) => ref.read(protectionProvider.notifier).refresh(),
          onError: (_) {},
        );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(protectionProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(settingsProvider.select((s) => s.themeMode));
    // Open the full-screen alarm as soon as an alarm starts ringing.
    ref.listen<bool>(protectionProvider.select((p) => p.alarmRinging), (prev, next) {
      if (next && prev != true) appRouter.push('/alarm');
    });
    return MaterialApp.router(
      title: 'KEEPON',
      debugShowCheckedModeBanner: false,
      theme: buildKeepOnTheme(Brightness.light),
      darkTheme: buildKeepOnTheme(Brightness.dark),
      themeMode: mode,
      routerConfig: appRouter,
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: dark ? KeepOnTokens.dark.surface : KeepOnTokens.light.surface,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
