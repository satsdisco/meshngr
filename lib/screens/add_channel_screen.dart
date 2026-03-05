import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../core/ble_service.dart';
import '../providers/chat_provider.dart';

/// Well-known public channel PSK (same across all MeshCore devices)
const String publicChannelPskHex = '8b3387e9c5cdea6ac9e5edbaa115cd72';

Uint8List _hexToBytes(String hex) {
  final cleaned = hex.replaceAll(' ', '');
  final bytes = Uint8List(cleaned.length ~/ 2);
  for (int i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

/// Derive PSK from hashtag name: first 16 bytes of SHA256("#name")
Uint8List derivePskFromHashtag(String hashtag) {
  final name = hashtag.startsWith('#') ? hashtag : '#$hashtag';
  final hash = sha256.convert(utf8.encode(name)).bytes;
  return Uint8List.fromList(hash.sublist(0, 16));
}

class AddChannelScreen extends StatelessWidget {
  const AddChannelScreen({super.key});

  int _findNextSlot(ChatProvider cp) {
    final usedIndices = <int>{};
    for (final ch in cp.channels) {
      // Extract index from id like "radio_ch_0"
      final match = RegExp(r'radio_ch_(\d+)').firstMatch(ch.id);
      if (match != null) usedIndices.add(int.parse(match.group(1)!));
    }
    for (int i = 0; i < 8; i++) {
      if (!usedIndices.contains(i)) return i;
    }
    return -1; // All slots full
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Channel')),
      body: Consumer2<BleService, ChatProvider>(
        builder: (context, ble, cp, _) {
          final nextSlot = _findNextSlot(cp);
          final slotsFull = nextSlot == -1;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Info banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: AppColors.accent.withValues(alpha: 0.8)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Channels are encrypted group conversations across the mesh. You need the same key to send and receive messages.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (slotsFull) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, size: 20, color: AppColors.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'All 8 channel slots are full. Remove a channel first to add a new one.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              Text('${cp.channels.length}/8 channels used', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),

              _OptionTile(
                icon: Icons.add,
                title: 'Create a Private Channel',
                subtitle: 'Secured with a random secret key.',
                enabled: !slotsFull && ble.isConnected,
                onTap: () => _createPrivateChannel(context, ble, nextSlot),
              ),
              const SizedBox(height: 8),
              _OptionTile(
                icon: Icons.lock_outline,
                title: 'Join a Private Channel',
                subtitle: 'Enter a secret key shared with you.',
                enabled: !slotsFull && ble.isConnected,
                onTap: () => _joinPrivateChannel(context, ble, nextSlot),
              ),
              const SizedBox(height: 8),
              _OptionTile(
                icon: Icons.public,
                title: 'Join the Public Channel',
                subtitle: 'Anyone on the mesh can join.',
                enabled: !slotsFull && ble.isConnected,
                onTap: () => _joinPublicChannel(context, ble, nextSlot),
              ),
              const SizedBox(height: 8),
              _OptionTile(
                icon: Icons.tag,
                title: 'Join a Hashtag Channel',
                subtitle: 'Type any name — anyone with the same name can chat.',
                enabled: !slotsFull && ble.isConnected,
                onTap: () => _joinHashtagChannel(context, ble, nextSlot),
              ),

              if (!ble.isConnected) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bluetooth_disabled, size: 16, color: AppColors.warning.withValues(alpha: 0.7)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Connect your radio first to manage channels.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.warning.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _createPrivateChannel(BuildContext context, BleService ble, int slot) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Create Private Channel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'A random encryption key will be generated. Share it with people you want to invite.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Channel name',
                hintText: 'e.g. Family Chat',
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              maxLength: 20,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              // Generate random 16-byte PSK
              final random = Random.secure();
              final psk = Uint8List(16);
              for (int i = 0; i < 16; i++) psk[i] = random.nextInt(256);
              Navigator.pop(ctx);
              ble.setChannel(slot, name, psk);
              _showSuccess(context, name, pskHex: psk.map((b) => b.toRadixString(16).padLeft(2, '0')).join());
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _joinPrivateChannel(BuildContext context, BleService ble, int slot) {
    final nameController = TextEditingController();
    final pskController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Join Private Channel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the channel name and the secret key someone shared with you.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Channel name',
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              maxLength: 20,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: pskController,
              style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Secret key (32 hex characters)',
                hintText: 'e.g. 8b3387e9c5cdea6ac9e5edbaa115cd72',
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              maxLength: 32,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final pskHex = pskController.text.trim();
              if (name.isEmpty || pskHex.length != 32) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a name and 32-character hex key')),
                );
                return;
              }
              try {
                final psk = _hexToBytes(pskHex);
                Navigator.pop(ctx);
                ble.setChannel(slot, name, psk);
                _showSuccess(context, name);
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid hex key')),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _joinPublicChannel(BuildContext context, BleService ble, int slot) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Join Public Channel'),
        content: Text(
          'The Public channel uses a well-known key that all MeshCore devices share. Anyone on the mesh can read and send messages here.',
          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final psk = _hexToBytes(publicChannelPskHex);
              Navigator.pop(ctx);
              ble.setChannel(slot, 'Public', psk);
              _showSuccess(context, 'Public');
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _joinHashtagChannel(BuildContext context, BleService ble, int slot) {
    final hashtagController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Join Hashtag Channel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Type any name — the encryption key is automatically derived from it. Anyone who types the same name joins the same channel.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: hashtagController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
              decoration: InputDecoration(
                prefixText: '# ',
                prefixStyle: TextStyle(color: AppColors.accent, fontSize: 18, fontWeight: FontWeight.w700),
                hintText: 'e.g. prague-mesh',
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              maxLength: 20,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final hashtag = hashtagController.text.trim();
              if (hashtag.isEmpty) return;
              final psk = derivePskFromHashtag(hashtag);
              Navigator.pop(ctx);
              ble.setChannel(slot, '#$hashtag', psk);
              _showSuccess(context, '#$hashtag');
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _showSuccess(BuildContext context, String name, {String? pskHex}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Channel "$name" added ✓')),
    );
    if (pskHex != null) {
      // Show the PSK so user can share it
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Share This Key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share this secret key with people you want to invite to "$name":',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  pskHex,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
    Navigator.pop(context); // Pop the AddChannel screen
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.4,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.3)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
