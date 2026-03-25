import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/screens/home/home_screen.dart';
import 'package:wallet_ai/components/popups/confirmation_dialog.dart';

class MockRecordProvider extends Mock implements RecordProvider {}
class MockChatProvider extends Mock implements ChatProvider {}

void main() {
  late MockRecordProvider mockRecordProvider;
  late MockChatProvider mockChatProvider;

  setUp(() {
    mockRecordProvider = MockRecordProvider();
    mockChatProvider = MockChatProvider();

    when(() => mockRecordProvider.isLoading).thenReturn(false);
    when(() => mockRecordProvider.records).thenReturn([]);
    when(() => mockRecordProvider.moneySources).thenReturn([]);
    when(() => mockRecordProvider.filteredRecords).thenReturn([]);
    
    // For ChatTab
    when(() => mockChatProvider.messages).thenReturn([]);
    when(() => mockChatProvider.isStreaming).thenReturn(false);
  });

  Widget createHomeScreen() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<RecordProvider>.value(value: mockRecordProvider),
        ChangeNotifierProvider<ChatProvider>.value(value: mockChatProvider),
      ],
      child: const MaterialApp(
        home: HomeScreen(),
      ),
    );
  }

  testWidgets('HomeScreen drawer contains Reset All Data tile', (tester) async {
    await tester.pumpWidget(createHomeScreen());

    // Open drawer
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // Find "Data Management" header
    expect(find.text('Data Management'), findsOneWidget);

    // Find "Reset All Data" tile
    expect(find.text('Reset All Data'), findsOneWidget);
    expect(find.byIcon(Icons.delete_forever), findsOneWidget);
  });

  testWidgets('Tapping Reset All Data opens ConfirmationDialog', (tester) async {
    await tester.pumpWidget(createHomeScreen());

    // Open drawer
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // Tap "Reset All Data"
    await tester.tap(find.text('Reset All Data'));
    await tester.pumpAndSettle();

    // Verify dialog is shown
    expect(find.byType(ConfirmationDialog), findsOneWidget);
    expect(find.text('Reset All Data'), findsNWidgets(2)); // One in drawer, one in dialog title
    expect(find.textContaining('Are you sure you want to delete all records'), findsOneWidget);
  });

  testWidgets('Confirming Reset All Data calls recordProvider.resetAllData', (tester) async {
    when(() => mockRecordProvider.resetAllData()).thenAnswer((_) async {});
    // After reset, it calls loadAll
    when(() => mockRecordProvider.loadAll()).thenAnswer((_) async {});

    await tester.pumpWidget(createHomeScreen());

    // Open drawer
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // Tap "Reset All Data"
    await tester.tap(find.text('Reset All Data'));
    await tester.pumpAndSettle();

    // Tap "Reset" button in dialog
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    // Verify resetAllData was called
    verify(() => mockRecordProvider.resetAllData()).called(1);
    
    // Verify dialog and drawer are closed
    expect(find.byType(ConfirmationDialog), findsNothing);
    // Drawer should also be closed because we called Navigator.pop(context) in onConfirm
    // and ConfirmationDialog itself calls Navigator.pop(context) before calling onConfirm.
    // Wait, let's check ConfirmationDialog implementation again.
  });
}
