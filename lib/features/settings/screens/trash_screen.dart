import 'dart:io';

import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/confirm_delete_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../core/trash/trash_service.dart';
import '../../../core/database/database.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => TrashScreenState();
}

class TrashScreenState extends State<TrashScreen> {
  final TrashService _trashService = TrashService();
  List<TrashItem> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  Future<void> _loadTrash() async {
    setState(() => _isLoading = true);
    final items = await _trashService.getTrashItems();
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _emptyTrash,
              tooltip: 'Empty trash',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const EmptyState(
                  icon: Icons.delete_outline,
                  message: 'Trash is empty',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final daysLeft = 30 -
                        DateTime.now().difference(item.deletedAt).inDays;
                    return Card(
                      color: AppColors.sheetBackground,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Image.file(
                              File(item.trashPath),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                item.mimeType == 'video'
                                    ? Icons.videocam
                                    : Icons.photo,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Deletes in $daysLeft days',
                          style: TextStyle(
                            color: daysLeft <= 3
                                ? AppColors.favoriteRed
                                : AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.restore,
                                  color: AppColors.textMuted),
                              onPressed: () => _restore(item),
                              tooltip: 'Restore',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_forever,
                                  color: AppColors.favoriteRed),
                              onPressed: () => _permanentDelete(item),
                              tooltip: 'Delete forever',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _restore(TrashItem item) async {
    final success = await _trashService.restoreFromTrash(item);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Restored' : 'Failed to restore'),
        ),
      );
      _loadTrash();
    }
  }

  Future<void> _permanentDelete(TrashItem item) async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Delete forever?',
    );

    if (confirmed) {
      await _trashService.permanentDelete(item);
      _loadTrash();
    }
  }

  Future<void> _emptyTrash() async {
    final confirmed = await ConfirmDeleteDialog.show(
      context,
      title: 'Empty trash?',
      confirmLabel: 'Empty',
    );

    if (confirmed) {
      await _trashService.emptyTrash();
      _loadTrash();
    }
  }
}
