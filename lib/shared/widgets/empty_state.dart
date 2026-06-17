import 'package:flutter/material.dart';
import '../../app/theme.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;
  final double iconSize;

  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.subtitle,
    this.iconSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: iconSize, color: AppColors.iconOverlay),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: subtitle != null ? 16 : 15,
              fontWeight: subtitle != null ? FontWeight.normal : FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: TextStyle(
                color: AppColors.textPrimary.withValues(alpha: 0.3),
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
