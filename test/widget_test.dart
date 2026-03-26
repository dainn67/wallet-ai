import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wallet_ai/main.dart';
import 'package:wallet_ai/screens/home/home_screen.dart';
import 'package:wallet_ai/screens/home/tabs/chat_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_ai/configs/app_config.dart';
import 'package:wallet_ai/repositories/record_repository.dart';

class MockRecordRepository extends Mock implements RecordRepository {}

void main() {
  late MockRecordRepository mockRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppConfig().init();

    mockRepository = MockRecordRepository();
    when(() => mockRepository.getAllRecords()).thenAnswer((_) async => []);
    when(() => mockRepository.getAllMoneySources()).thenAnswer((_) async => []);
    when(() => mockRepository.getAllCategories()).thenAnswer((_) async => []);
    when(() => mockRepository.getCategoryTotals()).thenAnswer((_) async => <int, double>{});

    RecordRepository.setMockInstance(mockRepository);

    // Mock home_widget channel
    const MethodChannel channel = MethodChannel('home_widget');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return null;
    });
  });

  testWidgets('HomeScreen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that HomeScreen is displayed.
    expect(find.byType(HomeScreen), findsOneWidget);
    
    // Verify that ChatTab is the default tab.
    expect(find.byType(ChatTab), findsOneWidget);
    
    // Verify app title.
    expect(find.text('Wally AI'), findsOneWidget);
    // In tests, kDebugMode is true, so it should show '(dev)' by default
    expect(find.textContaining('(dev)'), findsOneWidget);
  });
}
