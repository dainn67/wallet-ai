// Smoke tests — OnboardingDialog
// Covers: FR-2 (slide navigation, dismissal blocking), FR-3 (slide content),
//         FR-4 (completion flag), NFR-2 (back-button lock).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wallet_ai/components/popups/onboarding_dialog.dart';
import 'package:wallet_ai/providers/locale_provider.dart';
import 'package:wallet_ai/services/storage_service.dart';

class MockLocaleProvider extends Mock implements LocaleProvider {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLocaleProvider mockLocale;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();

    mockLocale = MockLocaleProvider();
    // Return the key as-is so tests can find widgets by key name
    when(() => mockLocale.translate(any()))
        .thenAnswer((i) => i.positionalArguments[0] as String);
  });

  Widget buildApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleProvider>.value(value: mockLocale),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => OnboardingDialog.show(ctx),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  // S1 — Three slides exist; slide 1 content shown initially
  testWidgets('S1: dialog opens and shows slide 1 text', (tester) async {
    await openDialog(tester);

    expect(find.byType(OnboardingDialog), findsOneWidget);
    expect(find.text('onboarding_slide_1_text'), findsOneWidget);
  });

  // S2 — Next advances slides
  testWidgets('S2: Next advances to slide 2, then slide 3', (tester) async {
    await openDialog(tester);

    // Slide 1 visible
    expect(find.text('onboarding_slide_1_text'), findsOneWidget);

    // Tap Next → slide 2
    await tester.tap(find.text('onboarding_next'));
    await tester.pumpAndSettle();
    expect(find.text('onboarding_slide_2_text'), findsOneWidget);

    // Tap Next → slide 3
    await tester.tap(find.text('onboarding_next'));
    await tester.pumpAndSettle();
    expect(find.text('onboarding_slide_3_text'), findsOneWidget);
  });

  // S3 — Got it only on last slide; Next absent on last slide
  testWidgets('S3: Got it only on slide 3; Next absent on slide 3', (tester) async {
    await openDialog(tester);

    // Slide 0: Next present, Got it absent
    expect(find.text('onboarding_next'), findsOneWidget);
    expect(find.text('onboarding_got_it'), findsNothing);

    // Advance to slide 1
    await tester.tap(find.text('onboarding_next'));
    await tester.pumpAndSettle();

    // Slide 1: Next present, Got it absent
    expect(find.text('onboarding_next'), findsOneWidget);
    expect(find.text('onboarding_got_it'), findsNothing);

    // Advance to slide 2
    await tester.tap(find.text('onboarding_next'));
    await tester.pumpAndSettle();

    // Slide 2: Got it present, Next absent
    expect(find.text('onboarding_got_it'), findsOneWidget);
    expect(find.text('onboarding_next'), findsNothing);
  });

  // S4 — Got it writes flag and dismisses dialog
  testWidgets('S4: Got it writes completion flag and dismisses', (tester) async {
    await openDialog(tester);

    // Navigate to last slide
    await tester.tap(find.text('onboarding_next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('onboarding_next'));
    await tester.pumpAndSettle();

    // Tap Got it
    await tester.tap(find.text('onboarding_got_it'));
    await tester.pumpAndSettle();

    // Dialog dismissed
    expect(find.byType(OnboardingDialog), findsNothing);

    // Flag written
    expect(
      StorageService().getBool(StorageService.keyOnboardingComplete),
      isTrue,
    );
  });

  // S5 — Back button does not dismiss dialog
  testWidgets('S5: Back button does not dismiss dialog', (tester) async {
    await openDialog(tester);

    expect(find.byType(OnboardingDialog), findsOneWidget);

    // Simulate back button press
    // ignore: invalid_use_of_protected_member
    await tester.binding.handlePopRoute();
    await tester.pump();

    // Dialog still visible
    expect(find.byType(OnboardingDialog), findsOneWidget);
  });

  // S6 — Swipe does not advance slides
  testWidgets('S6: Swipe gesture does not advance slides', (tester) async {
    await openDialog(tester);

    expect(find.text('onboarding_slide_1_text'), findsOneWidget);

    // Swipe left on the PageView
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pump();

    // Still on slide 1
    expect(find.text('onboarding_slide_1_text'), findsOneWidget);
    expect(find.text('onboarding_slide_2_text'), findsNothing);
  });
}
