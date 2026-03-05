import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../core/ble_service.dart';
import '../providers/chat_provider.dart';
import '../widgets/connection_status.dart';
import 'connection_screen.dart';
import 'broadcast_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                  subtitle: 'Enabled'),
              _SettingsTile(
                  icon: Icons.palette_outlined, title: 'Appearance', subtitle: 'Dark'),

              const SizedBox(height: 20),
              _SectionHeader(title: 'ABOUT'),
              _SettingsTile(icon: Icons.info_outline, title: 'meshngr', subtitle: 'v1.0.0'),
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
            ?trailing,
          ],
        ),
      ),
    );
  }
}
