import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:idura_verify/idura_verify.dart';
// Not a `package:idura_verify/idura_verify.dart` import: the bridge and the
// generated result variants are implementation details, so only this package's
// own tests can reach them.
import 'package:idura_verify/src/login.dart' as internal;
import 'package:idura_verify/src/messages.g.dart';

/// Stands in for the generated bridge. `extends` rather than `implements` so the
/// pigeon-internal members come along, which is the substitution pigeon 28
/// points at now that `dartTestOut` is deprecated.
class FakeHostApi extends IduraVerifyHostApi {
  FakeHostApi(this.result);

  final NativeLoginResult result;

  /// What [login] assembled, so the request is asserted on rather than assumed.
  NativeLoginRequest? lastRequest;

  @override
  Future<NativeLoginResult> login(NativeLoginRequest request) async {
    lastRequest = request;
    return result;
  }
}

/// Points [login] at a fake returning [result], and restores the real bridge
/// afterwards so one test cannot leak into the next.
FakeHostApi given(NativeLoginResult result) {
  final fake = FakeHostApi(result);
  internal.hostApi = fake;
  addTearDown(() => internal.hostApi = IduraVerifyHostApi());
  return fake;
}

/// Shaped like a real token from the mock flow. Only the payload is ever read.
const Map<String, Object?> _payload = {
  'iss': 'https://samples.criipto.id',
  'aud': 'urn:my:application:identifier:123',
  'sub': '{a3d0e0a0-0000-4000-8000-000000000001}',
  'identityscheme': 'mock',
  'iat': 1770000000,
  'nbf': 1770000000,
  'exp': 1770000300,
};

String idToken() {
  String segment(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

  return '${segment(const {'alg': 'RS256'})}'
      '.${segment(_payload)}'
      '.c2lnbmF0dXJl';
}

void main() {
  group('request assembly', () {
    test('flattens the eID into the acr value, scopes and hints', () async {
      final fake = given(
        NativeLoginSuccess(idToken: idToken(), traceId: 'trace-1'),
      );

      await login(DanishMitID.high().prefillSsn('1234564444'));

      expect(fake.lastRequest!.acrValues, 'urn:grn:authn:dk:mitid:high');
      expect(fake.lastRequest!.scopes, ['ssn']);
      expect(fake.lastRequest!.loginHints, ['sub:1234564444']);
    });

    test('encodes the action as the last login hint', () async {
      final fake = given(
        NativeLoginSuccess(idToken: idToken(), traceId: 'trace-1'),
      );

      await login(SwedishBankID.sameDevice().withSsn().sign('Sign here'));

      expect(fake.lastRequest!.loginHints, [
        'message:U2lnbiBoZXJl',
        'action:sign',
      ]);
    });

    test('omits the action hint when the eID carries none', () async {
      final fake = given(
        NativeLoginSuccess(idToken: idToken(), traceId: 'trace-1'),
      );

      await login(Vipps().withEmail());

      expect(fake.lastRequest!.loginHints, isEmpty);
      expect(fake.lastRequest!.scopes, ['email']);
    });

    test('defaults prompt to login rather than leaving it unset', () async {
      final fake = given(
        NativeLoginSuccess(idToken: idToken(), traceId: 'trace-1'),
      );

      await login(Mock());

      expect(fake.lastRequest!.prompt, Prompt.login);
      expect(fake.lastRequest!.preferEphemeralSession, isNull);
    });

    test('passes an explicit prompt through, including null', () async {
      var fake = given(
        NativeLoginSuccess(idToken: idToken(), traceId: 'trace-1'),
      );
      await login(Mock(), prompt: Prompt.consentRevoke);
      expect(fake.lastRequest!.prompt, Prompt.consentRevoke);

      fake = given(NativeLoginSuccess(idToken: idToken(), traceId: 'trace-1'));
      await login(Mock(), prompt: null);
      expect(fake.lastRequest!.prompt, isNull);
    });

    test('passes preferEphemeralSession through', () async {
      final fake = given(
        NativeLoginSuccess(idToken: idToken(), traceId: 'trace-1'),
      );

      await login(Mock(), preferEphemeralSession: true);

      expect(fake.lastRequest!.preferEphemeralSession, isTrue);
    });
  });

  group('success', () {
    test('returns the token, its trace id and the decoded claims', () async {
      given(NativeLoginSuccess(idToken: idToken(), traceId: 'trace-1'));

      final result = await login(Mock());

      expect(result.idToken, idToken());
      expect(result.traceId, 'trace-1');
      expect(result.claims.identityScheme, 'mock');
      expect(result.claims.subject, '{a3d0e0a0-0000-4000-8000-000000000001}');
    });

    test('an undecodable token stays inside the exception hierarchy', () async {
      given(NativeLoginSuccess(idToken: 'not.a.token', traceId: 'trace-1'));

      await expectLater(
        login(Mock()),
        throwsA(
          isA<IduraVerifyInternalException>().having(
            (e) => e.traceId,
            'traceId',
            'trace-1',
          ),
        ),
      );
    });
  });

  // One case per sealed variant. Adding a variant to the schema breaks login()'s
  // switch at compile time, so these assert the mapping rather than the coverage.
  group('failures', () {
    test('cancellation carries the trace id it was given', () async {
      given(NativeUserCancelled(traceId: 'trace-2'));

      await expectLater(
        login(Mock()),
        throwsA(
          isA<UserCancelledException>()
              .having((e) => e.traceId, 'traceId', 'trace-2')
              .having((e) => e.error, 'error', 'access_denied'),
        ),
      );
    });

    test('an access_denied OAuth error is cancellation too', () async {
      given(
        NativeOAuthError(
          error: 'access_denied',
          errorDescription: 'User cancelled',
          traceId: 'trace-3',
        ),
      );

      await expectLater(
        login(Mock()),
        throwsA(
          isA<UserCancelledException>().having(
            (e) => e.traceId,
            'traceId',
            'trace-3',
          ),
        ),
      );
    });

    test('any other OAuth error keeps its code and description', () async {
      given(
        NativeOAuthError(
          error: 'temporarily_unavailable',
          errorDescription: 'Try again later',
          traceId: 'trace-4',
        ),
      );

      await expectLater(
        login(Mock()),
        throwsA(
          isA<OAuth2Exception>()
              .having((e) => e.error, 'error', 'temporarily_unavailable')
              .having(
                (e) => e.errorDescription,
                'errorDescription',
                'Try again later',
              )
              .having((e) => e.traceId, 'traceId', 'trace-4')
              // The distinction the hierarchy exists for.
              .having(
                (e) => e is UserCancelledException,
                'is cancellation',
                isFalse,
              ),
        ),
      );
    });

    test('no suitable browser', () async {
      given(NativeNoSuitableBrowser(traceId: 'trace-5'));

      await expectLater(
        login(Mock()),
        throwsA(
          isA<NoSuitableBrowserException>().having(
            (e) => e.traceId,
            'traceId',
            'trace-5',
          ),
        ),
      );
    });

    test('a concurrent flow keeps the rejected call trace id', () async {
      given(NativeFlowAlreadyInProgress(traceId: 'trace-concurrent'));

      await expectLater(
        login(Mock()),
        throwsA(
          isA<LoginAlreadyInProgressException>().having(
            (e) => e.traceId,
            'traceId',
            'trace-concurrent',
          ),
        ),
      );
    });

    test('a setup mistake keeps the code and the native message', () async {
      given(
        NativeNotConfigured(
          code: NotConfiguredCode.hostActivityNotLifecycleOwner,
          message: 'MainActivity has to implement LifecycleOwner.',
        ),
      );

      await expectLater(
        login(Mock()),
        throwsA(
          isA<NotConfiguredException>()
              .having(
                (e) => e.code,
                'code',
                NotConfiguredCode.hostActivityNotLifecycleOwner,
              )
              .having(
                (e) => e.message,
                'message',
                'MainActivity has to implement LifecycleOwner.',
              )
              // No trace id: the flow never reached the backend.
              .having((e) => e.traceId, 'traceId', isNull),
        ),
      );
    });

    test('an internal failure', () async {
      given(
        NativeInternalError(message: 'Discovery failed', traceId: 'trace-6'),
      );

      await expectLater(
        login(Mock()),
        throwsA(
          isA<IduraVerifyInternalException>()
              .having((e) => e.message, 'message', 'Discovery failed')
              .having((e) => e.traceId, 'traceId', 'trace-6'),
        ),
      );
    });
  });
}
