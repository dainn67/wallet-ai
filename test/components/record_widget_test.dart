import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/components/record_widget.dart';
import 'package:wallet_ai/models/models.dart';
import 'package:intl/intl.dart';
import 'package:wallet_ai/providers/record_provider.dart';
import 'package:wallet_ai/repositories/record_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockRecordRepository extends Mock implements RecordRepository {}

void main() {
  late MockRecordRepository mockRepository;
  late RecordProvider recordProvider;

  setUp(() {
    mockRepository = MockRecordRepository();
    recordProvider = RecordProvider(repository: mockRepository);

    when(() => mockRepository.getCategoryTotals()).thenAnswer((_) async => <int, double>{});
    when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => []);
    when(() => mockRepository.getAllCategories()).thenAnswer((_) async => []);
    when(() => mockRepository.getAllRecords()).thenAnswer((_) async => []);
  });

  Widget createWidgetWrapper(Record record) {
    return MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider<RecordProvider>.value(
          value: recordProvider,
          child: RecordWidget(record: record),
        ),
      ),
    );
  }

  group('RecordWidget Tests', () {
    final testDate = DateTime(2026, 3, 21);
    final testRecord = Record(
      recordId: 1,
      lastUpdated: testDate.millisecondsSinceEpoch,
      moneySourceId: 1,
      categoryId: 1,
      categoryName: 'Food',
      sourceName: 'Cash',
      amount: 50.0,
      currency: 'USD',
      description: 'Lunch at Cafe',
      type: 'expense',
    );

    testWidgets('renders correct date text for a given timestamp', (WidgetTester tester) async {
      await recordProvider.loadAll();
      await tester.pumpWidget(createWidgetWrapper(testRecord));

      final formattedDate = DateFormat('dd/MM/yyyy').format(testDate);
      expect(find.text(formattedDate), findsOneWidget);
    });

    testWidgets('widget styling (font size/color) matches spec', (WidgetTester tester) async {
      await recordProvider.loadAll();
      await tester.pumpWidget(createWidgetWrapper(testRecord));

      final formattedDate = DateFormat('dd/MM/yyyy').format(testDate);
      final dateText = find.text(formattedDate);
      
      final textWidget = tester.widget<Text>(dateText);
      expect(textWidget.style?.fontSize, 10);
      expect(textWidget.style?.color, const Color(0xFF64748B));
      expect(textWidget.style?.fontFamily, isNull);
    });

    testWidgets('renders description and subtitle correctly', (WidgetTester tester) async {
      await recordProvider.loadAll();
      await tester.pumpWidget(createWidgetWrapper(testRecord));

      expect(find.text('Lunch at Cafe'), findsOneWidget);
      // Since categories are empty, it will fall back to record.categoryName
      expect(find.text('Food • Cash'), findsOneWidget);
    });

    testWidgets('renders hierarchical category name correctly', (WidgetTester tester) async {
      when(() => mockRepository.getAllCategories()).thenAnswer((_) async => [
        Category(categoryId: 1, name: 'Dining', type: 'expense'),
        Category(categoryId: 2, name: 'Lunch', type: 'expense', parentId: 1),
      ]);
      await recordProvider.loadAll();

      final hierarchicalRecord = testRecord.copyWith(categoryId: 2);
      await tester.pumpWidget(createWidgetWrapper(hierarchicalRecord));

      expect(find.text('Dining - Lunch • Cash'), findsOneWidget);
    });
  });
}
