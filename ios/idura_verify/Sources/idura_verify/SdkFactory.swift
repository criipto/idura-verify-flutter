import Foundation
import IduraVerify

/// `Info.plist` keys carrying the configuration at runtime.
///
/// These *are* public API on iOS, unlike the Android side where the app sets Gradle
/// placeholders and never names the `<meta-data>` keys behind them. Spelled the way
/// `@criipto/verify-expo`'s iOS module spells them, so an app migrating from Expo
/// keeps its `Info.plist`.
///
/// Configuration is read natively rather than passed from Dart so that a consumer
/// has no `initialize()` to forget, and so the value lives in one place per
/// platform.
let infoDomainKey = "IDURA_DOMAIN"
let infoClientIdKey = "IDURA_CLIENT_ID"

private func plistFix(_ key: String, _ example: String) -> String {
  "Add \(key) with a value like \"\(example)\" to your app's Info.plist."
}

/// A setup mistake in the host app, carrying the code and message Dart turns into a
/// `NotConfiguredException`.
///
/// An error rather than a return type so the checks below read as a straight line,
/// and so the SDK's own `IduraVerifyConfigurationError` joins the same channel.
struct NotConfiguredSignal: Error {
  let code: NotConfiguredCode
  let message: String

  /// Only ever set for `associatedDomainsNotConfigured`, which is the one setup
  /// mistake iOS cannot detect until a flow is already running.
  let traceId: String?

  init(_ code: NotConfiguredCode, _ message: String, traceId: String? = nil) {
    self.code = code
    self.message = message
    self.traceId = traceId
  }
}

struct Configuration: Equatable {
  let domain: String
  let clientId: String
}

/// Reads the two values. [info] is a lookup rather than a `Bundle` so this stays a
/// pure function.
///
/// Presence is all we check. The SDK validates the domain's shape itself before it
/// starts telemetry (`iduraDomainURL`, since 3.0.0) and does it more strictly than we
/// would, so `constructSdk` translates that error rather than duplicating the rule.
///
/// A blank value is treated as absent: an `Info.plist` key wired to a build setting
/// that no configuration defines expands to the empty string rather than
/// disappearing, which is the common shape of this mistake.
func readConfiguration(_ info: (String) -> String?) throws -> Configuration {
  guard let domain = info(infoDomainKey)?.nonBlank else {
    throw NotConfiguredSignal(
      .missingDomain,
      "Idura Verify is missing its domain. " + plistFix(infoDomainKey, "your-domain.criipto.id")
    )
  }

  guard let clientId = info(infoClientIdKey)?.nonBlank else {
    throw NotConfiguredSignal(
      .missingClientId,
      "Idura Verify is missing its client id. "
        + plistFix(infoClientIdKey, "urn:my:application:identifier:123")
    )
  }

  return Configuration(domain: domain, clientId: clientId)
}

/// Builds an SDK instance, or throws [NotConfiguredSignal] naming the fix.
///
/// Unlike Android there is no activity to bind to and no per-activity uniqueness
/// rule, so nothing here can fail for a reason the host app did not cause.
@MainActor
func constructSdk(_ info: (String) -> String?) throws -> IduraVerify {
  let configuration = try readConfiguration(info)

  do {
    return try IduraVerify(clientId: configuration.clientId, domain: configuration.domain)
  } catch let error as IduraVerifyConfigurationError {
    // The SDK's own `iduraDomainURL`, which owns the rules and is stricter than
    // anything we would write here. Pass its message through and add only the one
    // thing it cannot know: which Info.plist key the value came from.
    throw NotConfiguredSignal(
      .invalidDomain,
      (error.errorDescription ?? "\"\(configuration.domain)\" is not a valid Idura Verify domain.")
        + " " + plistFix(infoDomainKey, "your-domain.criipto.id")
    )
  }
}

private extension String {
  var nonBlank: String? {
    trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
  }
}
