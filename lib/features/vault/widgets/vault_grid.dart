import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../core/database/database.dart';

class VaultGrid extends StatelessWidget {
  final List<VaultItem> items;
  final void Function(VaultItem item) onTap;
  final void Function(VaultItem item)? onDelete;

  const VaultGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 80,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'Vault is empty',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap + to import files',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _VaultItemTile(
          item: item,
          onTap: () => onTap(item),
          onDelete: onDelete != null ? () => onDelete!(item) : null,
        );
      },
    );
  }
}

class _VaultItemTile extends StatefulWidget {
  final VaultItem item;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _VaultItemTile({
    required this.item,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<_VaultItemTile> createState() => _VaultItemTileState();
}

class _VaultItemTileState extends State<_VaultItemTile> {
  late final bool _hasThumbnail;
  late final bool _hasEncryptedPath;

  @override
  void initState() {
    super.initState();
    _hasThumbnail = widget.item.thumbnailPath != null &&
        File(widget.item.thumbnailPath!).existsSync();
    _hasEncryptedPath = widget.item.mimeType.contains('image') &&
        File(widget.item.encryptedPath).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onDelete != null
          ? () async {
              final confirmed = await ConfirmDeleteDialog.show(
                context,
                title: 'Remove from vault?',
                confirmLabel: 'Remove',
              );
              if (confirmed) {
                widget.onDelete?.call();
              }
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_hasThumbnail)
              ClipRect(
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Image.file(
                    File(item.thumbnailPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(
                          _getIconForMime(item.mimeType),
                          color: Colors.white24,
                          size: 40,
                        ),
                      );
                    },
                  ),
                ),
              )
            else if (_hasEncryptedPath)
              ClipRect(
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Image.file(
                    File(item.encryptedPath),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(
                          _getIconForMime(item.mimeType),
                          color: Colors.white24,
                          size: 40,
                        ),
                      );
                    },
                  ),
                ),
              )
            else
              Center(
                child: Icon(
                  _getIconForMime(item.mimeType),
                  color: Colors.white24,
                  size: 40,
                ),
              ),
            if (item.isFavorite)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  Icons.star,
                  color: Colors.amber[600],
                  size: 18,
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForMime(String mimeType) {
    if (mimeType.contains('video')) return Icons.videocam;
    if (mimeType.contains('image')) return Icons.image;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    return Icons.insert_drive_file;
  }
}
