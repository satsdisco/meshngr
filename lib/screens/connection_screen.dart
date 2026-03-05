import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../core/ble_service.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final ble = context.read<BleService>();
      if (!ble.isConnected && ble.state != BleConnectionState.scanning) {
        ble.startScan();
      }
    });
  }

  String _signalLabel(int rssi) {
    if (rssi > -50) return 'Excellent';
    if (rssi > -70) return 'Good';
    if (rssi > -85) return 'Fair';
    return 'Weak';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Radio'),
        actions: [
          Consumer<BleService>(
            builder: (context, ble, child) {
              if (ble.state == BleConnectionState.scanning) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Scan again',
                onPressed: () => ble.startScan(),
              );
            },
          ),
        ],
      ),
      body: Consumer<BleService>(
        builder: (context, ble, _) {
          return Column(
            children: [
              const SizedBox(height: 32),

              // Scanning / Connecting indicator
              if (ble.state == BleConnectionState.scanning ||
                  ble.state == BleConnectionState.connecting)
                Column(
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.accent,
                        backgroundColor: AppColors.surfaceLight,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      ble.state == BleConnectionState.connecting
                          ? 'Connecting...'
                          : 'Scanning for MeshCore radios...',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),

              // Connected card
              if (ble.state == BleConnectionState.connected)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.success, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Connected!',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: AppColors.success),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ble.deviceName ?? 'MeshCore Radio',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (ble.batteryPercent != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Battery: ${ble.batteryPercent}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          ble.disconnect();
                          Navigator.pop(context);
                        },
                        child: const Text('Disconnect',
                            style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                ),

              // No devices found
              if (ble.state == BleConnectionState.disconnected &&
                  ble.scanResults.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.bluetooth_disabled,
                          size: 56,
                          color: AppColors.textTertiary.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text('No radios found',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Make sure your MeshCore radio is powered on and nearby.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => ble.startScan(),
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('Scan Again'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),

              // Device list
              if (ble.scanResults.isNotEmpty &&
                  ble.state != BleConnectionState.connected)
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: ble.scanResults.length,
                    itemBuilder: (context, index) {
                      final result = ble.scanResults[index];
                      final name = result.device.platformName.isNotEmpty
                          ? result.device.platformName
                          : 'Unknown (${result.device.remoteId})';
                      final rssi = result.rssi;
                      final connectable = result.advertisementData.connectable;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.bluetooth,
                              color: connectable
                                  ? AppColors.accent
                                  : AppColors.textTertiary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  Text(
                                    '${_signalLabel(rssi)} ($rssi dBm)',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            if (connectable)
                              FilledButton(
                                onPressed: ble.state == BleConnectionState.connecting
                                    ? null
                                    : () => ble.connect(result.device),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 8),
                                ),
                                child: const Text('Connect'),
                              )
                            else
                              Text('Not available',
                                  style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
