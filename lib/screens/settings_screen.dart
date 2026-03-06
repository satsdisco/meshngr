import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../core/ble_service.dart';
import '../providers/chat_provider.dart';
import '../widgets/connection_status.dart';
import 'connection_screen.dart';
import 'broadcast_screen.dart';
import 'ble_debug_screen.dart';
import '../core/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = NotificationService().enabled;

  String _statusText(BleService ble) {
    switch (ble.state) {
      case BleConnectionState.disconnected:
        return 'Disconnected';
      case BleConnectionState.scanning:
        return 'Scanning...';
      case BleConnectionState.connecting:
        return 'Connecting...';
      case BleConnectionState.connected:
        return 'Connected to ${ble.deviceName ?? "device"}';
    }
  }

  void _editDisplayName(BuildContext context, BleService ble) {
    final controller = TextEditingController(text: ble.selfInfo?.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Display Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter your name',
            hintStyle: const TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surfaceLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty && ble.isConnected) {
                ble.setName(name);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Name updated to "$name"')),
                );
              } else if (!ble.isConnected) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Connect your radio first'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<BleService>(
        builder: (context, ble, _) {
          final selfInfo = ble.selfInfo;
          final battery = ble.batteryPercent;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              _SectionHeader(title: 'RADIO'),
              _SettingsTile(
                icon: Icons.bluetooth,
                title: 'Connection',
                subtitle: _statusText(ble),
                leading: ConnectionStatusDot(state: ble.state),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ConnectionScreen())),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
              ),

              if (ble.isConnected && battery != null)
                _SettingsTile(
                  icon: Icons.battery_charging_full,
                  title: 'Battery',
                  subtitle: '$battery%',
                ),

              _SettingsTile(
                icon: Icons.cell_tower,
                title: 'Broadcast',
                subtitle: 'Make yourself visible on the mesh',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const BroadcastScreen())),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
              ),

              const SizedBox(height: 20),
              _SectionHeader(title: 'IDENTITY'),
              _SettingsTile(
                icon: Icons.person_outline,
                title: 'Display Name',
                subtitle: selfInfo?.name ??
                    (ble.isConnected ? ble.deviceName ?? 'Unknown' : 'Not connected'),
                onTap: () => _editDisplayName(context, ble),
                trailing: const Icon(Icons.edit_outlined, color: AppColors.textTertiary, size: 18),
              ),
              _SettingsTile(
                icon: Icons.fingerprint,
                title: 'Node Address',
                subtitle: selfInfo != null
                    ? '0x${selfInfo.publicKeyHex.substring(0, 8).toUpperCase()}...'
                    : 'Not connected',
              ),

              const SizedBox(height: 20),
              _SectionHeader(title: 'DEVICE'),
              _SettingsTile(
                icon: Icons.bluetooth_connected,
                title: 'Radio',
                subtitle: ble.isConnected
                    ? (ble.deviceName ?? 'MeshCore Radio')
                    : 'Not connected',
              ),

              const SizedBox(height: 20),
              _SectionHeader(title: 'APP'),
              Consumer<ChatProvider>(
                builder: (context, chat, _) => _SettingsTile(
                  icon: Icons.science_outlined,
                  title: 'Demo Mode',
                  subtitle: chat.demoMode
                      ? 'On — showing simulated data'
                      : 'Off — real radio data only',
                  trailing: Switch(
                    value: chat.demoMode,
                    onChanged: (val) {
                      if (val) {
                        chat.enableDemoMode();
                      } else {
                        chat.disableDemoMode();
                      }
                    },
                    activeColor: AppColors.accent,
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: _notificationsEnabled ? 'Enabled' : 'Disabled',
                trailing: Switch(
                  value: _notificationsEnabled,
                  onChanged: (val) => setState(() {
                    _notificationsEnabled = val;
                    NotificationService().enabled = val;
                  }),
                  activeColor: AppColors.accent,
                ),
              ),

              const SizedBox(height: 20),
              _SectionHeader(title: 'DEBUG'),
              _SettingsTile(
                icon: Icons.bug_report,
                title: 'BLE Debug Log',
                subtitle: '${ble.debugLog.length} entries',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BleDebugScreen())),
              ),

              _SettingsTile(
                icon: Icons.delete_forever,
                title: 'Clear All Data',
                subtitle: 'Wipe local DB — channels reload from radio',
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear All Data?'),
                      content: const Text('This removes all local data. Channels and contacts will reload from the radio.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await context.read<ChatProvider>().clearAllData();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data cleared — reconnect to reload')));
                    }
                  }
                },
              ),

              const SizedBox(height: 20),
              _SectionHeader(title: 'ABOUT'),
              _SettingsTile(icon: Icons.info_outline, title: 'meshngr', subtitle: 'v0.4.1'),
              _SettingsTile(
                icon: Icons.code,
                title: 'Source Code',
                subtitle: 'github.com/satsdisco/meshngr',
              ),
            ],
          );
        },
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(title, style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.2)),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ] else ...[
              Icon(icon, color: AppColors.textTertiary, size: 22),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
