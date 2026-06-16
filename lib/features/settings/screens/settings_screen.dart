import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/providers/auth_provider.dart';

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
            subtitle: 'Version 1.0.0',
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
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white)),
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
              color: Colors.white.withValues(alpha: 0.3))
          : null,
      onTap: onTap,
    );
  }
}

class _BiometricToggle extends ConsumerWidget {
  const _BiometricToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final notifier = ref.read(authStateProvider.notifier);

    return SwitchListTile(
      secondary: const Icon(Icons.fingerprint, color: Colors.white70),
      title: const Text('Biometric Login',
          style: TextStyle(color: Colors.white)),
      subtitle: Text(
        'Use fingerprint or face to unlock',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 12,
        ),
      ),
      value: authState.isBiometricEnabled,
      onChanged: (value) async {
        await notifier.setBiometricEnabled(value);
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
      onTap: () => _showTrashDialog(context),
    );
  }

  void _showTrashDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Trash'),
        content: const Text(
          'Deleted items are kept for 30 days before being permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
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
              const Icon(Icons.shield_outlined, color: Colors.white70),
          title: const Text('Vault Security',
              style: TextStyle(color: Colors.white)),
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
