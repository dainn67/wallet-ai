import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/screens/home/home_screen.dart';
import 'package:wallet_ai/components/popups/confirmation_dialog.dart';
import 'package:wallet_ai/configs/configs.dart';

class MockRecordProvider extends Mock implements RecordProvider {}
class MockChatProvider extends Mock implements ChatProvider {}
class MockLocaleProvider extends Mock implements LocaleProvider {}

void main() {
  late MockRecordProvider mockRecordProvider;
  late MockChatProvider mockChatProvider;
  late MockLocaleProvider mockLocaleProvider;

  setUp(() {
    mockRecordProvider = MockRecordProvider();
    mockChatProvider = MockChatProvider();
    mockLocaleProvider = MockLocaleProvider();

    when(() => mockRecordProvider.isLoading).thenReturn(false);
    when(() => mockRecordProvider.records).thenReturn([]);
    when(() => mockRecordProvider.moneySources).thenReturn([]);
    when(() => mockRecordProvider.filteredRecords).thenReturn([]);
    when(() => mockRecordProvider.filteredTotalIncome).thenReturn(0.0);
    when(() => mockRecordProvider.filteredTotalExpense).thenReturn(0.0);
    when(() => mockRecordProvider.totalBalance).thenReturn(0.0);
    
    when(() => mockChatProvider.messages).thenReturn([]);
    when(() => mockChatProvider.isStreaming).thenReturn(false);
    when(() => mockChatProvider.suggestedPrompts).thenReturn([]);
    when(() => mockChatProvider.activePromptIndex).thenReturn(null);
    when(() => mockChatProvider.showingActions).thenReturn(false);

    when(() => mockLocaleProvider.language).thenReturn(AppLanguage.english);
    when(() => mockLocaleProvider.currency).thenReturn(AppCurrency.usd);
    when(() => mockLocaleProvider.translate(any())).thenAnswer((invocation) {
      final key = invocation.positionalArguments[0] as String;
      if (key == 'data_management_header') return 'Data Management';
      if (key == 'reset_all_data') return 'Reset All Data';
      if (key == 'reset_data_confirm_title') return 'Reset All Data';
      if (key == 'reset_data_confirm_content') return 'Are you sure you want to delete all records';
      if (key == 'reset_button') return 'Reset';
      if (key == 'popup_cancel') return 'Cancel';
      if (key == 'drawer_chat') return 'Chat';
      if (key == 'drawer_records') return 'Records';
      if (key == 'app_subtitle') return 'Personal finance copilot';
      if (key == 'settings_header') return 'Settings';
      if (key == 'currency_label') return 'Currency';
      if (key == 'language_label') return 'Language';
      return key;
    });
  });

  Widget createHomeScreen() {
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

  testWidgets('HomeScreen drawer contains Reset All Data tile', (tester) async {
    await tester.pumpWidget(createHomeScreen());

    // Open drawer
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    // Find "Reset All Data" tile
    expect(find.text('Reset All Data'), findsOneWidget);
    expect(find.byIcon(Icons.delete_forever), findsOneWidget);
  });

  testWidgets('Tapping Reset All Data opens ConfirmationDialog', (tester) async {
    await tester.pumpWidget(createHomeScreen());

    // Open drawer
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    // Tap "Reset All Data"
    await tester.tap(find.text('Reset All Data'));
    await tester.pumpAndSettle();

    // Verify dialog is shown
    expect(find.byType(ConfirmationDialog), findsOneWidget);
    // Find text specifically in the dialog
    expect(find.descendant(of: find.byType(ConfirmationDialog), matching: find.text('Reset All Data')), findsOneWidget);
  });

  testWidgets('Confirming Reset All Data calls recordProvider.resetAllData', (tester) async {
    when(() => mockRecordProvider.resetAllData()).thenAnswer((_) async {});
    when(() => mockRecordProvider.loadAll()).thenAnswer((_) async {});

    await tester.pumpWidget(createHomeScreen());

    // Open drawer
    final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();

    // Tap "Reset All Data"
    await tester.tap(find.text('Reset All Data'));
    await tester.pumpAndSettle();

    // Tap "Reset" button in dialog
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    // Verify resetAllData was called
    verify(() => mockRecordProvider.resetAllData()).called(1);
    
    // Verify dialog is closed
    expect(find.byType(ConfirmationDialog), findsNothing);
  });
}
