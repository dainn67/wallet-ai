import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/main.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/services/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Integration Test: Global theme applies Poppins fontFamily', (WidgetTester tester) async {
    // Initialize required singletons
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await RecordRepository.init();
    await AppConfig().init();

    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(seconds: 1));

    // Verify that standard Text widgets use inherited fontFamily (null in TextStyle)
    // We search for the app title "Wally AI"
    final titleFinder = find.text('Wally AI');
    expect(titleFinder, findsOneWidget);
    
    final Text titleText = tester.widget(titleFinder);
    
    // Since we removed GoogleFonts.poppins(...) which explicitly set fontFamily,
    // new TextStyles should have fontFamily as null and inherit from theme.
    expect(titleText.style?.fontFamily, isNull);
  });
}
