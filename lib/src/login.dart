import 'eid.dart';
import 'exceptions.dart';
import 'jwt.dart';
import 'login_result.dart';
import 'messages.g.dart';

/// The bridge [login] calls through.
///
/// A library-level variable so this package's own tests can substitute a fake
/// and drive every `NativeLoginResult` variant with no native code and no
/// device. `idura_verify.dart` exports `login` only, so this is not reachable
/// from a consumer's import: dropping the federated platform interface removed
/// `IduraVerifyPlatform.instance`, which was also the test seam, and this is
/// what replaces it.
IduraVerifyHostApi hostApi = IduraVerifyHostApi();

/// Logs the user in with [eid] and returns their natively verified ID token.
///
/// There is nothing to initialise first: the domain and client id are read from
/// your `AndroidManifest.xml` and `Info.plist` by the native SDK, so a
/// misconfiguration surfaces as a [NotConfiguredException] naming the fix.
///
/// ```dart
/// try {
///   final result = await login(DanishMitID.substantial().withSsn());
///   print(result.claims['ssn']);
/// } on UserCancelledException {
///   // The user backed out.
/// }
/// ```
///
/// [prompt] defaults to [Prompt.login], so a login always authenticates the user
/// afresh rather than silently reusing a session they may not expect. Pass
/// `null` to omit the parameter and let the server decide.
///
/// [preferEphemeralSession] asks iOS for a browser session that shares no
/// cookies with Safari, at the cost of the user having no way to be remembered.
/// Android has no equivalent, and ignores it rather than making you branch on
/// platform.
///
/// Throws a subclass of [IduraVerifyException] for every failure, including
/// cancellation. Never returns null and never completes with a raw platform
/// error.
Future<LoginResult> login(
  Eid eid, {
  Prompt? prompt = Prompt.login,
  bool? preferEphemeralSession,
}) async {
  final result = await hostApi.login(
    NativeLoginRequest(
      acrValues: eid.acrValue,
      scopes: eid.scopes,
      // The action is encoded here rather than natively, so the `Other` the
      // bridge constructs never carries one and cannot append it twice. Last,
      // matching the order the native SDKs assemble their hints in.
      loginHints: [
        ...eid.loginHints,
        if (eid.action case final action?) 'action:${action.wireValue}',
      ],
      prompt: prompt,
      preferEphemeralSession: preferEphemeralSession,
    ),
  );

  switch (result) {
    case NativeLoginSuccess(:final idToken, :final traceId):
      return LoginResult(
        idToken: idToken,
        traceId: traceId,
        claims: _decode(idToken, traceId),
      );
    case NativeUserCancelled(:final traceId):
      throw UserCancelledException(traceId: traceId);
    case NativeNoSuitableBrowser(:final traceId):
      throw NoSuitableBrowserException(traceId: traceId);
    case NativeOAuthError(
      :final error,
      :final errorDescription,
      :final traceId,
    ):
      // `access_denied` is cancellation under its spec name — the eID apps
      // report it that way when the user aborts inside them. Collapsing it here
      // is what lets callers handle cancellation in one place.
      throw error == 'access_denied'
          ? UserCancelledException(traceId: traceId)
          : OAuth2Exception(
              error: error,
              errorDescription: errorDescription,
              traceId: traceId,
            );
    case NativeFlowAlreadyInProgress():
      throw const LoginAlreadyInProgressException();
    case NativeNotConfigured(:final code, :final message):
      throw NotConfiguredException(code: code, message: message);
    case NativeInternalError(:final message, :final traceId):
      throw IduraVerifyInternalException(message: message, traceId: traceId);
  }
}

/// The native SDK verified this token's signature and issuer before handing it
/// over, so a payload we cannot read means the SDK changed under us rather than
/// anything a caller did. Still translated, so nothing outside the
/// [IduraVerifyException] hierarchy escapes [login].
Claims _decode(String idToken, String traceId) {
  try {
    return Claims.fromIdToken(idToken);
  } on FormatException catch (e) {
    throw IduraVerifyInternalException(
      message: 'Could not decode the ID token: ${e.message}',
      traceId: traceId,
    );
  }
}
