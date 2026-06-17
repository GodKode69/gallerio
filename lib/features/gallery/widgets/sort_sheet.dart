import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../shared/widgets/bottom_sheet_drag_handle.dart';
import '../providers/gallery_provider.dart';

class SortSheet extends ConsumerWidget {
  const SortSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const SortSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSort = ref.watch(
      galleryProvider.select((s) => s.sortOrder),
    );

    final options = [
      (SortOrder.newest, 'Newest First', Icons.arrow_downward),
      (SortOrder.oldest, 'Oldest First', Icons.arrow_upward),
      (SortOrder.nameAsc, 'Name (A-Z)', Icons.sort_by_alpha),
      (SortOrder.nameDesc, 'Name (Z-A)', Icons.sort_by_alpha),
      (SortOrder.largest, 'Largest First', Icons.arrow_upward),
      (SortOrder.smallest, 'Smallest First', Icons.arrow_downward),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BottomSheetDragHandle(),
          const SizedBox(height: 20),
          const Text(
            'Sort By',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          for (final option in options)
            _SortOption(
              label: option.$2,
              icon: option.$3,
              isSelected: currentSort == option.$1,
              onTap: () {
                ref.read(galleryProvider.notifier).setSortOrder(option.$1);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? colorScheme.primary : AppColors.textSecondary,
        size: 20,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? colorScheme.primary : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: colorScheme.primary, size: 20)
          : null,
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
