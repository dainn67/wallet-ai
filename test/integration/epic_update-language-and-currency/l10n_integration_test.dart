import 'dart:core' hide Record;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import 'package:wallet_ai/screens/home/home_screen.dart';
import 'package:wallet_ai/services/services.dart';
import 'package:wallet_ai/components/popups/confirmation_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wallet_ai/models/models.dart';

class MockRecordRepository extends Mock implements RecordRepository {}

void main() {
  const MethodChannel channel = MethodChannel('home_widget');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return null;
    });
  });

  late MockRecordRepository mockRepository;
  late StorageService storageService;

  setUp(() async {
    PackageInfo.setMockInitialValues(
      appName: 'Wallet AI',
      packageName: 'com.example.wallet_ai',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: 'signature',
    );
    SharedPreferences.setMockInitialValues({
      'user_language': AppLanguage.english.toString(),
      'user_currency': AppCurrency.usd.toString(),
      StorageService.keyOnboardingComplete: true,
    });
    await StorageService.init();
    storageService = StorageService();
    mockRepository = MockRecordRepository();

    // Default mock responses
    when(() => mockRepository.getAllRecords()).thenAnswer((_) async => []);
    when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => []);
    when(() => mockRepository.getAllCategories()).thenAnswer((_) async => []);
    when(() => mockRepository.getCategoryTotals()).thenAnswer((_) async => <int, double>{});
    when(() => mockRepository.resetAllData()).thenAnswer((_) async {});
    
    // Initialize AppConfig
    await AppConfig().init();
  });

  Widget createTestWidget() {
    return MultiProvider(
      providers: [
        Provider.value(value: storageService),
        ChangeNotifierProvider<LocaleProvider>(
          create: (context) => LocaleProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => RecordProvider(repository: mockRepository)..loadAll(),
        ),
        ChangeNotifierProvider(
          create: (context) => ChatProvider(
            recordProvider: context.read<RecordProvider>(),
            localeProvider: context.read<LocaleProvider>(),
          ),
        ),
      ],
      child: const MaterialApp(
        home: HomeScreen(),
      ),
    );
  }

  group('L10n Integration Tests', () {
    testWidgets('SC-1: Language switch updates UI reactively', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.language));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tiếng Việt').last);
      await tester.pumpAndSettle();

      expect(find.text('Tiếng Việt'), findsOneWidget);
      expect(find.text('Ghi chép'), findsWidgets);
    });

    testWidgets('SC-3: Protected currency switch wipes data and updates preference', (tester) async {
      final mockRecord = Record(
        recordId: 1, 
        moneySourceId: 1, 
        amount: 100, 
        currency: 'USD', 
        description: 'Test', 
        type: 'expense',
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      );
      
      when(() => mockRepository.getAllRecords()).thenAnswer((_) async => [mockRecord]);
      when(() => mockRepository.resetAllData()).thenAnswer((_) async {});

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final recordProvider = tester.element(find.byType(HomeScreen)).read<RecordProvider>();
      expect(recordProvider.records.length, 1);

      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.currency_exchange));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Vietnamese Dong'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmationDialog), findsOneWidget);

      // Important: setup empty return BEFORE confirm
      when(() => mockRepository.getAllRecords()).thenAnswer((_) async => []);

      await tester.tap(find.byKey(const Key('confirm_elevated_button')));
      await tester.pumpAndSettle();

      verify(() => mockRepository.resetAllData()).called(1);
      expect(recordProvider.records.length, 0);
      
      final localeProvider = tester.element(find.byType(HomeScreen)).read<LocaleProvider>();
      expect(localeProvider.currency, AppCurrency.vnd);
      expect(storageService.getString('user_currency'), 'VND');
    });

    test('Persistence across simulated app restarts', () async {
      await storageService.setString('user_language', 'vietnamese');
      await storageService.setString('user_currency', 'VND');

      final newLocaleProvider = LocaleProvider(storageService);

      expect(newLocaleProvider.language, AppLanguage.vietnamese);
      expect(newLocaleProvider.currency, AppCurrency.vnd);
    });
  });
}
