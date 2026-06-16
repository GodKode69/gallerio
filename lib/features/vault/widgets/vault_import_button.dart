import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../providers/vault_provider.dart';

class VaultImportButton extends ConsumerWidget {
  const VaultImportButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.extended(
      onPressed: () => _importFiles(context, ref),
      icon: const Icon(Icons.add),
      label: const Text('Import'),
    );
  }

  Future<void> _importFiles(BuildContext context, WidgetRef ref) async {
    final hasPermission = await Permission.photos.request();
    if (!hasPermission.isGranted && !hasPermission.isLimited) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission required to import files')),
        );
      }
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;

    if (!context.mounted) return;

    final validFiles = result.files.where((f) => f.path != null).toList();
    if (validFiles.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Importing ${validFiles.length} file(s)...'),
      ),
    );

    final paths = validFiles.map((f) => f.path!).toList();
    await ref.read(vaultProvider.notifier).importFiles(
      filePaths: paths,
      assetInfo: {
        'name': validFiles.first.name,
        'mimeType': validFiles.first.extension ?? '',
        'size': validFiles.fold<int>(0, (sum, f) => sum + f.size),
        'album': 'Imported',
      },
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import complete')),
      );
    }
  }
}
