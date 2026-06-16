import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/screens/pin_setup_screen.dart';
import '../features/auth/screens/lock_screen.dart';
import '../features/vault/screens/vault_screen.dart';
import '../features/viewer/screens/viewer_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import 'shell_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/gallery',
    redirect: (context, state) {
      final isPinSet = authState.isPinSet;
      final isUnlocked = authState.isUnlocked;
      final isLoading = authState.isLoading;
      final goingToLock = state.matchedLocation == '/lock';
      final goingToSetup = state.matchedLocation == '/setup';

      if (isLoading) return null;

      if (isPinSet && !isUnlocked && !goingToLock && !goingToSetup) {
        return '/lock';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/setup',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return PinSetupScreen(
            changeMode: extra?['changeMode'] ?? false,
          );
        },
      ),
      GoRoute(
        path: '/lock',
        builder: (context, state) => const LockScreen(),
      ),
      GoRoute(
        path: '/vault',
        builder: (context, state) => const VaultScreen(),
      ),
      GoRoute(
        path: '/viewer',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ViewerScreen(
            assetId: extra?['assetId'],
            filePath: extra?['filePath'],
            title: extra?['title'] ?? '',
            isVaultItem: extra?['isVaultItem'] ?? false,
            vaultItemId: extra?['vaultItemId'],
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          GoRoute(
            path: '/albums',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/gallery',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/convert',
            builder: (context, state) => const SizedBox.shrink(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SizedBox.shrink(),
          ),
        ],
      ),
    ],
  );
});
