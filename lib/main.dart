import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'core/ble_service.dart';
import 'providers/chat_provider.dart';
import 'providers/connection_provider.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  final bleService = BleService();
  final chatProvider = ChatProvider(bleService);
  await chatProvider.initialize();

  runApp(MeshngrApp(bleService: bleService, chatProvider: chatProvider));
}

class MeshngrApp extends StatelessWidget {
  final BleService bleService;
  final ChatProvider chatProvider;

  const MeshngrApp({
    super.key,
    required this.bleService,
    required this.chatProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: bleService),
        ChangeNotifierProvider.value(value: chatProvider),
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
      ],
      child: MaterialApp(
        title: 'meshngr',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const OnboardingScreen(),
      ),
    );
  }
}
