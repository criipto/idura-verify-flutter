import 'jwt.dart';

/// A completed login.
final class LoginResult {
  /// Creates a result. The plugin builds these for you; the constructor is
  /// public only so you can fake one in your own tests.
  const LoginResult({
    required this.idToken,
    required this.traceId,
    required this.claims,
  });

  /// The ID token, whose signature the native SDK has already verified.
  ///
  /// Send it to your backend, which should verify it independently before
  /// trusting anything in it — a token that arrived over your own API has not
  /// been through the native SDK.
  final String idToken;

  /// The Idura trace id for this login. Log it alongside your own error
  /// reporting; the flow is then greppable in the Idura dashboard.
  final String traceId;

  /// [idToken]'s payload, decoded and not re-verified.
  final Claims claims;
}
