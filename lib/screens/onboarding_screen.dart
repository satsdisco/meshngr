import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/connection_provider.dart' as conn;
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
  bool _connectingRadio = false;

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
                    isConnecting: _connectingRadio,
                    onConnect: () async {
                      setState(() => _connectingRadio = true);
                      // Simulate connection
                      final cp = context.read<conn.ConnectionProvider>();
                      await cp.startScan();
                      if (cp.discoveredDevices.isNotEmpty) {
                        await cp.connect(cp.discoveredDevices.first);
                      }
                      setState(() => _connectingRadio = false);
                      _nextPage();
                    },
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
          // Logo area
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.accent,
                  AppColors.accent.withValues(alpha: 0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.cell_tower, size: 56, color: Colors.white),
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

          // Feature bullets
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

// Page 2: Connect radio
class _ConnectPage extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onConnect;
  final VoidCallback onSkip;
  final bool isConnecting;

  const _ConnectPage({
    required this.onNext,
    required this.onConnect,
    required this.onSkip,
    required this.isConnecting,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<conn.ConnectionProvider>(
      builder: (context, cp, _) {
        final isConnected = cp.isConnected;

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Radio icon with pulse animation
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isConnected
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.surfaceLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isConnected ? Icons.check_circle : Icons.bluetooth_searching,
                  size: 48,
                  color: isConnected ? AppColors.success : AppColors.accent,
                ),
              ),
              const SizedBox(height: 32),

              Text(
                isConnected ? 'Radio Connected!' : 'Connect Your Radio',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                isConnected
                    ? 'You\'re connected to ${cp.connectedDevice?.name ?? "your radio"}. You\'re ready to message.'
                    : 'Turn on your MeshCore radio and make sure Bluetooth is enabled. We\'ll find it automatically.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
              ),

              if (!isConnected && !isConnecting) ...[
                const SizedBox(height: 12),
                // Show found devices
                if (cp.discoveredDevices.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...cp.discoveredDevices.where((d) => d.isConnectable).map((device) =>
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bluetooth, color: AppColors.accent, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(device.name, style: Theme.of(context).textTheme.titleMedium),
                          ),
                          Text(device.signalLabel, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ],
              ],

              const Spacer(flex: 3),

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
                    onPressed: isConnecting ? null : onConnect,
                    icon: isConnecting
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.bluetooth_searching),
                    label: Text(
                      isConnecting ? 'Scanning...' : 'Scan for Radios',
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
                  child: Text(
                    'Skip for now — I\'ll connect later',
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
            'This is how other people on the mesh will see you. You can change it anytime.',
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
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                hintText: 'Your name',
                hintStyle: TextStyle(color: AppColors.textTertiary, fontWeight: FontWeight.w400),
                border: InputBorder.none,
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
  }
}
