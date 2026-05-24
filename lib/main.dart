import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import 'package:wallet_ai/screens/screens.dart';
import 'package:wallet_ai/services/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([StorageService.init(), RecordRepository.init(), dotenv.load(fileName: ".env")]);

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize AppConfig (loads devMode etc.)
  await AppConfig().init();

  // Initialize HomeWidget
  await HomeWidget.setAppGroupId('com.leslie.wallyai');

  // Update the user pattern from AI based on record history (fire-and-forget)
  AiPatternService().updateUserPattern();
  
  // Ensure the system status bar and navigation bar are visible
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => AppConfig()),
        Provider(create: (_) => StorageService()),
        ChangeNotifierProxyProvider<StorageService, LocaleProvider>(
          create: (context) => LocaleProvider(Provider.of<StorageService>(context, listen: false)),
          update: (_, storageService, previous) => previous ?? LocaleProvider(storageService),
        ),
        ChangeNotifierProvider(create: (_) => RecordProvider()..loadAll()),
        ChangeNotifierProxyProvider2<RecordProvider, LocaleProvider, ChatProvider>(
          create: (_) => ChatProvider(),
          update: (_, recordProvider, localeProvider, chatProvider) {
            return (chatProvider ?? ChatProvider())
              ..recordProvider = recordProvider
              ..localeProvider = localeProvider;
          },
        ),
      ],
      child: MaterialApp(
        title: AppConfig().appName,
        scaffoldMessengerKey: ToastService.messengerKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const HomeScreen(),
      ),
    );
  }
}
