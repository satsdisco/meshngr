class BleDevice {
  final String id;
  final String name;
  final int rssi;
  final bool isConnectable;

  const BleDevice({
    required this.id,
    required this.name,
    required this.rssi,
    this.isConnectable = true,
  });

  String get signalLabel {
    if (rssi > -50) return 'Excellent';
    if (rssi > -70) return 'Good';
    if (rssi > -85) return 'Fair';
    return 'Weak';
  }
}
