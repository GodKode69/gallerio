import 'package:flutter/material.dart';

import '../features/auth/screens/pin_setup_screen.dart';
import '../features/auth/screens/lock_screen.dart';
import '../features/vault/screens/vault_screen.dart';
import '../features/viewer/screens/viewer_screen.dart';
import '../features/settings/screens/trash_screen.dart';
import 'shell_screen.dart';

class AppNavigator {
  AppNavigator._();

  static void goToGallery(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ShellScreen()),
      (route) => false,
    );
  }

  static void goToLock(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LockScreen()),
      (route) => false,
    );
  }

  static void goToSetup(BuildContext context, {bool changeMode = false}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PinSetupScreen(changeMode: changeMode),
    ));
  }

  static void goToVault(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const VaultScreen(),
    ));
  }

  static void goToTrash(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const TrashScreen(),
    ));
  }

  static void goToViewer(
    BuildContext context, {
    String? assetId,
    String? filePath,
    String title = '',
    bool isVaultItem = false,
    int? vaultItemId,
    List<String>? assetIds,
    int initialIndex = 0,
  }) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ViewerScreen(
        assetId: assetId,
        filePath: filePath,
        title: title,
        isVaultItem: isVaultItem,
        vaultItemId: vaultItemId,
        assetIds: assetIds,
        initialIndex: initialIndex,
      ),
    ));
  }

  static bool canPop(BuildContext context) {
    return Navigator.of(context).canPop();
  }

  static void pop(BuildContext context) {
    Navigator.of(context).pop();
  }
}
