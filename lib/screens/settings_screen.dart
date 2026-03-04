import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/connection_provider.dart' as conn;
import '../widgets/connection_status.dart';
import 'connection_screen.dart';
import 'broadcast_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<conn.ConnectionProvider>(
        builder: (context, cp, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              _SectionHeader(title: 'RADIO'),
              _SettingsTile(
                icon: Icons.bluetooth,
                title: 'Connection',
                subtitle: cp.statusText,
                leading: ConnectionStatusDot(state: cp.state),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectionScreen())),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
              ),

              _SettingsTile(
                icon: Icons.cell_tower,
                title: 'Broadcast',
                subtitle: 'Make yourself visible on the mesh',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BroadcastScreen())),
                trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
              ),

              const SizedBox(height: 20),
              _SectionHeader(title: 'IDENTITY'),
              _SettingsTile(icon: Icons.person_outline, title: 'Display Name', subtitle: 'MeshUser-42'),
              _SettingsTile(icon: Icons.fingerprint, title: 'Node Address', subtitle: '0xABCDEF'),

              const SizedBox(height: 20),
              _SectionHeader(title: 'DEVICE'),
              _SettingsTile(icon: Icons.memory, title: 'Firmware', subtitle: 'MeshCore v2.1.0'),
              _SettingsTile(icon: Icons.radio, title: 'Frequency', subtitle: '868 MHz (EU)'),
              _SettingsTile(icon: Icons.speed, title: 'TX Power', subtitle: '20 dBm'),

              const SizedBox(height: 20),
              _SectionHeader(title: 'APP'),
              _SettingsTile(icon: Icons.notifications_outlined, title: 'Notifications', subtitle: 'Enabled'),
              _SettingsTile(icon: Icons.palette_outlined, title: 'Appearance', subtitle: 'Dark'),

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
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
