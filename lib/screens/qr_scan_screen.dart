import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/contact.dart';
import '../providers/chat_provider.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final raw = barcode.rawValue!;
    // Supported formats:
    // 1. meshcore://contact?key=HEX&name=NAME (our QR format)
    // 2. meshngr:ADDRESS:NAME
    // 3. Raw 64-char hex address
    String? address;
    String? name;

    if (raw.startsWith('meshcore://contact')) {
      final uri = Uri.tryParse(raw);
      if (uri != null) {
        address = uri.queryParameters['key'];
        name = uri.queryParameters['name'];
      }
    } else if (raw.startsWith('meshngr:')) {
      final parts = raw.split(':');
      if (parts.length >= 2) address = parts[1];
      if (parts.length >= 3) name = parts.sublist(2).join(':');
    } else if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(raw)) {
      address = raw;
    }

    if (address == null || address.length != 64) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid QR code — not a mesh contact')),
      );
      return;
    }

    _scanned = true;
    _controller.stop();

    final displayName = name ?? 'Node-${address.substring(0, 6)}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Add Contact?'),
        content: Text('Add "$displayName" to your contacts?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _scanned = false);
              _controller.start();
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final contact = Contact(
                id: address!,
                name: displayName,
                address: address,
                trustLevel: TrustLevel.saved,
                lastSeen: DateTime.now(),
              );
              context.read<ChatProvider>().addContact(contact, alias: name);
              Navigator.pop(ctx);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Added $displayName')),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accent, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Text(
              'Point at a meshngr QR code',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
