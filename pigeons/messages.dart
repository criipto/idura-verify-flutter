// The single source of truth for the Dart <-> native bridge. Regenerate with
// scripts/generate.sh after any change here, and commit the output alongside it.
//
// The wire format follows @criipto/verify-expo's LoginParams / NativeLoginResult
// so the mapping already proven in the Expo module ports across: the eID builders
// resolve to a flat request on the Dart side, and the native bridge only has to
// replay it onto `Other(acrValue)`.
//
// One deliberate divergence: scopes and login hints cross as lists, where Expo
// space joins them into a single string. Both of Expo's native bridges split that
// string straight back apart on `" "`, because the SDKs model them as
// `scopes: [String]` / `loginHints: [String]` and only join at the OIDC request.
// The join was a detour that could corrupt any entry containing a space.

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    kotlinOut: 'android/src/main/kotlin/eu/idura/verify/flutter/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'eu.idura.verify.flutter'),
    swiftOut: 'ios/idura_verify/Sources/idura_verify/Messages.g.swift',
    dartPackageName: 'idura_verify',
  ),
)
/// The OIDC `prompt` parameter.
///
/// Defaults to [Prompt.login] on both platforms, so a login always starts a
/// fresh authentication rather than silently reusing an existing session. Pass
/// `null` to omit the parameter entirely.
///
/// Lives in the schema rather than in hand-written Dart, and is re-exported as
/// public API: pigeon then guarantees the Dart, Kotlin and Swift copies of this
/// list are the same list, so no value can reach the native side that it has to
/// reject. Both SDKs already model `prompt` as an enum, and they own the
/// `consentRevoke` -> `consent_revoke` spelling, so nothing here needs a wire
/// value.
enum Prompt {
  /// Always authenticate, ignoring any existing session.
  login,

  /// Never show UI; fail instead if the user is not already authenticated.
  none,

  /// Ask the user to consent to the requested scopes.
  consent,

  /// Ask the user to consent again, discarding a previously granted consent.
  consentRevoke,
}

class NativeLoginRequest {
  NativeLoginRequest({
    required this.acrValues,
    required this.scopes,
    required this.loginHints,
    this.prompt,
    this.preferEphemeralSession,
  });

  /// Colon joined, which is the single `acrValue` both SDKs' `Other` takes.
  String acrValues;

  /// One entry per `withScope` call, never joined. Empty rather than null when
  /// there are none, so neither bridge needs a nullable branch.
  List<String> scopes;

  /// One entry per `withLoginHint` call, never joined.
  List<String> loginHints;

  /// Null omits the parameter entirely.
  Prompt? prompt;

  /// iOS only. Silently ignored on Android, which has no equivalent.
  bool? preferEphemeralSession;
}

/// Every setup mistake we can name, so the Dart side can turn each into a
/// message that states the fix rather than a generic failure.
enum NotConfiguredCode {
  missingDomain,
  missingClientId,
  invalidDomain,

  /// Android: the host activity does not implement `LifecycleOwner`, which the
  /// SDK follows to know when to initialise and when to release what it holds.
  /// Both Flutter activity base classes are one, so this needs a hand-rolled
  /// host to reach.
  hostActivityNotLifecycleOwner,

  /// Android: the native SDK allows one instance per activity, and two Flutter
  /// engines sharing an activity each construct their own. Plugin instances are
  /// per engine, so nothing the host app wrote is wrong.
  duplicateInstance,

  /// iOS: the associated-domains entitlement is absent.
  associatedDomainsNotConfigured,
  noActivity,
}

/// Outcomes travel as data on the success path, never as a channel error, so a
/// `traceId` stays attached to every outcome including cancellation — which is
/// what makes the native SDKs' telemetry correlatable from Dart.
///
/// Sealed on purpose: Dart gets a compile error when a new variant is added and
/// a `switch` is not updated, and Kotlin gets the same from an exhaustive `when`.
sealed class NativeLoginResult {}

class NativeLoginSuccess extends NativeLoginResult {
  NativeLoginSuccess(this.idToken, this.traceId);

  /// Already signature-verified by the native SDK. Dart only decodes it.
  String idToken;
  String traceId;
}

class NativeUserCancelled extends NativeLoginResult {
  NativeUserCancelled(this.traceId);
  String? traceId;
}

/// Android only: no browser on the device can host the flow.
class NativeNoSuitableBrowser extends NativeLoginResult {
  NativeNoSuitableBrowser(this.traceId);
  String? traceId;
}

class NativeOAuthError extends NativeLoginResult {
  NativeOAuthError(this.error, this.errorDescription, this.traceId);
  String error;
  String? errorDescription;
  String? traceId;
}

/// Android only: the SDK rejects a second concurrent login, before it makes any
/// network request and without disturbing the one already running.
class NativeFlowAlreadyInProgress extends NativeLoginResult {
  NativeFlowAlreadyInProgress(this.traceId);
  String? traceId;
}

class NativeNotConfigured extends NativeLoginResult {
  NativeNotConfigured(this.code, this.message, this.traceId);
  NotConfiguredCode code;
  String message;

  /// Null for every Android code and for the iOS ones raised while reading the
  /// configuration, because those all happen before a flow exists. Set for
  /// [NotConfiguredCode.associatedDomainsNotConfigured], which iOS only learns
  /// about once `ASWebAuthenticationSession` has already failed inside a span.
  String? traceId;
}

class NativeInternalError extends NativeLoginResult {
  NativeInternalError(this.message, this.traceId);
  String message;
  String? traceId;
}

@HostApi()
abstract class IduraVerifyHostApi {
  @async
  NativeLoginResult login(NativeLoginRequest request);

  /// Builds the native SDK if it is not built yet, taking OIDC discovery, the
  /// JWKS fetch and Android's scan for a usable browser off the login path.
  ///
  /// Returns nothing, and no result variant: there is nothing a caller could act
  /// on, because a real misconfiguration surfaces from [login] as a
  /// [NativeNotConfigured] either way. The native side logs instead, since a
  /// warm-up that quietly does nothing is otherwise invisible while an
  /// integration is being wired up.
  ///
  /// `@async` for the same reason [login] is: constructing the SDK is main-thread
  /// work on both platforms, and only the generated suspending form puts the
  /// bridge there.
  @async
  void warmUp();
}
