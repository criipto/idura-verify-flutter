import Foundation

/// The path the SDK appends to the domain for its redirect URI. Mirrors the default in
/// `IduraVerify.init`, which keeps the value internal; the plugin never overrides it.
private let returnLinkPath = "/ios/callback"

/// Whether [url] is the login's own return link: the redirect URI that eID apps open as
/// a Universal Link to bring the user back after an app switch.
///
/// The link only has to bring the app forward. `ASWebAuthenticationSession` finishes the
/// login on its own, so the link itself carries nothing for us to act on.
///
/// [domain] is the raw `IDURA_DOMAIN` value, which the SDK requires to be a bare
/// hostname, so comparing hosts is enough.
func isLoginReturnLink(_ url: URL?, domain: String?) -> Bool {
  guard let url,
    let domain = domain?.trimmingCharacters(in: .whitespacesAndNewlines),
    !domain.isEmpty
  else { return false }

  return url.scheme?.lowercased() == "https"
    && url.host()?.lowercased() == domain.lowercased()
    && url.path() == returnLinkPath
}
