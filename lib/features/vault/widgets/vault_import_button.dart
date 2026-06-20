import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:isolate';
import '../../../app/theme.dart';
import '../../../shared/widgets/bottom_sheet_drag_handle.dart';
import '../providers/vault_provider.dart';

class VaultImportButton extends ConsumerWidget {
  const VaultImportButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.extended(
      onPressed: () => _showImportOptions(context, ref),
      icon: const Icon(Icons.add),
      label: const Text('Import'),
    );
  }

  void _showImportOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BottomSheetDragHandle(),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.textMuted),
              title: const Text('Pick Files',
                  style: TextStyle(color: Colors.white)),
              subtitle: Text(
                'Select individual files',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _importFiles(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder, color: AppColors.textMuted),
              title: const Text('Pick Folder',
                  style: TextStyle(color: Colors.white)),
              subtitle: Text(
                'Import all images/videos in a folder',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _importFolder(context, ref);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _importFiles(BuildContext context, WidgetRef ref) async {
    final photosStatus = await Permission.photos.request();
    final videosStatus = await Permission.videos.request();
    final hasPermission = (photosStatus.isGranted || photosStatus.isLimited) ||
        (videosStatus.isGranted || videosStatus.isLimited);
    if (!hasPermission) {
      final storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission required to import files')),
          );
        }
        return;
      }
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

    final allPaths = validFiles.map((f) => f.path!).toList();
    await ref.read(vaultProvider.notifier).importFiles(
      filePaths: allPaths,
      assetInfo: {
        'name': 'Imported',
        'mimeType': 'mixed',
        'size': 0,
        'album': 'Imported',
      },
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import complete')),
      );
    }
  }

  Future<void> _importFolder(BuildContext context, WidgetRef ref) async {
    final photosStatus = await Permission.photos.request();
    final videosStatus = await Permission.videos.request();
    final hasPermission = (photosStatus.isGranted || photosStatus.isLimited) ||
        (videosStatus.isGranted || videosStatus.isLimited);
    if (!hasPermission) {
      final storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission required to import files')),
          );
        }
        return;
      }
    }

    final directoryPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select folder to import',
    );

    if (directoryPath == null) return;

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scanning folder...')),
    );

    List<File> files;
    try {
      files = await Isolate.run(() {
        final directory = Directory(directoryPath);
        const imageVideoExtensions = {
          'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif',
          'mp4', 'mov', 'avi', 'mkv', 'webm', '3gp',
        };
        return directory
            .listSync()
            .whereType<File>()
            .where((file) {
              final ext = file.path.split('.').last.toLowerCase();
              return imageVideoExtensions.contains(ext);
            })
            .toList()
          ..sort((a, b) {
            final aStat = a.statSync();
            final bStat = b.statSync();
            return bStat.modified.compareTo(aStat.modified);
          });
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access folder: $e')),
        );
      }
      return;
    }

    if (files.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No images or videos found in folder')),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Importing ${files.length} file(s)...'),
        ),
      );
    }

    final paths = files.map((f) => f.path).toList();
    await ref.read(vaultProvider.notifier).importFiles(
      filePaths: paths,
      assetInfo: {
        'name': directoryPath.split('/').last,
        'mimeType': 'mixed',
        'size': 0,
        'album': directoryPath.split('/').last,
      },
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import complete')),
      );
    }
  }
}
