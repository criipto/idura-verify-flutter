import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:idura_verify/idura_verify.dart';

/// Assembles a JWT with an unpadded base64url payload, as a real issuer emits.
/// The signature is never looked at, so any placeholder will do.
String idTokenWith(Map<String, Object?> payload) {
  String segment(String json) =>
      base64Url.encode(utf8.encode(json)).replaceAll('=', '');

  return '${segment('{"alg":"RS256","kid":"abc"}')}'
      '.${segment(jsonEncode(payload))}'
      '.c2lnbmF0dXJl';
}

/// Shaped like a real mock-flow token from samples.criipto.id, so the required
/// claims are exercised together rather than one at a time.
Map<String, Object?> mockPayload({Map<String, Object?> overrides = const {}}) =>
    {
      'iss': 'https://samples.criipto.id',
      'aud': 'urn:my:application:identifier:123',
      'sub': '{a3d0e0a0-0000-4000-8000-000000000001}',
      'identityscheme': 'mock',
      'iat': 1770000000,
      'nbf': 1770000000,
      'exp': 1770000300,
      ...overrides,
    };

void main() {
  group('Claims.fromIdToken', () {
    test('decodes the claims both native SDKs surface', () {
      final claims = Claims.fromIdToken(idTokenWith(mockPayload()));

      expect(claims.issuer, 'https://samples.criipto.id');
      expect(claims.audience, 'urn:my:application:identifier:123');
      expect(claims.subject, '{a3d0e0a0-0000-4000-8000-000000000001}');
      expect(claims.identityScheme, 'mock');
      expect(claims.issuedAt, DateTime.utc(2026, 2, 2, 2, 40));
      expect(claims.notBefore, claims.issuedAt);
      expect(claims.expiresAt, claims.issuedAt.add(const Duration(minutes: 5)));
    });

    test('takes the first entry of an aud array', () {
      final claims = Claims.fromIdToken(
        idTokenWith(
          mockPayload(
            overrides: {
              'aud': ['first', 'second'],
            },
          ),
        ),
      );

      expect(claims.audience, 'first');
    });

    test('exposes scope-specific claims through [] and raw', () {
      final claims = Claims.fromIdToken(
        idTokenWith(
          mockPayload(
            overrides: {
              'name': 'Jørgen Åberg',
              'address': {'street': 'Vestergade 1', 'postalCode': '8000'},
              'is_over_18': true,
            },
          ),
        ),
      );

      // Non-ASCII survives, which is the whole reason the payload goes through
      // utf8.decode rather than String.fromCharCodes.
      expect(claims['name'], 'Jørgen Åberg');
      expect(claims['address'], {
        'street': 'Vestergade 1',
        'postalCode': '8000',
      });
      expect(claims['is_over_18'], isTrue);
      expect(claims['nothing_requested_this'], isNull);
      expect(claims.raw['identityscheme'], 'mock');
    });

    test('does not check the validity window', () {
      // Expired in 2001. Verification is the native SDK's job, and re-checking
      // here would reject tokens it deliberately accepts within its clock skew.
      final claims = Claims.fromIdToken(
        idTokenWith(
          mockPayload(
            overrides: {
              'iat': 1000000000,
              'nbf': 1000000000,
              'exp': 1000000300,
            },
          ),
        ),
      );

      expect(claims.expiresAt.isBefore(DateTime.now().toUtc()), isTrue);
    });

    test('exposes raw unmodifiably, so a decoded token cannot be edited', () {
      final claims = Claims.fromIdToken(idTokenWith(mockPayload()));

      expect(() => claims.raw['sub'] = 'someone else', throwsUnsupportedError);
    });

    group('throws a FormatException', () {
      test('when the token is not three parts', () {
        expect(
          () => Claims.fromIdToken('header.payload'),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('three dot separated parts, got 2'),
            ),
          ),
        );
      });

      test('when the payload is not base64url', () {
        expect(
          () => Claims.fromIdToken('header.not base64!.signature'),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('not base64url encoded JSON'),
            ),
          ),
        );
      });

      test('when the payload is not a JSON object', () {
        expect(
          () => Claims.fromIdToken(
            '${base64Url.encode(utf8.encode('{}')).replaceAll('=', '')}'
            '.${base64Url.encode(utf8.encode('"a string"')).replaceAll('=', '')}'
            '.signature',
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('not a JSON object'),
            ),
          ),
        );
      });

      test('when a required string claim is missing', () {
        final payload = mockPayload()..remove('identityscheme');

        expect(
          () => Claims.fromIdToken(idTokenWith(payload)),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains("no string 'identityscheme' claim"),
            ),
          ),
        );
      });

      test('when a required timestamp claim is not a number', () {
        expect(
          () => Claims.fromIdToken(
            idTokenWith(mockPayload(overrides: {'exp': '1770000300'})),
          ),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains("no numeric 'exp' claim"),
            ),
          ),
        );
      });

      test('when aud is neither a string nor a list of them', () {
        expect(
          () => Claims.fromIdToken(
            idTokenWith(mockPayload(overrides: {'aud': 42})),
          ),
          throwsA(isA<FormatException>()),
        );
      });

      test('without quoting the token or its claims', () {
        // A decode failure gets logged, and both the token and the payload are
        // sensitive, so neither may appear in the message.
        final token = idTokenWith(mockPayload(overrides: {'sub': 42}));

        expect(
          () => Claims.fromIdToken(token),
          throwsA(
            isA<FormatException>()
                .having((e) => e.message, 'message', isNot(contains(token)))
                .having((e) => e.source, 'source', isNull),
          ),
        );
      });
    });
  });
}
