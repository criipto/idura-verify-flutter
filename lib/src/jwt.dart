import 'dart:convert';

/// The claims of an ID token, decoded but deliberately not verified.
///
/// The native SDK verified the signature, issuer, audience and validity window
/// before the token crossed the bridge, so nothing here repeats that work — this
/// is a JSON decode and nothing more. Treating a token from any other source as
/// trustworthy because it decoded is a vulnerability, not a shortcut.
///
/// The named claims are the ones both native SDKs surface, and the native
/// verification step requires all of them, so they are non-nullable. Everything
/// else — whatever your requested scopes returned — is reachable through
/// [operator []] and [raw].
final class Claims {
  const Claims._({
    required this.subject,
    required this.audience,
    required this.issuer,
    required this.identityScheme,
    required this.issuedAt,
    required this.notBefore,
    required this.expiresAt,
    required this.raw,
  });

  /// Decodes the payload of [idToken].
  ///
  /// Throws a [FormatException] if it is not a JWT whose payload is a JSON
  /// object carrying every claim below. A token that reached you from a login
  /// cannot fail this, because the native verification step rejects such a token
  /// first.
  factory Claims.fromIdToken(String idToken) {
    final claims = _decodePayload(idToken);
    return Claims._(
      subject: _string(claims, 'sub'),
      audience: _audience(claims),
      issuer: _string(claims, 'iss'),
      identityScheme: _string(claims, 'identityscheme'),
      issuedAt: _timestamp(claims, 'iat'),
      notBefore: _timestamp(claims, 'nbf'),
      expiresAt: _timestamp(claims, 'exp'),
      raw: Map.unmodifiable(claims),
    );
  }

  /// `sub`: the user's identifier, stable per eID and per Idura domain.
  final String subject;

  /// `aud`: your client id.
  final String audience;

  /// `iss`: your Idura domain.
  final String issuer;

  /// `identityscheme`: which eID authenticated the user, e.g. `dkmitid` or
  /// `mock`.
  final String identityScheme;

  /// `iat`, in UTC.
  final DateTime issuedAt;

  /// `nbf`, in UTC.
  final DateTime notBefore;

  /// `exp`, in UTC. Already checked natively; exposed for your own logging
  /// rather than as something to act on.
  final DateTime expiresAt;

  /// Every claim in the payload, including the named ones above. Unmodifiable.
  final Map<String, Object?> raw;

  /// The value of an arbitrary claim, or `null` if the token has none.
  ///
  /// Use this for the claims your scopes add, e.g. `claims['address']` after
  /// requesting the `address` scope.
  Object? operator [](String claim) => raw[claim];
}

/// None of the messages below quote the token or any claim value. An ID token is
/// a credential and the payload is personal data, so a decode failure must stay
/// safe to log.
Map<String, Object?> _decodePayload(String idToken) {
  final parts = idToken.split('.');
  if (parts.length != 3) {
    throw FormatException(
      'Not a JWT: expected three dot separated parts, got ${parts.length}.',
    );
  }

  final Object? payload;
  try {
    payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
  } on FormatException catch (e) {
    throw FormatException(
      'The JWT payload is not base64url encoded JSON: ${e.message}',
    );
  }

  if (payload is! Map<String, Object?>) {
    throw const FormatException('The JWT payload is not a JSON object.');
  }
  return payload;
}

String _string(Map<String, Object?> claims, String name) {
  final value = claims[name];
  if (value is! String) {
    throw FormatException("The JWT payload has no string '$name' claim.");
  }
  return value;
}

String _audience(Map<String, Object?> claims) {
  final value = claims['aud'];
  // The JWT spec allows a single string or an array. An ID token issued to a
  // public client only ever has one audience, so take the first entry, as both
  // native SDKs do.
  if (value is String) return value;
  if (value is List && value.isNotEmpty) {
    final first = value.first;
    if (first is String) return first;
  }
  throw const FormatException(
    "The JWT payload has no 'aud' claim holding a string.",
  );
}

DateTime _timestamp(Map<String, Object?> claims, String name) {
  final value = claims[name];
  if (value is! num) {
    throw FormatException("The JWT payload has no numeric '$name' claim.");
  }
  // Seconds since the epoch, per RFC 7519's NumericDate.
  return DateTime.fromMillisecondsSinceEpoch(
    (value * 1000).round(),
    isUtc: true,
  );
}
