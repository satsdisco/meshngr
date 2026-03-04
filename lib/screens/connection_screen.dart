import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/connection_provider.dart' as conn;

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
      context.read<conn.ConnectionProvider>().startScan();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect Radio')),
      body: Consumer<conn.ConnectionProvider>(
        builder: (context, connectionProvider, _) {
          return Column(
            children: [
              const SizedBox(height: 32),
              // Scanning indicator
              if (connectionProvider.state == conn.ConnectionState.scanning ||
                  connectionProvider.state == conn.ConnectionState.connecting)
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
                      connectionProvider.state == conn.ConnectionState.connecting
                          ? 'Connecting...'
                          : 'Scanning for radios...',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),

              if (connectionProvider.state == conn.ConnectionState.connected)
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.success),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        connectionProvider.connectedDevice?.name ?? '',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          connectionProvider.disconnect();
                          Navigator.pop(context);
                        },
                        child: const Text('Disconnect', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                ),

              // Device list
              if (connectionProvider.discoveredDevices.isNotEmpty &&
                  connectionProvider.state != conn.ConnectionState.connected)
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: connectionProvider.discoveredDevices.length,
                    itemBuilder: (context, index) {
                      final device = connectionProvider.discoveredDevices[index];
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
                              color: device.isConnectable ? AppColors.accent : AppColors.textTertiary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(device.name, style: Theme.of(context).textTheme.titleMedium),
                                  Text(
                                    '${device.signalLabel} (${device.rssi} dBm)',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            if (device.isConnectable)
                              FilledButton(
                                onPressed: () => connectionProvider.connect(device),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                ),
                                child: const Text('Connect'),
                              )
                            else
                              Text('Not available', style: Theme.of(context).textTheme.bodySmall),
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
