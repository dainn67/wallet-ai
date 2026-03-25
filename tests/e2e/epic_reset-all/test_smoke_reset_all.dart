import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import 'package:wallet_ai/screens/home/home_screen.dart';
import 'package:wallet_ai/components/popups/confirmation_dialog.dart';
import 'package:wallet_ai/components/popups/edit_source_popup.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late RecordRepository repository;
  late RecordProvider recordProvider;

  setUp(() async {
    db = await openDatabase(inMemoryDatabasePath, version: 5,
        onCreate: (Database db, int version) async {
      await db.execute('CREATE TABLE Category (category_id INTEGER PRIMARY KEY, name TEXT, type TEXT)');
      await db.execute('CREATE TABLE MoneySource (source_id INTEGER PRIMARY KEY, source_name TEXT, amount REAL)');
      await db.execute('CREATE TABLE Record (record_id INTEGER PRIMARY KEY, money_source_id INTEGER, category_id INTEGER, amount REAL, currency TEXT, description TEXT, type TEXT, last_updated INTEGER)');
      await db.insert('Category', {'name': 'Uncategorized', 'type': 'expense'});
    });

    RecordRepository.setMockDatabase(db);
    repository = RecordRepository();
    recordProvider = RecordProvider(repository: repository);
    await recordProvider.loadAll();
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<RecordProvider>.value(value: recordProvider),
        ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider(recordProvider: recordProvider)),
      ],
      child: const MaterialApp(
        home: HomeScreen(),
      ),
    );
  }

  testWidgets('Smoke Test: Reset All Data Navigation and Dialog', (tester) async {
    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();

    // Verify Drawer exists
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    
    // Verify "Reset All Data" is visible
    expect(find.text('Reset All Data'), findsOneWidget);
    
    // Verify Dialog triggers
    await tester.tap(find.text('Reset All Data'));
    await tester.pumpAndSettle();
    
    expect(find.byType(ConfirmationDialog), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    
    // Cancel should close dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(ConfirmationDialog), findsNothing);
  });

  testWidgets('Smoke Test: Delete Source Icon and Dialog', (tester) async {
    // Add a source to click on
    await repository.createMoneySource(MoneySource(sourceName: 'Wallet', amount: 100));
    await recordProvider.loadAll();

    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();

    // Tap source to open edit popup
    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();
    
    expect(find.byType(EditSourcePopup), findsOneWidget);
    
    // Verify Delete Icon exists
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    
    // Verify Dialog triggers
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    
    expect(find.byType(ConfirmationDialog), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    
    // Cancel should close dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(ConfirmationDialog), findsNothing);
  });
}
