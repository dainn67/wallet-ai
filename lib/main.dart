import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/screens/screens.dart';
import 'package:wallet_ai/services/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([StorageService.init(), dotenv.load(fileName: ".env")]);
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
        ChangeNotifierProvider(create: (_) => CounterProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'Wallet AI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6366F1), // Indigo/Violet
            primary: const Color(0xFF6366F1),
            secondary: const Color(0xFF10B981), // Emerald
            surface: const Color(0xFFF8FAFC),
          ),
          textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: GoogleFonts.poppins(color: const Color(0xFF1E293B), fontSize: 20, fontWeight: FontWeight.w600),
            iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
          ),
        ),
        home: const ChatScreen(),
      ),
    );
  }
}
