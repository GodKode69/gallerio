import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:io';
import '../../../app/theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/trash/trash_service.dart';
import '../../../core/database/database.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader(title: 'Security'),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: authState.isPinSet ? 'Change PIN' : 'Set PIN',
            subtitle: authState.isPinSet
                ? 'PIN is set'
                : 'Protect your app with a PIN',
            onTap: () => context.push('/setup', extra: {
              'changeMode': authState.isPinSet,
            }),
          ),
          if (authState.isPinSet)
            _SettingsTile(
              icon: Icons.lock_open,
              title: 'Remove PIN',
              subtitle: 'Disable PIN protection',
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Remove PIN?'),
                    content: const Text(
                        'This will remove PIN protection from your vault.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  ref.read(authStateProvider.notifier).removePin();
                }
              },
            ),
          const _BiometricToggle(),
          const _SectionHeader(title: 'Vault'),
          const _VaultSecurityToggle(),
          const _SectionHeader(title: 'Trash'),
          const _TrashBin(),
          const _SectionHeader(title: 'About'),
          const _SettingsTile(
            icon: Icons.info_outline,
            title: 'Gallerio',
            subtitle: 'Version 1.0.3',
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textMuted),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            )
          : null,
      trailing: onTap != null
          ? Icon(Icons.chevron_right,
              color: AppColors.textPrimary.withValues(alpha: 0.3))
          : null,
      onTap: onTap,
    );
  }
}

class _BiometricToggle extends ConsumerStatefulWidget {
  const _BiometricToggle();

  @override
  ConsumerState<_BiometricToggle> createState() => _BiometricToggleState();
}

class _BiometricToggleState extends ConsumerState<_BiometricToggle> {
  final _localAuth = LocalAuthentication();

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final notifier = ref.read(authStateProvider.notifier);

    return SwitchListTile(
      secondary: const Icon(Icons.fingerprint, color: AppColors.textMuted),
      title: const Text('Biometric Login',
          style: TextStyle(color: AppColors.textPrimary)),
      subtitle: Text(
        'Use fingerprint or face to unlock',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 12,
        ),
      ),
      value: authState.isBiometricEnabled,
      onChanged: (value) async {
        if (value) {
          try {
            final canAuth = await _localAuth.canCheckBiometrics;
            if (!canAuth) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Biometric not available on this device')),
                );
              }
              return;
            }

            final authenticated = await _localAuth.authenticate(
              localizedReason: 'Authenticate to enable biometric login',
              options: const AuthenticationOptions(
                stickyAuth: true,
                biometricOnly: false,
              ),
            );

            if (!authenticated) return;

            await notifier.setBiometricEnabled(true);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Biometric error: $e')),
              );
            }
          }
        } else {
          await notifier.setBiometricEnabled(false);
        }
      },
    );
  }
}

class _TrashBin extends ConsumerWidget {
  const _TrashBin();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsTile(
      icon: Icons.delete_outline,
      title: 'Trash',
      subtitle: 'View deleted items',
      onTap: () => _openTrashScreen(context),
    );
  }

  void _openTrashScreen(BuildContext context) {
    context.push('/trash');
  }
}

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
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline,
                            size: 64, color: AppColors.iconOverlay),
                        SizedBox(height: 16),
                        Text(
                          'Trash is empty',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                        ),
                      ],
                    ),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Delete forever?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.favoriteRed)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _trashService.permanentDelete(item);
      _loadTrash();
    }
  }

  Future<void> _emptyTrash() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Empty trash?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Empty', style: TextStyle(color: AppColors.favoriteRed)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _trashService.emptyTrash();
      _loadTrash();
    }
  }
}

class _VaultSecurityToggle extends ConsumerWidget {
  const _VaultSecurityToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final notifier = ref.read(authStateProvider.notifier);

    return Column(
      children: [
        SwitchListTile(
          secondary:
              const Icon(Icons.shield_outlined, color: AppColors.textMuted),
          title: const Text('Vault Security',
              style: TextStyle(color: AppColors.textPrimary)),
          subtitle: Text(
            'Require vault code in search to access hidden vault',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          value: authState.isVaultEnabled,
          onChanged: (value) async {
            if (value && !authState.hasVaultCode) {
              final code = await _showVaultCodeDialog(
                context,
                title: 'Set Vault Code',
                hint: 'Enter a secret word/phrase (min 3 chars)',
              );
              if (code != null && code.isNotEmpty) {
                await notifier.setVaultCode(code);
                await notifier.setVaultEnabled(true);
              }
            } else if (value && authState.hasVaultCode) {
              await notifier.setVaultEnabled(true);
            } else {
              await notifier.setVaultEnabled(false);
            }
          },
        ),
        if (authState.isVaultEnabled)
          _SettingsTile(
            icon: Icons.vpn_key_outlined,
            title: 'Change Vault Code',
            onTap: () async {
              final newCode = await _showChangeVaultCodeFlow(context, ref);
              if (newCode != null && newCode.isNotEmpty) {
                await notifier.setVaultCode(newCode);
              }
            },
          ),
      ],
    );
  }

  Future<String?> _showVaultCodeDialog(
    BuildContext context, {
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.length < 3) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Code must be at least 3 characters')),
                );
                return;
              }
              Navigator.pop(context, controller.text);
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  Future<String?> _showChangeVaultCodeFlow(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(authStateProvider.notifier);
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    final verified = await showDialog<bool>(
      context: context,
      builder: (context) {
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Verify Current Vault Code'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: oldController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Enter current vault code',
                      errorText: error,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    final ok = await notifier.verifyVaultCode(oldController.text);
                    if (!context.mounted) return;
                    if (ok) {
                      Navigator.pop(context, true);
                    } else {
                      setDialogState(() {
                        error = 'Incorrect vault code';
                      });
                    }
                  },
                  child: const Text('Verify'),
                ),
              ],
            );
          },
        );
      },
    );

    if (verified != true) return null;

    if (!context.mounted) return null;

    return await showDialog<String>(
      context: context,
      builder: (context) {
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Set New Vault Code'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: newController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Enter new vault code',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmController,
                    decoration: InputDecoration(
                      hintText: 'Confirm new vault code',
                      errorText: error,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    if (newController.text.length < 3) {
                      setDialogState(() {
                        error = 'Code must be at least 3 characters';
                      });
                    } else if (newController.text != confirmController.text) {
                      setDialogState(() {
                        error = 'Codes do not match';
                      });
                    } else {
                      Navigator.pop(context, newController.text);
                    }
                  },
                  child: const Text('Set'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
