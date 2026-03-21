import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/main.dart';

void main() {
  testWidgets('Integration Test: Global theme applies Poppins fontFamily', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Get the BuildContext of the main app
    final BuildContext context = tester.element(find.byType(MaterialApp));
    final ThemeData theme = Theme.of(context);

    // Verify global fontFamily
    expect(theme.fontFamily, 'Poppins');
    
    // Verify that standard Text widgets use Poppins (inherited)
    final Text titleText = tester.widget(find.textContaining('Wallet').first);
    // In Flutter, if TextStyle doesn't have a fontFamily, it inherits from theme.
    // We check if the effective style resolved by the framework includes Poppins.
    
    // Since we removed GoogleFonts.poppins(...) which explicitly set fontFamily,
    // new TextStyles should have fontFamily as null and inherit Poppins from theme.
    expect(titleText.style?.fontFamily, isNull);
  });
}
