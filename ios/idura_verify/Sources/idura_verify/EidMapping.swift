import IduraVerify
import SdkAliases

/// Rebuilds the eID the Dart builders resolved.
///
/// Always `Other`, never a typed builder. Dart has already produced the acr
/// value, the scopes and the hints, and both SDKs derive app-switch behaviour
/// from the acr value's prefix rather than from which struct assembled it, so
/// this is not a lesser path.
///
/// Folded through `withScope`/`withLoginHint` rather than assigning the arrays,
/// so the SDK keeps ownership of what appending a scope means. The action
/// arrives already encoded as a login hint, so `eid.action` stays nil here and
/// `IduraVerify.login` does not append a second `action:` hint of its own.
func makeEid(_ request: NativeLoginRequest) -> Other {
  let base = Other(acrValue: request.acrValues)
  let withScopes = request.scopes.reduce(base) { $0.withScope($1) }
  return request.loginHints.reduce(withScopes) { $0.withLoginHint($1) }
}

/// Maps the generated prompt onto the SDK's own.
///
/// Exhaustive, so growing the pigeon enum stops compiling here.
func sdkPrompt(_ prompt: Prompt) -> SdkPrompt {
  switch prompt {
  case .login: return .login
  case Prompt.none: return SdkPrompt.none
  case .consent: return .consent
  case .consentRevoke: return .consentRevoke
  }
}

/// Never called. It exists so the compiler notices the *SDK's* `Prompt` growing
/// a case, which `sdkPrompt` above cannot: that switch only proves every pigeon
/// value maps onto something, not that every SDK value is reachable from
/// Flutter. A new SDK prompt breaks this switch and nothing else.
///
/// Android asserts the same property by comparing case counts, which needs both
/// enums to be enumerable. Pigeon's is `CaseIterable`; the SDK's is a bare `String`
/// enum, so an exhaustive switch is the only version of the check available here.
/// Verified by deleting a case: the build fails with "Switch must be exhaustive".
func pigeonPrompt(_ prompt: SdkPrompt) -> Prompt {
  switch prompt {
  case .login: return .login
  case SdkPrompt.none: return Prompt.none
  case .consent: return .consent
  case .consentRevoke: return .consentRevoke
  }
}
