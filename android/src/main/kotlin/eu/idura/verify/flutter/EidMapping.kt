package eu.idura.verify.flutter

import eu.idura.verify.eid.EID
import eu.idura.verify.eid.Other
import eu.idura.verify.Prompt as SdkPrompt

/**
 * Rebuilds the eID the Dart builders resolved.
 *
 * Always [Other], never a typed builder. Dart has already produced the acr value,
 * the scopes and the hints, and both SDKs derive app-switch behaviour from the acr
 * value's prefix rather than from which class assembled it, so this is not a lesser
 * path.
 *
 * The action arrives as a login hint, encoded on the Dart side, so `eid.action`
 * stays null here.
 */
internal fun NativeLoginRequest.toEid(): EID<*> =
  Other(acrValues).also { eid ->
    scopes.forEach { eid.withScope(it) }
    loginHints.forEach { eid.withLoginHint(it) }
  }

/**
 * Maps the generated prompt onto the SDK's own.
 *
 * The `when` is exhaustive, so growing the pigeon enum stops compiling here. It
 * cannot notice the *SDK's* enum growing, which would leave a new prompt value
 * silently unreachable from Flutter — that is what the case-count assertion in
 * `PromptMappingTest` is for.
 */
internal fun Prompt.toSdk(): SdkPrompt =
  when (this) {
    Prompt.LOGIN -> SdkPrompt.Login
    Prompt.NONE -> SdkPrompt.None
    Prompt.CONSENT -> SdkPrompt.Consent
    Prompt.CONSENT_REVOKE -> SdkPrompt.ConsentRevoke
  }
