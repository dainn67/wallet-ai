import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/repositories/record_repository.dart';

class MockRecordRepository extends Mock implements RecordRepository {}

void main() {
  late MockRecordRepository mockRepository;

  setUp(() {
    mockRepository = MockRecordRepository();
    
    // Default mock behavior
    when(() => mockRepository.getAllRecords()).thenAnswer((_) async => []);
    when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => []);
    when(() => mockRepository.getAllCategories()).thenAnswer((_) async => []);
  });

  testWidgets('RecordProvider.loadAll is triggered when ChatProvider.dbUpdateVersion changes', (WidgetTester tester) async {
    final chatProvider = ChatProvider();
    
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ChatProvider>.value(value: chatProvider),
          ChangeNotifierProxyProvider<ChatProvider, RecordProvider>(
            create: (_) => RecordProvider(repository: mockRepository)..loadAll(),
            update: (_, chat, record) {
              if (record == null) return RecordProvider(repository: mockRepository)..loadAll();
              if (record.lastDbUpdateVersion != chat.dbUpdateVersion) {
                record.lastDbUpdateVersion = chat.dbUpdateVersion;
                record.loadAll();
              }
              return record;
            },
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer<RecordProvider>(
              builder: (context, provider, child) {
                return Text('Loading: ${provider.isLoading}');
              },
            ),
          ),
        ),
      ),
    );

    // Initial load should have been called
    verify(() => mockRepository.getAllRecords()).called(1);
    verify(() => mockRepository.getAllMoneySources()).called(1);
    verify(() => mockRepository.getAllCategories()).called(1);

    // Increment version in chatProvider
    chatProvider.incrementDbUpdateVersionForTest();
    
    // Need to pump to let the ProxyProvider update
    await tester.pump();

    // loadAll should be called again
    verify(() => mockRepository.getAllRecords()).called(1);
    verify(() => mockRepository.getAllMoneySources()).called(1);
    verify(() => mockRepository.getAllCategories()).called(1);
  });
}
