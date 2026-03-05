import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/ble_service.dart';
import '../theme/app_theme.dart';

class BleDebugScreen extends StatelessWidget {
  const BleDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Debug Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              context.read<BleService>().debugLog.clear();
              (context as Element).markNeedsBuild();
            },
          ),
        ],
      ),
      body: Consumer<BleService>(
        builder: (context, ble, _) {
          if (ble.debugLog.isEmpty) {
            return const Center(
              child: Text('No BLE activity yet', style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(12),
            itemCount: ble.debugLog.length,
            itemBuilder: (context, index) {
              final log = ble.debugLog[ble.debugLog.length - 1 - index];
              final isError = log.contains('ERROR') || log.contains('BLOCKED');
              final isTx = log.contains('TX:');
              final isRx = log.contains('RX:');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  log,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: isError
                        ? AppColors.error
                        : isTx
                            ? AppColors.accent
                            : isRx
                                ? AppColors.success
                                : AppColors.textSecondary,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
