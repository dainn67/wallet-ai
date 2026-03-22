import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/screens/home/tabs/records_tab.dart';
import 'package:wallet_ai/components/month_divider.dart';
import 'package:wallet_ai/repositories/record_repository.dart';

class MockRecordRepository extends Mock implements RecordRepository {}

void main() {
  late MockRecordRepository mockRepository;

  setUp(() {
    mockRepository = MockRecordRepository();
    // Provide default mock behaviors to prevent TypeErrors during loadAll
    when(() => mockRepository.getAllRecords()).thenAnswer((_) async => []);
    when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => []);
    when(() => mockRepository.getAllCategories()).thenAnswer((_) async => []);
  });

  testWidgets('Integration Test: RecordsTab displays month headers for records from multiple months', (WidgetTester tester) async {
    // March 2026
    final marchDate = DateTime(2026, 3, 15).millisecondsSinceEpoch;
    // February 2026
    final febDate = DateTime(2026, 2, 10).millisecondsSinceEpoch;

    final records = [
      Record(
        recordId: 1,
        lastUpdated: marchDate,
        moneySourceId: 1,
        amount: 100,
        currency: 'USD',
        description: 'March Record',
        type: 'expense',
      ),
      Record(
        recordId: 2,
        lastUpdated: febDate,
        moneySourceId: 1,
        amount: 300,
        currency: 'USD',
        description: 'February Record',
        type: 'expense',
      ),
    ];

    when(() => mockRepository.getAllRecords()).thenAnswer((_) async => records);
    when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => []);

    final recordProvider = RecordProvider(repository: mockRepository);
    await recordProvider.loadAll();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider<RecordProvider>.value(
            value: recordProvider,
            child: const RecordsTab(),
          ),
        ),
      ),
    );

    // Initial pump
    await tester.pump();

    // Verify Dividers are present
    expect(find.byType(MonthDivider), findsNWidgets(2));
    expect(find.text('March 2026'), findsOneWidget);
    expect(find.text('February 2026'), findsOneWidget);
  });
}
