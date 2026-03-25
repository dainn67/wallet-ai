import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:wallet_ai/screens/home/home_screen.dart';
import 'package:wallet_ai/configs/configs.dart';
import 'package:wallet_ai/services/storage_service.dart';
import 'package:mocktail/mocktail.dart';

class MockRecordProvider extends Mock implements RecordProvider {}
class MockChatProvider extends Mock implements ChatProvider {}
class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockRecordProvider mockRecordProvider;
  late MockChatProvider mockChatProvider;
  late MockStorageService mockStorageService;
  late LocaleProvider localeProvider;

  setUp(() {
    mockRecordProvider = MockRecordProvider();
    mockChatProvider = MockChatProvider();
    mockStorageService = MockStorageService();

    when(() => mockStorageService.getString(any())).thenReturn(null);
    when(() => mockStorageService.setString(any(), any())).thenAnswer((_) async => true);

    localeProvider = LocaleProvider(mockStorageService);

    when(() => mockRecordProvider.records).thenReturn([]);
    when(() => mockRecordProvider.moneySources).thenReturn([]);
    when(() => mockRecordProvider.categories).thenReturn([]);
    when(() => mockRecordProvider.isLoading).thenReturn(false);
    when(() => mockChatProvider.messages).thenReturn([]);
    when(() => mockChatProvider.isStreaming).thenReturn(false);
  });

  Widget createTestApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
        ChangeNotifierProvider<RecordProvider>.value(value: mockRecordProvider),
        ChangeNotifierProvider<ChatProvider>.value(value: mockChatProvider),
      ],
      child: const MaterialApp(
        home: HomeScreen(),
      ),
    );
  }

  testWidgets('Home Screen localization toggle test', (tester) async {
    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();

    // 1. Initial English state
    expect(find.text('Chat'), findsWidgets);
    expect(find.text('Records'), findsWidgets);

    // 2. Open Drawer
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    // 3. Change to Vietnamese
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tiếng Việt'));
    await tester.pumpAndSettle();

    // 4. Verify Vietnamese text
    expect(find.text('Ngôn ngữ'), findsOneWidget);
    expect(find.text('Tiếng Việt'), findsOneWidget);
    expect(find.text('Ghi chép'), findsWidgets);
    expect(find.text('Trò chuyện'), findsWidgets);

    // 5. Close Drawer and check tabs
    // Note: showModalBottomSheet might still be open or drawer might be open.
    // Tapping 'Tiếng Việt' should pop the bottom sheet.
    // The drawer is still open.
    await tester.tapAt(const Offset(300, 300)); // Tap outside drawer to close
    await tester.pumpAndSettle();

    expect(find.text('Trò chuyện'), findsWidgets);
    expect(find.text('Ghi chép'), findsWidgets);
  });
}
