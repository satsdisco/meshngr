import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/chat_provider.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final _nameController = TextEditingController();
  final _keyController = TextEditingController();
  bool _sending = false;

  bool get _isValidKey {
    final key = _keyController.text.trim().toLowerCase();
    return RegExp(r'^[0-9a-f]{64}$').hasMatch(key);
  }

  Future<void> _addContact() async {
    if (!_isValidKey) return;
    setState(() => _sending = true);

    final cp = context.read<ChatProvider>();
    final name = _nameController.text.trim();
    final key = _keyController.text.trim().toLowerCase();

    try {
      await cp.ble.addContactByKey(key, name: name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${name.isNotEmpty ? name : "Contact"} added to radio')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selfKey = context.read<ChatProvider>().ble.selfInfo?.publicKeyHex;

    return Scaffold(
      appBar: AppBar(title: const Text('Add Contact')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // YOUR KEY section
          if (selfKey != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.key, size: 16, color: AppColors.accent),
                      const SizedBox(width: 8),
                      const Text('Your Public Key', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: selfKey));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Public key copied'), duration: Duration(seconds: 1)),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy, size: 14, color: AppColors.accent.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Text('Copy', style: TextStyle(fontSize: 12, color: AppColors.accent.withValues(alpha: 0.7))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    selfKey,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share this with the person you want to message. They need to add your key too — DMs only work when both sides have exchanged keys.',
                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ADD THEIR KEY section
          const Text('Add Their Key', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'Paste the public key someone shared with you.',
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Name (optional)',
              hintText: 'e.g. Alice',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _keyController,
            decoration: InputDecoration(
              labelText: 'Public Key',
              hintText: '64-character hex string',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              suffixIcon: IconButton(
                icon: const Icon(Icons.paste, size: 20),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (data?.text != null) {
                    _keyController.text = data!.text!.trim();
                    setState(() {});
                  }
                },
              ),
            ),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            maxLines: 2,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),

          if (_keyController.text.isNotEmpty && !_isValidKey)
            Text(
              'Key must be exactly 64 hex characters (0-9, a-f)',
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),

          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _isValidKey && !_sending ? _addContact : null,
            icon: _sending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.person_add),
            label: Text(_sending ? 'Adding...' : 'Add to Radio'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.accent.withValues(alpha: 0.7)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Both people need to add each other for DMs to work. It\'s like exchanging phone numbers — one-sided doesn\'t cut it.',
                    style: TextStyle(fontSize: 12, color: AppColors.accent.withValues(alpha: 0.8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
