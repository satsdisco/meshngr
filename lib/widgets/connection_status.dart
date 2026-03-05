import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../core/ble_service.dart';

class ConnectionStatusDot extends StatelessWidget {
  final BleConnectionState state;
  final double size;

  const ConnectionStatusDot({super.key, required this.state, this.size = 8});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (state) {
      case BleConnectionState.connected:
        color = AppColors.success;
        break;
      case BleConnectionState.connecting:
      case BleConnectionState.scanning:
        color = AppColors.warning;
        break;
      case BleConnectionState.disconnected:
        color = AppColors.error;
        break;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4, spreadRadius: 1),
        ],
      ),
    );
  }
}
