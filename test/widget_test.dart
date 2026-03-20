import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/main.dart';
import 'package:wallet_ai/screens/home/home_screen.dart';
import 'package:wallet_ai/screens/home/tabs/chat_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_ai/configs/app_config.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppConfig().init();
  });

  testWidgets('HomeScreen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that HomeScreen is displayed.
    expect(find.byType(HomeScreen), findsOneWidget);
    
    // Verify that ChatTab is the default tab.
    expect(find.byType(ChatTab), findsOneWidget);
    
    // Verify app title.
    expect(find.text('Wallet AI'), findsOneWidget);
    // In tests, kDebugMode is true, so it should show 'Dev Mode active' by default
    expect(find.text('Dev Mode active'), findsOneWidget);
  });
}
