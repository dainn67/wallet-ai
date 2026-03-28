import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/screens/home/home_screen.dart';
import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/services/storage_service.dart';

class MockRecordProvider extends Mock implements RecordProvider {}
class MockChatProvider extends Mock implements ChatProvider {}
class MockLocaleProvider extends Mock implements LocaleProvider {}
class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockRecordProvider mockRecordProvider;
  late MockChatProvider mockChatProvider;
  late MockLocaleProvider mockLocaleProvider;
  late MockStorageService mockStorageService;

  setUp(() {
    mockRecordProvider = MockRecordProvider();
    mockChatProvider = MockChatProvider();
    mockLocaleProvider = MockLocaleProvider();
    mockStorageService = MockStorageService();

    when(() => mockRecordProvider.records).thenReturn([]);
    when(() => mockRecordProvider.filteredRecords).thenReturn([]);
    when(() => mockRecordProvider.moneySources).thenReturn([]);
    when(() => mockRecordProvider.categories).thenReturn([]);
    when(() => mockRecordProvider.getCategoryName(any())).thenReturn('Test Category');
    when(() => mockRecordProvider.isLoading).thenReturn(false);
    when(() => mockRecordProvider.filteredTotalIncome).thenReturn(0.0);
    when(() => mockRecordProvider.filteredTotalExpense).thenReturn(0.0);
    when(() => mockRecordProvider.totalBalance).thenReturn(0.0);
    
    when(() => mockChatProvider.messages).thenReturn([]);
    when(() => mockChatProvider.isStreaming).thenReturn(false);

    when(() => mockLocaleProvider.language).thenReturn(AppLanguage.english);
    when(() => mockLocaleProvider.currency).thenReturn(AppCurrency.usd);
    when(() => mockLocaleProvider.translate(any())).thenAnswer((invocation) {
      final key = invocation.positionalArguments[0] as String;
      if (key == 'app_subtitle') return 'Personal finance copilot';
      if (key == 'settings_header') return 'Settings';
      if (key == 'currency_label') return 'Currency';
      if (key == 'language_label') return 'Language';
      if (key == 'reset_all_data') return 'Reset All Data';
      if (key == 'drawer_chat') return 'Chat';
      if (key == 'drawer_records') return 'Records';
      return key;
    });
  });

  Widget createHomeScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<RecordProvider>.value(value: mockRecordProvider),
        ChangeNotifierProvider<ChatProvider>.value(value: mockChatProvider),
        ChangeNotifierProvider<LocaleProvider>.value(value: mockLocaleProvider),
        Provider<StorageService>.value(value: mockStorageService),
      ],
      child: const MaterialApp(
        home: HomeScreen(),
      ),
    );
  }

  testWidgets('HomeScreen has BottomNavigationBar and Tabs', (tester) async {
    await tester.pumpWidget(createHomeScreen());

    expect(find.byType(TabBar), findsOneWidget); // HomeScreen uses TabBar now
    expect(find.text('Chat'), findsWidgets);
    expect(find.text('Records'), findsWidgets);
  });

  testWidgets('HomeScreen has a Drawer', (tester) async {
    await tester.pumpWidget(createHomeScreen());

    // Open drawer
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsOneWidget);
    // Find Wally AI in drawer header specifically
    expect(find.descendant(of: find.byType(Drawer), matching: find.text('Wally AI')), findsOneWidget);
    expect(find.text('Personal finance copilot'), findsOneWidget);
  });

  testWidgets('Drawer shows correct version and preferences', (tester) async {
    await tester.pumpWidget(createHomeScreen());

    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Currency'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Reset All Data'), findsOneWidget);
  });
}
