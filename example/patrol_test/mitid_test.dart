// Local-only: a real Danish MitID login on a physical device, through the hosted
// page, an app switch into the MitID test app and back. The Flutter counterpart of
// the native SDKs' `testMitID` / `runMitID`. Unlike the mock login it drives the
// browser and the MitID app, through Patrol's native automation.
//
// Skipped unless the test user is passed in with --dart-define=MITID_USER_ID=...
// and --dart-define=MITID_PIN=..., so nothing here runs by accident. On Android,
// --dart-define=EXPECT_TAB=auth|custom also asserts which tab the SDK opened.
// How to run it on each platform is in DEVELOPING.md, "End-to-end tests".

import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:idura_verify_example/main.dart';
import 'package:patrol/patrol.dart';

const _userId = String.fromEnvironment('MITID_USER_ID');
const _pin = String.fromEnvironment('MITID_PIN');
const _expectTab = String.fromEnvironment('EXPECT_TAB');
const _expectContinue = bool.fromEnvironment('EXPECT_CONTINUE');

/// The process that renders an ASWebAuthenticationSession's page.
const _iosBrowser = 'com.apple.SafariViewService';
const _iosMitID = 'eu.nets.mitid.ios.staging';
const _androidMitID = 'dk.mitid.app.android';

const _step = Duration(seconds: 30);

void main() {
  patrolTest(
    'a MitID login comes back logged in',
    skip: _userId.isEmpty || _pin.isEmpty,
    ($) async {
      await $.pumpWidgetAndSettle(const ExampleApp());
      await $('Danish MitID').tap();

      if (Platform.isAndroid) await _expectTabType();
      await _enterUserId($);
      await _webTap($, 'CONTINUE');
      await _webTap($, 'OPEN MITID APP');

      for (final digit in _pin.split('')) {
        await _mitIDTapKey($, digit);
      }
      await _swipeApprove($);
      if (_expectContinue) {
        await $.platform.android.tap(
          AndroidSelector(textStartsWith: 'CONTINUE TO'),
          timeout: _step,
        );
      }

      await $(
        'Logged in',
      ).waitUntilVisible(timeout: const Duration(seconds: 60));
      expect(find.textContaining('identityscheme: dkmitid'), findsOneWidget);
    },
  );
}

/// Reads the tab type from the SDK's own `Using <browser> <version>, <TabType>`
/// log line. The browser's UI can't tell the two apart: older Chrome Custom Tabs
/// lack the minimize button that newer ones have and Auth Tabs never do.
Future<void> _expectTabType() async {
  if (_expectTab.isEmpty) return;
  final expected = {'auth': 'AuthTab', 'custom': 'CustomTab'}[_expectTab];
  expect(expected, isNotNull, reason: 'EXPECT_TAB must be auth or custom');

  final used = RegExp(r'IduraVerify: Using .*, (\w+)$', multiLine: true);
  final deadline = DateTime.now().add(_step);
  String? actual;
  while (actual == null && DateTime.now().isBefore(deadline)) {
    // An app can read its own log; --pid skips lines left by earlier runs.
    final log = await Process.run('logcat', [
      '-d',
      '--pid=$pid',
      '-s',
      'IduraVerify:I',
    ]);
    actual = used.allMatches(log.stdout as String).lastOrNull?.group(1);
    if (actual == null) await Future<void>.delayed(const Duration(seconds: 1));
  }
  expect(actual, expected, reason: 'the SDK opened the login in another tab');
}

Future<void> _enterUserId(PatrolIntegrationTester $) =>
    $.platform.action.mobile(
      ios: () => $.platform.ios.enterText(
        IOSSelector(elementType: IOSElementType.textField, label: 'User ID'),
        text: _userId,
        appId: _iosBrowser,
        keyboardBehavior: KeyboardBehavior.alternative,
        timeout: _step,
      ),
      android: () async {
        final field = AndroidSelector(className: 'android.widget.EditText');
        await $.platform.android.tap(field, timeout: _step);
        await $.platform.android.enterText(
          field,
          text: _userId,
          keyboardBehavior: KeyboardBehavior.alternative,
          timeout: _step,
        );
      },
    );

/// A button or link on the hosted page, by its visible text.
Future<void> _webTap(PatrolIntegrationTester $, String label) =>
    $.platform.action.mobile(
      ios: () => $.platform.ios.tap(
        IOSSelector(label: label),
        appId: _iosBrowser,
        timeout: _step,
      ),
      // Exact: textContains is case-insensitive, so 'OPEN MITID APP' would also
      // match the "Open MitID app and approve" heading above the button.
      android: () =>
          $.platform.android.tap(AndroidSelector(text: label), timeout: _step),
    );

Future<void> _mitIDTapKey(PatrolIntegrationTester $, String digit) =>
    $.platform.action.mobile(
      ios: () => $.platform.ios.tap(
        IOSSelector(elementType: IOSElementType.key, identifier: digit),
        appId: _iosMitID,
        timeout: _step,
      ),
      android: () => $.platform.android.tap(
        AndroidSelector(text: digit, applicationPackage: _androidMitID),
        timeout: _step,
      ),
    );

/// MitID approves with a swipe-to-approve slider, dragged across its full width.
/// Patrol swipes in screen fractions, so the slider's frame is converted.
Future<void> _swipeApprove(PatrolIntegrationTester $) async {
  final view = PlatformDispatcher.instance.views.first;
  await $.platform.action.mobile(
    ios: () async {
      final approve = IOSSelector(label: 'Approve');
      await $.platform.ios.waitUntilVisible(
        approve,
        appId: _iosMitID,
        timeout: _step,
      );
      final views = await $.platform.ios.getNativeViews(
        approve,
        appId: _iosMitID,
      );
      final frame = views.roots.first.frame;
      // XCUITest frames are in points, which are Flutter's logical pixels.
      final screen = view.physicalSize / view.devicePixelRatio;
      await $.platform.ios.swipe(
        from: _fraction(frame.minX + frame.width * 0.05, frame.midY, screen),
        to: _fraction(frame.minX + frame.width * 0.98, frame.midY, screen),
        appId: _iosMitID,
      );
    },
    android: () async {
      final approve = AndroidSelector(contentDescription: 'Approve');
      await $.platform.android.waitUntilVisible(approve, timeout: _step);
      final views = await $.platform.android.getNativeViews(approve);
      final bounds = views.roots.first.visibleBounds;
      // UiAutomator bounds are in physical pixels.
      final screen = view.physicalSize;
      await $.platform.android.swipe(
        from: _fraction(bounds.minX + bounds.width * 0.05, bounds.midY, screen),
        to: _fraction(bounds.minX + bounds.width * 0.98, bounds.midY, screen),
      );
    },
  );
}

Offset _fraction(double x, double y, Size screen) =>
    Offset(x / screen.width, y / screen.height);

extension on Rectangle {
  double get width => maxX - minX;
  double get midY => (minY + maxY) / 2;
}
