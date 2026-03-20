import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wallet_ai/screens/home/home_screen.dart';
import 'package:wallet_ai/screens/home/tabs/chat_tab.dart';
import 'package:wallet_ai/providers/providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockChatProvider extends Mock implements ChatProvider {}

class MockRecordProvider extends Mock implements RecordProvider {}

void main() {
  late MockChatProvider mockChatProvider;
  late MockRecordProvider mockRecordProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockChatProvider = MockChatProvider();
    mockRecordProvider = MockRecordProvider();

    when(() => mockChatProvider.messages).thenReturn([]);
    when(() => mockChatProvider.isStreaming).thenReturn(false);
    when(() => mockChatProvider.addListener(any())).thenReturn(null);
    when(() => mockChatProvider.removeListener(any())).thenReturn(null);

    when(() => mockRecordProvider.records).thenReturn([]);
    when(() => mockRecordProvider.filteredRecords).thenReturn([]);
    when(() => mockRecordProvider.isLoading).thenReturn(false);
  });

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ChatProvider>.value(value: mockChatProvider),
        ChangeNotifierProvider<RecordProvider>.value(value: mockRecordProvider),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  testWidgets('HomeScreen renders with TabBar and 3 tabs', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Records'), findsOneWidget);
    expect(find.text('Test'), findsOneWidget);
  });

  testWidgets('HomeScreen renders with TabBarView and ChatTabs', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    expect(find.byType(TabBarView), findsOneWidget);
    expect(find.byType(ChatTab), findsWidgets);
  });

  testWidgets('HomeScreen has a Drawer', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());

    // Open drawer
    final ScaffoldState state = tester.firstState(find.byType(Scaffold));
    state.openDrawer();
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsOneWidget);
    expect(find.text('Wallet AI'), findsWidgets);
  });
}
