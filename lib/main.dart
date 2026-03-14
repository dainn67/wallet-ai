import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/config/app_config.dart';
import 'package:wallet_ai/providers/counter_provider.dart';
import 'package:wallet_ai/providers/chat_provider.dart';
import 'package:wallet_ai/screens/chat_screen.dart';
import 'package:wallet_ai/services/api_service.dart';
import 'package:wallet_ai/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
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
        Provider(
          create: (context) => ApiService(config: context.read<AppConfig>()),
        ),
        ChangeNotifierProvider(create: (_) => CounterProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'Wallet AI',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        home: const ChatScreen(),
      ),
    );
  }
}
