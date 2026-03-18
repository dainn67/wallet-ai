import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/screens/home/home_screen.dart';

void main() {
  testWidgets('HomeScreen renders with TabBar and 3 tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: HomeScreen(),
    ));

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Records'), findsOneWidget);
    expect(find.text('Test'), findsOneWidget);
  });

  testWidgets('HomeScreen renders with TabBarView and Placeholders', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: HomeScreen(),
    ));

    expect(find.byType(TabBarView), findsOneWidget);
    expect(find.byType(Placeholder), findsWidgets);
  });

  testWidgets('HomeScreen has a Drawer', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: HomeScreen(),
    ));

    // Open drawer
    await tester.dragFrom(tester.getTopLeft(find.byType(HomeScreen)), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(find.byType(Drawer), findsOneWidget);
    expect(find.text('Wallet AI'), findsWidgets); // Both in AppBar and DrawerHeader
  });
}
