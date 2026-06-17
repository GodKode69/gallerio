import 'package:flutter/material.dart';
import '../../app/theme.dart';

class ConfirmDeleteDialog extends StatelessWidget {
  final String title;
  final String confirmLabel;

  const ConfirmDeleteDialog({
    super.key,
    required this.title,
    this.confirmLabel = 'Delete',
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    String confirmLabel = 'Delete',
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDeleteDialog(
        title: title,
        confirmLabel: confirmLabel,
      ),
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      title: Row(
        children: [
          Text(title),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              confirmLabel,
              style: const TextStyle(color: AppColors.favoriteRed),
            ),
          ),
        ],
      ),
    );
  }
}
