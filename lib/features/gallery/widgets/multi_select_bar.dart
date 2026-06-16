import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/gallery_provider.dart';
import '../../../core/database/database.dart';
import '../../../core/encryption/encryption_service.dart';
import '../../../core/security/security_service.dart';
import '../../../core/trash/trash_service.dart';
import 'package:drift/drift.dart' as drift;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'dart:convert';

class MultiSelectBar extends ConsumerWidget {
  const MultiSelectBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCount = ref.watch(
      galleryProvider.select((s) => s.selectedCount),
    );
    final isSelectionMode = ref.watch(
      galleryProvider.select((s) => s.isSelectionMode),
    );

    if (!isSelectionMode || selectedCount == 0) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(
          top: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () {
              ref.read(galleryProvider.notifier).exitSelectionMode();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '$selectedCount',
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          _ActionButton(
            icon: Icons.select_all,
            label: 'All',
            onTap: () => ref.read(galleryProvider.notifier).selectAll(),
          ),
          _ActionButton(
            icon: Icons.share,
            label: 'Share',
            onTap: () => _shareSelected(ref),
          ),
          _ActionButton(
            icon: Icons.delete_outline,
            label: 'Delete',
            onTap: () => _deleteSelected(context, ref),
          ),
          _ActionButton(
            icon: Icons.lock,
            label: 'Vault',
            onTap: () => _moveToVault(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _shareSelected(WidgetRef ref) async {
    final assets = ref.read(galleryProvider.notifier).selectedAssets;
    final paths = <String>[];

    for (final asset in assets) {
      final file = await asset.file;
      if (file != null) paths.add(file.path);
    }

    if (paths.isNotEmpty) {
      await Share.shareXFiles(
        paths.map((p) => XFile(p)).toList(),
        text: '${paths.length} items',
      );
    }

    ref.read(galleryProvider.notifier).exitSelectionMode();
  }

  Future<void> _deleteSelected(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        title: Row(
          children: [
            const Text('Delete Items?'),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final assets = ref.read(galleryProvider.notifier).selectedAssets;
      try {
        await TrashService().deleteMultipleWithTrash(assets);
      } catch (_) {}
      ref.read(galleryProvider.notifier).exitSelectionMode();
      ref.read(galleryProvider.notifier).refresh();
    }
  }

  Future<void> _moveToVault(BuildContext context, WidgetRef ref) async {
    final assets = ref.read(galleryProvider.notifier).selectedAssets;

    try {
      final security = SecurityService();
      final encryption = EncryptionService();

      var key = await security.getVaultKey();
      if (key == null) {
        key = await encryption.generateKey();
        await security.setVaultKey(key);
      }

      final appDir = await getApplicationDocumentsDirectory();
      final vaultDir = Directory(p.join(appDir.path, 'vault'));
      if (!await vaultDir.exists()) {
        await vaultDir.create(recursive: true);
      }

      final db = GallerioDatabase();
      int count = 0;

      for (final asset in assets) {
        final file = await asset.file;
        if (file == null) continue;

        final encryptedName = encryption.generateEncryptedName();
        final encryptedPath = p.join(vaultDir.path, '$encryptedName.enc');

        final outputFile = File(encryptedPath);
        await encryption.encryptFile(
          inputFile: file,
          key: key,
          outputFile: outputFile,
        );

        final nonce = await encryption.getLastNonce();
        final name = asset.title ?? 'Photo';

        await db.insertVaultItem(VaultItemsCompanion.insert(
          name: name,
          encryptedPath: encryptedPath,
          originalName: drift.Value(name),
          mimeType: drift.Value(asset.type == AssetType.video ? 'video' : 'image'),
          size: const drift.Value(0),
          album: const drift.Value('Imported'),
          iv: base64Encode(nonce),
        ));
        count++;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count items moved to vault')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to move to vault: $e')),
        );
      }
    }

    ref.read(galleryProvider.notifier).exitSelectionMode();
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
