// Integration tests — OnboardingDialog first-launch gate in HomeScreen
// Covers: FR-1 (first launch shows dialog), FR-1 (returning launch skips dialog), FR-4 (flag check)
// Pattern: mount HomeScreen with mocked providers; check post-frame callback behaviour.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wallet_ai/components/popups/onboarding_dialog.dart';
import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/screens/home/home_screen.dart';
import 'package:wallet_ai/services/storage_service.dart';

class MockRecordProvider extends Mock implements RecordProvider {}
class MockChatProvider extends Mock implements ChatProvider {}
class MockLocaleProvider extends Mock implements LocaleProvider {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Silence HomeWidget platform channel calls
  const homeWidgetChannel = MethodChannel('home_widget');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(homeWidgetChannel, (_) async => null);
  });

  late MockRecordProvider mockRecordProvider;
  late MockChatProvider mockChatProvider;
  late MockLocaleProvider mockLocaleProvider;

  void stubProviders() {
    when(() => mockRecordProvider.records).thenReturn([]);
    when(() => mockRecordProvider.filteredRecords).thenReturn([]);
    when(() => mockRecordProvider.moneySources).thenReturn([]);
    when(() => mockRecordProvider.categories).thenReturn([]);
    when(() => mockRecordProvider.getCategoryName(any())).thenReturn('Test');
    when(() => mockRecordProvider.isLoading).thenReturn(false);
    when(() => mockRecordProvider.filteredTotalIncome).thenReturn(0.0);
    when(() => mockRecordProvider.filteredTotalExpense).thenReturn(0.0);
    when(() => mockRecordProvider.totalBalance).thenReturn(0.0);
    when(() => mockRecordProvider.selectedDateRange).thenReturn(null);

    when(() => mockChatProvider.messages).thenReturn([]);
    when(() => mockChatProvider.isStreaming).thenReturn(false);
    when(() => mockChatProvider.suggestedPrompts).thenReturn([]);
    when(() => mockChatProvider.activePromptIndex).thenReturn(null);
    when(() => mockChatProvider.showingActions).thenReturn(false);

    when(() => mockLocaleProvider.language).thenReturn(AppLanguage.english);
    when(() => mockLocaleProvider.currency).thenReturn(AppCurrency.usd);
    when(() => mockLocaleProvider.translate(any())).thenAnswer((i) {
      final key = i.positionalArguments[0] as String;
      const keys = {
        'app_subtitle': 'Personal finance copilot',
        'settings_header': 'Settings',
        'currency_label': 'Currency',
        'language_label': 'Language',
        'reset_all_data': 'Reset All Data',
        'drawer_chat': 'Chat',
        'drawer_records': 'Records',
        'drawer_categories': 'Categories',
      };
      return keys[key] ?? key;
    });
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();

    mockRecordProvider = MockRecordProvider();
    mockChatProvider = MockChatProvider();
    mockLocaleProvider = MockLocaleProvider();
    stubProviders();
  });

  Widget buildHomeScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<RecordProvider>.value(value: mockRecordProvider),
        ChangeNotifierProvider<ChatProvider>.value(value: mockChatProvider),
        ChangeNotifierProvider<LocaleProvider>.value(value: mockLocaleProvider),
      ],
      child: const MaterialApp(
        home: HomeScreen(),
      ),
    );
  }

  // Gate-1: no flag → dialog shown
  testWidgets('Gate-1: shows OnboardingDialog on first launch (no flag)', (tester) async {
    // Prefs are empty (set in setUp); StorageService.getBool returns null → != true → show dialog
    await tester.pumpWidget(buildHomeScreen());
    await tester.pump(const Duration(milliseconds: 100)); // let post-frame callback fire

    expect(find.byType(OnboardingDialog), findsOneWidget);
  });

  // Gate-2: flag=true → dialog NOT shown
  testWidgets('Gate-2: does not show OnboardingDialog when onboarding_complete is true', (tester) async {
    // Explicitly set the completion flag via StorageService singleton
    await StorageService().setBool(StorageService.keyOnboardingComplete, true);

    await tester.pumpWidget(buildHomeScreen());
    await tester.pump(const Duration(milliseconds: 100)); // let post-frame callback fire

    expect(find.byType(OnboardingDialog), findsNothing);
  });
}
