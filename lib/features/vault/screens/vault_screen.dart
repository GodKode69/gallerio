import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/vault_provider.dart';
import '../widgets/vault_grid.dart';
import '../widgets/vault_import_button.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  @override
  Widget build(BuildContext context) {
    final vaultState = ref.watch(vaultProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/gallery'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: _VaultSearchDelegate(ref),
              );
            },
          ),
        ],
      ),
      body: vaultState.isLoading && vaultState.filteredItems.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : VaultGrid(
              items: vaultState.filteredItems,
              onTap: (item) async {
                final file =
                    await ref.read(vaultProvider.notifier).decryptForViewing(item);
                if (file != null && context.mounted) {
                  context.push('/viewer', extra: {
                    'filePath': file.path,
                    'title': item.name,
                    'isVaultItem': true,
                    'vaultItemId': item.id,
                  });
                }
              },
              onDelete: (item) async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    insetPadding: const EdgeInsets.symmetric(horizontal: 40),
                    title: Row(
                      children: [
                        const Text('Remove from vault?'),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Remove',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ),
                );
                if (confirmed == true) {
                  await ref
                      .read(vaultProvider.notifier)
                      .deleteItem(item.id);
                }
              },
            ),
      floatingActionButton: const VaultImportButton(),
    );
  }
}

class _VaultSearchDelegate extends SearchDelegate<String> {
  final WidgetRef ref;
  Timer? _debounceTimer;

  _VaultSearchDelegate(this.ref);

  @override
  String get searchFieldLabel => 'Search vault...';

  @override
  TextStyle? get searchFieldStyle => const TextStyle(color: Colors.white);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    _debounceTimer?.cancel();
    ref.read(vaultProvider.notifier).search(query);
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(vaultProvider.notifier).search(query);
    });
    final vaultState = ref.watch(vaultProvider);

    if (vaultState.filteredItems.isEmpty) {
      return const Center(
        child: Text(
          'No results',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      itemCount: vaultState.filteredItems.length,
      itemBuilder: (context, index) {
        final item = vaultState.filteredItems[index];
        return ListTile(
          leading: const Icon(Icons.lock, color: Colors.white54),
          title: Text(item.name, style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            item.album,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          ),
          onTap: () => close(context, item.name),
        );
      },
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
