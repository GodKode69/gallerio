import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/screens/pin_setup_screen.dart';
import '../features/auth/screens/lock_screen.dart';
import '../features/vault/screens/vault_screen.dart';
import '../features/viewer/screens/viewer_screen.dart';
import '../features/settings/screens/trash_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import 'shell_screen.dart';

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(this._ref) {
    _ref.listen<AuthState>(authStateProvider, (_, _) => notifyListeners());
  }
  final Ref _ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/gallery',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isPinSet = authState.isPinSet;
      final isUnlocked = authState.isUnlocked;
      final isLoading = authState.isLoading;
      final goingToLock = state.matchedLocation == '/lock';
      final goingToSetup = state.matchedLocation == '/setup';
      final goingToViewer = state.matchedLocation == '/viewer';

      if (isLoading) return null;

      if (isPinSet && !isUnlocked && !goingToLock && !goingToSetup && !goingToViewer) {
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
        path: '/trash',
        builder: (context, state) => const TrashScreen(),
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
            assetIds: extra?['assetIds'] != null
                ? List<String>.from(extra!['assetIds'])
                : null,
            initialIndex: extra?['initialIndex'] ?? 0,
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
