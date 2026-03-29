// Smoke Tests — Epic: home-widget-android
// Tests structural correctness of widget code without requiring an emulator.
// Verifies AppWidget.kt and record_provider.dart changes are correct.

import 'dart:io';

void main() {
  final failures = <String>[];

  // ─── AppWidget.kt checks ───────────────────────────────────────────────────
  final appWidgetFile = File(
    'android/app/src/main/kotlin/com/example/wallet_ai/AppWidget.kt',
  );
  assert(appWidgetFile.existsSync(), 'AppWidget.kt must exist');
  final appWidgetContent = appWidgetFile.readAsStringSync();

  // SC-1: 5 breakpoints defined
  final breakpoints = ['SMALL', 'TALL', 'WIDE', 'MEDIUM', 'LARGE'];
  for (final bp in breakpoints) {
    if (!appWidgetContent.contains('val $bp')) {
      failures.add('SC-1: Missing breakpoint: $bp');
    }
  }

  // SC-2: SizeMode.Responsive includes all 5 breakpoints
  if (!appWidgetContent.contains('SizeMode.Responsive(setOf(SMALL, TALL, WIDE, MEDIUM, LARGE))')) {
    failures.add('SC-2: SizeMode.Responsive does not include all 5 breakpoints');
  }

  // SC-3: SmallLayout uses ic_menu_edit (pencil), not ic_input_add (add)
  if (appWidgetContent.contains('ic_input_add')) {
    failures.add('SC-3: SmallLayout still uses ic_input_add — should use ic_menu_edit');
  }
  if (!appWidgetContent.contains('ic_menu_edit')) {
    failures.add('SC-3: SmallLayout missing ic_menu_edit pencil icon');
  }

  // SC-4: SmallLayout has "Quick Record..." text
  if (!appWidgetContent.contains('"Quick Record..."')) {
    failures.add('SC-4: SmallLayout missing "Quick Record..." hint text');
  }

  // SC-5: TallLayout composable exists
  if (!appWidgetContent.contains('fun TallLayout(')) {
    failures.add('SC-5: TallLayout composable not defined');
  }

  // SC-6: MediumLayout composable exists
  if (!appWidgetContent.contains('fun MediumLayout(')) {
    failures.add('SC-6: MediumLayout composable not defined');
  }

  // SC-7: current_month key read in MediumLayout or LargeDashboard
  if (!appWidgetContent.contains('"current_month"')) {
    failures.add('SC-7: current_month preference key not referenced in AppWidget.kt');
  }

  // SC-8: homeWidget://record deep link present in SmallLayout tap handler
  if (!appWidgetContent.contains('homeWidget://record')) {
    failures.add('SC-8: homeWidget://record deep link missing from widget tap handlers');
  }

  // SC-9: Routing thresholds (130dp and 200dp separators)
  if (!appWidgetContent.contains('130.dp')) {
    failures.add('SC-9: Expected 130.dp routing threshold not found in AppWidget.kt');
  }
  if (!appWidgetContent.contains('200.dp')) {
    failures.add('SC-9: Expected 200.dp routing threshold not found in AppWidget.kt');
  }

  // ─── RecordProvider checks ─────────────────────────────────────────────────
  final providerFile = File('lib/providers/record_provider.dart');
  assert(providerFile.existsSync(), 'record_provider.dart must exist');
  final providerContent = providerFile.readAsStringSync();

  // SC-10: _updateWidget uses filteredTotalIncome (not manual loop)
  if (!providerContent.contains('filteredTotalIncome')) {
    failures.add('SC-10: _updateWidget() does not use filteredTotalIncome getter');
  }

  // SC-11: _updateWidget uses filteredTotalExpense (not manual loop)
  if (!providerContent.contains('filteredTotalExpense')) {
    failures.add('SC-11: _updateWidget() does not use filteredTotalExpense getter');
  }

  // SC-12: current_month key saved
  if (!providerContent.contains("'current_month'")) {
    failures.add("SC-12: _updateWidget() does not save 'current_month' key");
  }

  // SC-13: DateFormat used for month label
  if (!providerContent.contains('DateFormat')) {
    failures.add('SC-13: DateFormat not used for current_month formatting');
  }

  // SC-14: intl import present
  if (!providerContent.contains("package:intl/intl.dart")) {
    failures.add("SC-14: Missing import 'package:intl/intl.dart'");
  }

  // SC-15: No manual totalIncome loop (old all-time loop removed)
  // The old code had: "double totalIncome = 0;" inside _updateWidget
  // After the fix this local variable should not exist in _updateWidget scope
  final updateWidgetSection = _extractMethod(providerContent, '_updateWidget');
  if (updateWidgetSection.contains('double totalIncome') ||
      updateWidgetSection.contains('double totalSpend')) {
    failures.add('SC-15: _updateWidget() still contains manual totalIncome/totalSpend loop');
  }

  // ─── Results ───────────────────────────────────────────────────────────────
  if (failures.isEmpty) {
    print('✅ All smoke tests passed (15/15)');
    exit(0);
  } else {
    print('❌ ${failures.length} smoke test(s) failed:');
    for (final f in failures) {
      print('  - $f');
    }
    exit(1);
  }
}

String _extractMethod(String content, String methodName) {
  final start = content.indexOf('void $methodName()');
  if (start == -1) return '';
  final end = content.indexOf('\n  }', start);
  return end > start ? content.substring(start, end) : '';
}
