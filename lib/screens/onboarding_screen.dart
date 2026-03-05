import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../core/ble_service.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  final _nameController = TextEditingController(text: '');

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finish() {
    // Set name on radio if connected
    final ble = context.read<BleService>();
    final name = _nameController.text.trim();
    if (name.isNotEmpty && ble.isConnected) {
      ble.setName(name);
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Page indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: List.generate(3, (i) => Expanded(
                  child: Container(
                    height: 3,
                    margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: i <= _currentPage
                          ? AppColors.accent
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                )),
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _WelcomePage(onNext: _nextPage),
                  _ConnectPage(
                    onNext: _nextPage,
                    onSkip: _nextPage,
                  ),
                  _NamePage(
                    controller: _nameController,
                    onFinish: _finish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Page 1: Welcome
class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'meshngr',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Off-grid messaging\nthat just works.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 32),
          _FeatureRow(icon: Icons.signal_cellular_alt, text: 'No internet, no cell towers needed'),
          const SizedBox(height: 14),
          _FeatureRow(icon: Icons.lock_outline, text: 'Encrypted, peer-to-peer messaging'),
          const SizedBox(height: 14),
          _FeatureRow(icon: Icons.people_outline, text: 'Find and message anyone on the mesh'),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Get Started',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.accent, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

// Page 2: Connect radio — REAL BLE scanning
class _ConnectPage extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _ConnectPage({
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<BleService>(
      builder: (context, ble, _) {
        final isConnected = ble.isConnected;
        final isScanning = ble.state == BleConnectionState.scanning;
        final isConnecting = ble.state == BleConnectionState.connecting;

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Status icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isConnected
                      ? AppColors.success.withValues(alpha: 0.15)
                      : isScanning || isConnecting
                          ? AppColors.accent.withValues(alpha: 0.15)
                          : AppColors.surfaceLight,
                  shape: BoxShape.circle,
                ),
                child: isScanning || isConnecting
                    ? Stack(
                        alignment: Alignment.center,
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
                          Icon(Icons.bluetooth_searching, size: 28, color: AppColors.accent),
                        ],
                      )
                    : Icon(
                        isConnected ? Icons.check_circle : Icons.bluetooth_searching,
                        size: 48,
                        color: isConnected ? AppColors.success : AppColors.accent,
                      ),
              ),
              const SizedBox(height: 24),

              Text(
                isConnected
                    ? 'Radio Connected!'
                    : isScanning
                        ? 'Scanning...'
                        : isConnecting
                            ? 'Connecting...'
                            : 'Connect Your Radio',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                isConnected
                    ? 'Connected to ${ble.deviceName ?? "your radio"}. You\'re ready to message!'
                    : isScanning
                        ? 'Looking for MeshCore radios nearby...'
                        : 'Turn on your MeshCore radio and make sure Bluetooth is enabled.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),

              // Real scan results
              if (ble.scanResults.isNotEmpty && !isConnected) ...[
                const SizedBox(height: 20),
                ...ble.scanResults.map((result) {
                  final name = result.device.platformName.isNotEmpty
                      ? result.device.platformName
                      : 'Unknown (${result.device.remoteId})';
                  final connectable = result.advertisementData.connectable;
                  final rssi = result.rssi;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.bluetooth, color: connectable ? AppColors.accent : AppColors.textTertiary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: Theme.of(context).textTheme.titleSmall),
                              Text('$rssi dBm', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        if (connectable && !isConnecting)
                          FilledButton(
                            onPressed: () => ble.connect(result.device),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            ),
                            child: const Text('Connect', style: TextStyle(fontSize: 13)),
                          ),
                      ],
                    ),
                  );
                }),
              ],

              // No devices found after scan
              if (!isScanning && !isConnecting && !isConnected && ble.scanResults.isEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: AppColors.warning.withValues(alpha: 0.7)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Make sure your radio is powered on, Bluetooth is enabled on your phone, and you\'re nearby.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.warning.withValues(alpha: 0.8),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(flex: 2),

              if (isConnected)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Continue', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                )
              else ...[
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: isScanning || isConnecting ? null : () => ble.startScan(),
                    icon: isScanning || isConnecting
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.bluetooth_searching),
                    label: Text(
                      isScanning
                          ? 'Scanning...'
                          : isConnecting
                              ? 'Connecting...'
                              : 'Scan for Radios',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onSkip,
                  child: const Text(
                    'Skip — I\'ll connect later in Settings',
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// Page 3: Set your name
class _NamePage extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onFinish;

  const _NamePage({required this.controller, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Consumer<BleService>(
      builder: (context, ble, _) {
        // Pre-fill with radio's current name if available
        if (controller.text.isEmpty && ble.selfInfo?.name != null) {
          controller.text = ble.selfInfo!.name;
        }

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline, size: 48, color: AppColors.accent),
              ),
              const SizedBox(height: 32),

              Text(
                'What should we call you?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                ble.isConnected
                    ? 'This name will be set on your radio. Others on the mesh will see it.'
                    : 'You can set this later when your radio is connected.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  maxLength: 20,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Your name',
                    hintStyle: TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.w400),
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 16, color: AppColors.accent.withValues(alpha: 0.7)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tip: Use a name your friends will recognize, not a handle or callsign.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.accent.withValues(alpha: 0.8),
                              height: 1.4,
                            ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: onFinish,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Start Messaging',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
