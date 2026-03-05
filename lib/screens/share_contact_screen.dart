import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import '../core/ble_service.dart';
import 'qr_scan_screen.dart';

/// Shows your QR code so others can scan and add you as a contact
class ShareContactScreen extends StatelessWidget {
  const ShareContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan QR',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrScanScreen())),
          ),
        ],
      ),
      body: Consumer<BleService>(
        builder: (context, ble, _) {
          final selfInfo = ble.selfInfo;
          final name = selfInfo?.name ?? ble.deviceName ?? 'Unknown';
          final pubKeyHex = selfInfo?.publicKeyHex ?? '';

          if (pubKeyHex.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bluetooth_disabled, size: 48, color: AppColors.textTertiary.withValues(alpha: 0.4)),
                    const SizedBox(height: 16),
                    Text('Connect your radio first', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Text(
                      'Your QR code will be generated from your radio\'s identity.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary),
                    ),
                  ],
                ),
              ),
            );
          }

          // QR data format: meshcore://contact?key=<pubKeyHex>&name=<name>
          // Use the standard MeshCore QR format for cross-app compatibility
          final qrData = 'meshcore://contact/add?name=${Uri.encodeComponent(name)}&public_key=$pubKeyHex&type=1';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(name, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 32),

                // QR Code
                UnconstrainedBox(
                  child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(color: Colors.black, eyeShape: QrEyeShape.square),
                    dataModuleStyle: const QrDataModuleStyle(color: Colors.black, dataModuleShape: QrDataModuleShape.square),
                  ),
                ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Show this to someone nearby.\nThey can scan it to add you as a contact.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 24),

                // Copy key button
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: pubKeyHex));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Public key copied to clipboard')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy Public Key'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  pubKeyHex.length > 16
                      ? '${pubKeyHex.substring(0, 8)}...${pubKeyHex.substring(pubKeyHex.length - 8)}'
                      : pubKeyHex,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
