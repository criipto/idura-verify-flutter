# idura_verify

The Idura Verify Flutter plugin allows your users to authenticate with a host of European eID providers. It allows your application to act as a [_public client_](https://docs.idura.app/verify/getting-started/glossary/#public-clients), meaning it does not use a client secret, but instead employs [PKCE](https://docs.idura.app/verify/getting-started/glossary/#pkce-proof-key-for-code-exchange) to ensure that a malicious actor cannot intercept the authorization code.

In addition to the basic OIDC flow, the plugin also supports [app switching](https://docs.idura.app/verify/guides/appswitch/).

The plugin wraps the native [Android](https://github.com/criipto/idura-verify-android) and [iOS](https://github.com/criipto/idura-verify-ios) SDKs, which both build on top of the AppAuth library maintained by the OpenID foundation. It requires:

- Flutter 3.44 or newer.
- Android API level 26 and up.
- iOS 17.4 and up, with Swift Package Manager enabled. The iOS SDK is distributed only as a Swift package, so CocoaPods is not supported. Swift Package Manager is the default from Flutter 3.44.

On Android, the plugin has been tested using Chrome (both Auth Tab and Custom Tab), Samsung Internet, Brave, and Microsoft Edge browsers. If the end-user has one of the browsers above installed, the plugin will use that, even if it is not the default browser. If not, the plugin will fall back to the default browser.
The plugin _can_ work with other browsers (such as Opera and Firefox). However, the end user will need to manually press "Open in app" after being redirected to the redirect URL.

# Installation

```sh
flutter pub add idura_verify
```

Android API level 26 is above Flutter's default, so raise it in `android/app/build.gradle.kts`:

```kts
android {
  defaultConfig {
    minSdk = 26
  }
}
```

# Usage

If you prefer a more interactive approach, there is an [example project](https://github.com/criipto/idura-verify-flutter/blob/master/example/README.md) which you can run and play around with.

## Configuration

The plugin needs to be configured with two pieces of information:

- Your Idura domain, as a bare host name such as `this-is-an-example.idura.broker`.
- Your Idura client ID.

The plugin assumes that:

- You will be using your [Idura domain](https://docs.idura.app/verify/getting-started/glossary/#domain-idura-domain) to host your redirect URL (both custom (vanity) domains, \*.criipto.id, and \*.idura.broker domains can be used).
- Your redirect URLs will be `https://[YOUR IDURA DOMAIN]/android/callback` and `https://[YOUR IDURA DOMAIN]/ios/callback`.

You should register both callback URLs in the [Idura dashboard](https://dashboard.idura.app).

There is nothing to initialize in Dart: the domain and client ID are read from your app's Android manifest and `Info.plist`, so each value is written once per platform, in the build configuration. If one is missing, `login()` throws a `NotConfiguredException` naming the fix.

### Android

The domain needs to be configured at compile time, since it is used to set up [intent filters](https://developer.android.com/guide/components/intents-filters#Receiving) for your redirect and app switch URLs. You do so by using [manifest placeholders](https://developer.android.com/build/manage-manifests#inject_build_variables_into_the_manifest) in `android/app/build.gradle.kts`:

```kts
android {
  defaultConfig {
    manifestPlaceholders["iduraDomain"] = "this-is-an-example.idura.broker"
    manifestPlaceholders["iduraClientId"] = "urn:my:application:identifier:XXXX"
  }
}
```

#### A word about redirect URLs

In order for redirect URLs to work, your app needs to prove that it is authorized to capture the URL. This is done by using [App Links](https://developer.android.com/training/app-links/about). When you use your Idura domain, Idura manages this for you, as long as you configure your package name and the fingerprint of your signing key in the Idura dashboard.

During development, you can get the fingerprint of your local signing key by running `./gradlew signingReport` in your `android` directory. To get the signing key to use for release, see the [Android documentation](https://developer.android.com/training/app-links/configure-assetlinks#declare-website).

### iOS

The domain needs to be configured as an [Associated domain](https://developer.apple.com/documentation/xcode/configuring-an-associated-domain) in order for redirect and app switch to work. This is a two-way association:

1. You should add the following entitlements to your app:
   ```
   webcredentials:this-is-an-example.idura.broker # Always required
   applinks:this-is-an-example.idura.broker # Required for app-switching
   ```
2. The domain should host an [Associated Domains Entitlement](https://developer.apple.com/documentation/xcode/supporting-associated-domains) file. When you use your Idura domain, Idura manages this for you, as long as you configure your Apple team ID and the bundle ID of your app in the Idura dashboard.

The domain must also be available to the plugin at runtime. In order to prevent drift between the value stored in your entitlements and your `Info.plist`, we recommend adding your domain and client ID as config fields, and referencing them from both:

`config.xcconfig`

```
IDURA_DOMAIN = this-is-an-example.idura.broker
IDURA_CLIENT_ID = urn:my:application:identifier:XXXX
```

`Info.plist`

```xml
<dict>
	<!-- Don't put the actual value here, this is a reference to your config file -->
	<key>IDURA_CLIENT_ID</key>
	<string>$(IDURA_CLIENT_ID)</string>
	<key>IDURA_DOMAIN</key>
	<string>$(IDURA_DOMAIN)</string>
</dict>
```

`Runner.entitlements`

```xml
<dict>
	<key>com.apple.developer.associated-domains</key>
	<array>
		<!-- Don't put the actual value here, this is a reference to your config file -->
		<string>webcredentials:$(IDURA_DOMAIN)</string>
		<string>applinks:$(IDURA_DOMAIN)</string>
	</array>
</dict>
```

Associated domains are stripped from Simulator builds, so on iOS every login, including the mock one, needs a physical device.

## Logging in

```dart
import 'package:idura_verify/idura_verify.dart';

final result = await login(DanishMitID.substantial());
print(result.claims.subject);
print(result.traceId);
```

`login()` returns a `LoginResult` containing the `idToken`, its decoded `claims`, and the `traceId` for the login flow. You can inspect traces in the Idura dashboard. The native SDK has verified the token before handing it over, but if you send it to your backend, verify it there again before trusting it.

The plugin provides builder classes for the eIDs supported by Idura Verify. You should use these when possible, since they provide helper methods for the scopes and login hints supported by the specific eID provider. For example, Danish MitID supports SSN prefilling, which you can access using the `prefillSsn` method:

```dart
final result = await login(
  DanishMitID.substantial().prefillSsn('123456-7890').withMessage('Hello there!'),
);
```

The returned `Claims` class has properties for some common claims such as `subject` and `identityScheme`. For other claims, index it by name. For example, if you requested the `address` scope, you can access the address like so:

```dart
final address = result.claims['address'] as Map<String, Object?>?;
final streetAddress = address?['street_address'] as String?;
```

`login()` passes `prompt=login` by default, so the user always authenticates afresh rather than silently reusing a session they may not expect. Pass `prompt: null` to let the server decide.

Building the native SDK fetches the OIDC discovery document and JWKS. Calling `warmUp()`, for example from `initState` on your login screen, takes that off the first login. It is optional.

Only one login can be in flight at a time on Android, because a browser result carries nothing that says which of several pending logins it belongs to. Calling `login()` while an earlier call has not returned throws `LoginAlreadyInProgressException` before any network request is made, and the login already running is unaffected. Disable your login button while the call is outstanding rather than relying on the rejection.

On Android, a login only lives as long as the activity it was started from. If Android reclaims your process while the user is in the browser, the call is lost and `login()` never returns. The browser tab itself survives, so the user can still complete the flow there, but the result has nowhere to go and is discarded. Start a new login when the user comes back rather than waiting for the old one.

### Ephemeral sessions

On iOS, the web view used to display the login page to the user allows you to choose between using an ephemeral or a shared browser session.

- **An ephemeral session** Shares no cookies with the user's browser, so the user may have to enter their login details. This is the default.
- **A shared session** Shares cookies with the user's browser, so login details may be remembered between logins. However, the user is presented with the following dialog each time they want to log in:

<img width="325" height="198" src="https://github.com/user-attachments/assets/5f476841-d909-479b-8470-ec89cad8b1c0" />

It is up to you to decide which flow is better, based on the UX requirements of your application. Not all eIDs require the user to enter anything in the webview - For example, Swedish BankID will take the user directly to their authenticator app. For this reason, you may also choose to use an ephemeral session for some eIDs, but not for others. Pass `preferEphemeralSession` to `login()` to choose. Android has no equivalent and ignores it.

Danish MitID supports a [re-authentication flow](https://docs.criipto.com/verify/e-ids/danish-mitid/#reauthentication), so you do not need to rely on a shared browser session if you need to re-authenticate the user with MitID.

## Error handling

`login()` throws a subclass of `IduraVerifyException` for every failure, including cancellation. The trace ID of the failed flow, when there is one, is available on `e.traceId`:

```dart
try {
  final result = await login(DanishMitID.substantial());
  // ...
} on UserCancelledException {
  // User dismissed the browser or the IdP returned `access_denied`. Usually a normal
  // action — quietly return them to the previous screen rather than showing an error.
} on NoSuitableBrowserException {
  // Android only: no browser on the device can run the auth flow.
} on LoginAlreadyInProgressException {
  // Android only: a login is still running. Nothing was started — leave the running
  // login to finish.
} on OAuth2Exception catch (e) {
  // The IdP returned a non-cancellation OAuth error. `e.error` is the OAuth 2.0 error code,
  // `e.errorDescription` is the optional human-readable text.
} on NotConfiguredException catch (e) {
  // A setup mistake in your app, not something the user did. `e.message` names the fix.
} on IduraVerifyException catch (e) {
  // Catch-all for SDK-internal failures (PAR, JWT verification, browser plumbing). Treat
  // as unrecoverable; surface a generic error to the user and log `e.traceId`.
}
```

`UserCancelledException` is a subclass of `OAuth2Exception`, so catch it first.
