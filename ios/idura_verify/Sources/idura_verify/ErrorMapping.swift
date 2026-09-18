import Foundation
import IduraVerify

/// Turns anything the SDK can throw into a result variant.
///
/// Failures ride the success path as data rather than crossing as a channel error,
/// which is what keeps `traceId` attached to every outcome including cancellation.
///
/// Two variants never appear here. `NativeNoSuitableBrowser` and
/// `NativeFlowAlreadyInProgress` are Android-only: `ASWebAuthenticationSession` is
/// always available, and the iOS SDK has no concurrent-flow guard to trip.
func nativeLoginResult(from error: any Error) -> NativeLoginResult {
  switch error {
  case let signal as NotConfiguredSignal:
    return NativeNotConfigured(
      code: signal.code,
      message: signal.message,
      traceId: signal.traceId
    )

  case IduraVerifyError.userCancelled(let traceId):
    return NativeUserCancelled(traceId: traceId)

  case IduraVerifyError.associatedDomainsNotConfigured(let traceId):
    // The one setup mistake that carries a trace id: the entitlement is invisible
    // until ASWebAuthenticationSession has already failed inside a span. Everything
    // else in NotConfiguredCode is detected before a flow exists.
    return NativeNotConfigured(
      code: .associatedDomainsNotConfigured,
      message: (error as? LocalizedError)?.errorDescription
        ?? "The app is missing the Associated Domains entitlement for your Idura domain.",
      traceId: traceId
    )

  case IduraVerifyError.oauth(let oauthError, let errorDescription, let traceId):
    return NativeOAuthError(
      error: oauthError,
      errorDescription: errorDescription,
      traceId: traceId
    )

  case IduraVerifyError.internalError(let message, _, let traceId):
    return NativeInternalError(message: message, traceId: traceId)

  // A net, not a route we expect traffic on: `IduraVerify.login` funnels everything
  // through `IduraVerifyError.from`, so nothing else should reach us. Anything that
  // does is a leak worth reporting, so name the type — these messages exist for a
  // support ticket rather than for a user.
  default:
    return NativeInternalError(
      message: "\(type(of: error)): \(error.localizedDescription)"
    )
  }
}
