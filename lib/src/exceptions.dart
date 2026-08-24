import 'messages.g.dart' show NotConfiguredCode;

/// Superclass of every error a login can fail with.
///
/// Catch this to handle any failure uniformly, or a subtype to tell user
/// cancellation apart from a real error. The hierarchy deliberately mirrors
/// `@criipto/verify-expo`'s, so the two wrappers read alike.
///
/// ```dart
/// try {
///   final result = await login(DanishMitID.substantial());
/// } on UserCancelledException {
///   // Normal: the user backed out. Return them to the previous screen.
/// } on NotConfiguredException catch (e) {
///   // A setup mistake in your app, not something the user did. e.message
///   // names the fix.
/// } on IduraVerifyException catch (e) {
///   // Anything else. Log e.traceId alongside your own error reporting.
/// }
/// ```
abstract class IduraVerifyException implements Exception {
  /// Creates an exception. Not intended to be called outside this package.
  const IduraVerifyException({required this.message, this.traceId});

  /// Aimed at you, not at the user. Never show it in the UI.
  final String message;

  /// The Idura trace id for this login, if the flow got far enough to have one.
  /// Look it up in the Idura dashboard to see what the backend saw.
  final String? traceId;

  @override
  String toString() => traceId == null
      ? '$runtimeType: $message'
      : '$runtimeType: $message (traceId: $traceId)';
}

/// The authorization server returned an OAuth 2.0 error response.
///
/// [error] is one of the standard OAuth 2.0 codes, e.g. `invalid_request` or
/// `temporarily_unavailable`. The spec-standard `access_denied` arrives as
/// [UserCancelledException] instead, so cancellation only has to be handled in
/// one place.
class OAuth2Exception extends IduraVerifyException {
  /// Creates an exception. Not intended to be called outside this package.
  OAuth2Exception({
    required String error,
    String? errorDescription,
    super.traceId,
  }) : error = error,
       errorDescription = errorDescription,
       super(
         message: errorDescription == null
             ? error
             : '$error ($errorDescription)',
       );

  /// The standard OAuth 2.0 error code.
  final String error;

  /// A human-readable elaboration, when the server sent one.
  final String? errorDescription;
}

/// The user backed out before the login completed.
///
/// Covers both dismissing the browser and cancelling inside the eID app, which
/// reaches us as OAuth 2.0 `access_denied`. Usually a normal action rather than
/// an error worth surfacing.
class UserCancelledException extends OAuth2Exception {
  /// Creates an exception. Not intended to be called outside this package.
  UserCancelledException({super.traceId})
    : super(error: 'access_denied', errorDescription: 'User cancelled login');
}

/// Android only: no browser on the device can host the flow.
///
/// In practice this means every browser has been disabled or uninstalled, which
/// nothing in your app can fix.
class NoSuitableBrowserException extends IduraVerifyException {
  /// Creates an exception. Not intended to be called outside this package.
  const NoSuitableBrowserException({super.traceId})
    : super(
        message:
            'No browser is available to host the login flow. Every browser on '
            'this device appears to be disabled or uninstalled.',
      );
}

/// Android only: a login was started while another was still in the browser.
///
/// The native SDK allows one flow at a time. Disable your login button until
/// the pending future completes.
class LoginAlreadyInProgressException extends IduraVerifyException {
  /// Creates an exception. Not intended to be called outside this package.
  const LoginAlreadyInProgressException()
    : super(
        message:
            'A login is already in progress. Wait for the pending login to '
            'complete before starting another.',
      );
}

/// Your app is not set up correctly, so no login can succeed.
///
/// Every case is a mistake in the host app's configuration rather than anything
/// the user did, and [message] names the specific fix. Match on [code] if you
/// want to react programmatically.
class NotConfiguredException extends IduraVerifyException {
  /// Creates an exception. Not intended to be called outside this package.
  const NotConfiguredException({required this.code, required super.message});

  /// Which setup mistake this is.
  final NotConfiguredCode code;
}

/// The SDK's own machinery failed in a way you cannot recover from.
///
/// Sources include OIDC discovery, the PAR endpoint, ID token verification and
/// browser plumbing. Show the user a generic message and log [traceId].
class IduraVerifyInternalException extends IduraVerifyException {
  /// Creates an exception. Not intended to be called outside this package.
  const IduraVerifyInternalException({required super.message, super.traceId});
}
