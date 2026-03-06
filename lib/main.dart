import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/app_theme.dart';
import 'core/ble_service.dart';
import 'core/notification_service.dart';
import 'core/foreground_service.dart';
import 'providers/chat_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Init notifications + foreground service
  await NotificationService().initialize();
  await MeshForegroundService.init();

  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_complete') ?? false;

  final bleService = BleService();
  final chatProvider = ChatProvider(bleService);
  await chatProvider.initialize();

  // Auto-reconnect to last device if onboarding is done
  if (onboardingDone) {
    final lastDeviceId = prefs.getString('last_device_id');
    if (lastDeviceId != null) {
      bleService.autoReconnect(lastDeviceId);
    }
  }

  runApp(MeshngrApp(
    bleService: bleService,
    chatProvider: chatProvider,
    onboardingDone: onboardingDone,
  ));
}

class MeshngrApp extends StatelessWidget {
  final BleService bleService;
  final ChatProvider chatProvider;
  final bool onboardingDone;

  const MeshngrApp({
    super.key,
    required this.bleService,
    required this.chatProvider,
    required this.onboardingDone,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: bleService),
        ChangeNotifierProvider.value(value: chatProvider),
      ],
      child: MaterialApp(
        title: 'meshngr',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: onboardingDone ? const HomeScreen() : const OnboardingScreen(),
      ),
    );
  }
}
