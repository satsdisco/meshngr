import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../providers/connection_provider.dart' as conn;

class ConnectionStatusDot extends StatelessWidget {
  final conn.ConnectionState state;
  final double size;

  const ConnectionStatusDot({super.key, required this.state, this.size = 8});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (state) {
      case conn.ConnectionState.connected:
        color = AppColors.success;
        break;
      case conn.ConnectionState.connecting:
      case conn.ConnectionState.scanning:
        color = AppColors.warning;
        break;
      case conn.ConnectionState.disconnected:
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
