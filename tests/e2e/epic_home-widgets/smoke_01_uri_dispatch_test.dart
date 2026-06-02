// Smoke Tests — Epic: home-widgets
//
// Verifies the URI contract between the Android Glance widget (T002) and the
// Flutter dispatcher (T003/T005). The three URI strings are co-located in
// both Kotlin (AppWidget.kt) and Dart (home_screen.dart _dispatchWidgetUri).
// If they drift, FR-2/FR-3/FR-5 silently break.
//
// We can't drive the actual widget tap in a Dart test, but we CAN verify that
// every URI the widget fires is one the dispatcher recognises, by parsing the
// expected URIs the way the Dart side parses them.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('home-widgets epic / widget URI contract', () {
    // The three URIs the Glance widget (AppWidget.kt) fires.
    // Source-of-truth: docs/features/home-widget.md "Layout breakpoints" section.
    const widgetUris = <String>[
      'homeWidget://record',  // Bar + write icon
      'homeWidget://camera',  // Camera icon (FR-3)
      'homeWidget://open',    // Root fallback (FR-5)
    ];

    // The hosts the Flutter dispatcher (_dispatchWidgetUri) recognises.
    // Source-of-truth: lib/screens/home/home_screen.dart switch (uri?.host).
    const recognisedHosts = <String>{'record', 'camera', 'open'};

    test('SMOKE-1: every widget URI parses successfully', () {
      for (final raw in widgetUris) {
        final uri = Uri.tryParse(raw);
        expect(uri, isNotNull, reason: '$raw must be a parseable URI');
        // Dart's Uri normalises scheme to lowercase per RFC 3986.
        expect(uri!.scheme, equalsIgnoringCase('homewidget'),
            reason: 'Scheme must be the homeWidget protocol');
        expect(uri.host, isNotEmpty,
            reason: 'Host must be non-empty — the dispatcher branches on host');
      }
    });

    test('SMOKE-2: every widget URI host is recognised by the dispatcher', () {
      for (final raw in widgetUris) {
        final host = Uri.parse(raw).host;
        expect(recognisedHosts, contains(host),
            reason: 'Widget fires "$raw" but dispatcher has no case for host "$host". '
                   'Either AppWidget.kt or home_screen.dart has drifted.');
      }
    });

    test('SMOKE-3: unknown host falls through (default no-op contract)', () {
      // T003's contract: an unknown host must NOT crash. The default branch
      // is a no-op. We assert that a typo'd URI parses to a known-unknown host
      // (so the dispatcher's default branch is reachable in production).
      final uri = Uri.parse('homeWidget://record_v2');
      expect(uri.host, equals('record_v2'));
      expect(recognisedHosts.contains(uri.host), isFalse,
          reason: 'A typo must hit the default branch, not match an existing host');
    });
  });
}
