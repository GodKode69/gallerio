import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/shell_screen.dart';
import 'app/theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/lock_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: GallerioApp()));
}

class GallerioApp extends ConsumerWidget {
  const GallerioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    final bool showLock =
        authState.isPinSet && !authState.isUnlocked && !authState.isLoading;

    return MaterialApp(
      title: 'Gallerio',
      theme: GallerioTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: showLock ? const LockScreen() : const ShellScreen(),
    );
  }
}
