// End-to-end mock login against the example's tenant, the Flutter counterpart of
// the native SDKs' `runMockLogin` / `testMockLogin`. Nothing is faked: the tap goes
// through the bridge into the native SDK, out to the browser and the live tenant,
// and back through the App Link or associated-domain callback.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idura_verify_example/main.dart';
import 'package:patrol/patrol.dart';

/// A cold CI emulator round-tripping the browser, the token endpoint and the
/// JWKS fetch has been seen to need well over the default waits. Generous, so a
/// slow-but-working login is not reported as a failure.
const _loginTimeout = Duration(seconds: 90);

void main() {
  patrolTest('a mock login comes back logged in', ($) async {
    await $.pumpWidget(const ExampleApp());
    await $(FilledButton).$('Mock').tap();

    await _pumpUntilLoginEnds($.tester);

    expect(
      find.text('Logged in'),
      findsOneWidget,
      // Whatever the example rendered instead, which is usually a failure card
      // naming the reason. Its message is a SelectableText, so Text alone would
      // show the exception's type and drop the part that explains it.
      reason: $.tester.allWidgets.map(_text).nonNulls.join('\n'),
    );
    expect(find.textContaining('identityscheme: mock'), findsOneWidget);
    expect(find.textContaining('name: foobar'), findsOneWidget);
  });
}

/// Pumps until the example's progress indicator goes away, which it does on
/// every outcome, so a failed login fails the test straight away rather than
/// after the full timeout.
///
/// `pumpAndSettle` cannot be used: the indicator animates for as long as the
/// login is in flight, so the tree never settles.
Future<void> _pumpUntilLoginEnds(WidgetTester tester) async {
  final deadline = DateTime.now().add(_loginTimeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
  }
  throw TestFailure('Login still running after ${_loginTimeout.inSeconds}s');
}

String? _text(Widget widget) => switch (widget) {
  Text(:final data) || SelectableText(:final data) => data,
  _ => null,
};
