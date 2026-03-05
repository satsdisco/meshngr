import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/contact.dart';
import '../providers/chat_provider.dart';
import '../core/ble_service.dart';
import '../core/protocol.dart';

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
    // 1. meshcore://<hex> (ref app export format — contact frame as hex)
    // 2. meshcore://contact?key=HEX&name=NAME (our URL format)
    // 3. Raw 64-char hex address
    String? address;
    String? name;
    String? rawContactHex; // Full contact frame hex for radio import

    if (raw.startsWith('meshcore://contact')) {
      // Format: meshcore://contact/add?name=X&public_key=HEX&type=N
      // or: meshcore://contact?key=HEX&name=X
      final uri = Uri.tryParse(raw);
      if (uri != null) {
        address = uri.queryParameters['public_key'] ?? uri.queryParameters['key'];
        name = uri.queryParameters['name'];
      }
    } else if (raw.startsWith('meshcore://')) {
      // Reference app format: meshcore:// + hex-encoded contact frame
      // Contact frame: [pubkey x32][adv_type][flags][pathLen][path x64][name x32][timestamp x4][lat x4][lon x4][lastmod x4]
      final hex = raw.substring('meshcore://'.length).trim();
      if (hex.length >= 64) {
        rawContactHex = hex;
        // First 32 bytes (64 hex chars) = public key
        address = hex.substring(0, 64);
        // Name is at byte offset 99 (hex offset 198), 32 bytes max
        if (hex.length >= 198 + 2) {
          final nameHex = hex.substring(198, (198 + 64).clamp(0, hex.length));
          final nameBytes = <int>[];
          for (int i = 0; i < nameHex.length - 1; i += 2) {
            final b = int.tryParse(nameHex.substring(i, i + 2), radix: 16) ?? 0;
            if (b == 0) break;
            nameBytes.add(b);
          }
          if (nameBytes.isNotEmpty) {
            name = String.fromCharCodes(nameBytes);
          }
        }
      }
    } else if (RegExp(r'^[0-9a-fA-F]{64,}$').hasMatch(raw)) {
      address = raw.substring(0, 64);
    }

    // Also try raw bytes (some QR generators encode binary)
    if (address == null && barcode.rawBytes != null && barcode.rawBytes!.length >= 32) {
      final bytes = barcode.rawBytes!;
      address = bytes.sublist(0, 32).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      if (bytes.length > 99) {
        final nameBytes = bytes.sublist(99);
        final nullIdx = nameBytes.indexOf(0);
        final trimmed = nullIdx >= 0 ? nameBytes.sublist(0, nullIdx) : nameBytes;
        if (trimmed.isNotEmpty) name = String.fromCharCodes(trimmed);
      }
    }

    if (address == null || address.length < 64) {
      final preview = raw.length > 80 ? '${raw.substring(0, 80)}...' : raw;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('QR not recognized\n$preview'),
          duration: const Duration(seconds: 5),
        ),
      );
      // Cooldown before re-scanning to prevent error spam
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _scanned = false);
      });
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
              // Import to radio if we have the full contact frame
              if (rawContactHex != null) {
                final ble = context.read<BleService>();
                if (ble.isConnected) {
                  ble.sendFrame(buildImportContactFrame(rawContactHex!));
                }
              }
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
