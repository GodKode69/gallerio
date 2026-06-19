import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/shell_screen.dart';
import 'app/theme.dart';
import 'core/security/security_service.dart';
import 'core/storage/local_prefs.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/lock_screen.dart';
import 'features/onboarding/screens/onboarding_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SecurityService().preloadCache();
  runApp(const ProviderScope(child: GallerioApp()));
}

final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  return await LocalPrefs().hasCompletedOnboarding;
});

class GallerioApp extends ConsumerWidget {
  const GallerioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final onboardingAsync = ref.watch(onboardingCompletedProvider);

    final bool showLock =
        authState.isPinSet && !authState.isUnlocked && !authState.isLoading;

    Widget home;
    if (onboardingAsync.isLoading || authState.isLoading) {
      home = const SizedBox.shrink();
    } else {
      final onboardingDone = onboardingAsync.valueOrNull ?? false;
      if (!onboardingDone) {
        home = Stack(
          children: [
            if (showLock) const LockScreen() else const ShellScreen(),
            OnboardingOverlay(
              onComplete: () => ref.invalidate(onboardingCompletedProvider),
            ),
          ],
        );
      } else {
        home = showLock ? const LockScreen() : const ShellScreen();
      }
    }

    return MaterialApp(
      title: 'Gallerio',
      theme: GallerioTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: home,
    );
  }
}
