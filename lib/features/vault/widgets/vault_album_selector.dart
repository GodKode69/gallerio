import 'package:flutter/material.dart';

class VaultAlbumSelector extends StatelessWidget {
  final List<String> albums;
  final String? currentAlbum;
  final bool isOpen;
  final VoidCallback onToggle;
  final void Function(String album) onAlbumSelected;
  final VoidCallback onShowAll;

  const VaultAlbumSelector({
    super.key,
    required this.albums,
    required this.currentAlbum,
    required this.isOpen,
    required this.onToggle,
    required this.onAlbumSelected,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    currentAlbum ?? 'All Vault Items',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                ListTile(
                  dense: true,
                  title: Text(
                    'All Vault Items',
                    style: TextStyle(
                      color: currentAlbum == null
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white,
                      fontWeight: currentAlbum == null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  onTap: onShowAll,
                ),
                for (final album in albums)
                  ListTile(
                    dense: true,
                    title: Text(
                      album,
                      style: TextStyle(
                        color: currentAlbum == album
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white,
                        fontWeight: currentAlbum == album
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () => onAlbumSelected(album),
                  ),
              ],
            ),
          ),
          crossFadeState:
              isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        const Divider(height: 1, color: Colors.white12),
      ],
    );
  }
}
