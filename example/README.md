# Example

This example application shows you how to integrate the Idura Verify Flutter plugin.

Note that eIDs which use authenticator apps (Danish MitID, Swedish and Norwegian BankID) cannot be used in a simulator. On iOS no login works in the Simulator at all, including the mock one, because associated domains are stripped from Simulator builds. So in order to test the full experience, you should have access to a physical Android or iOS device.

1. Clone this repo into a directory named `idura_verify`. With any other name `flutter build ios` fails to resolve packages; see [DEVELOPING.md](../DEVELOPING.md#clone-into-a-directory-named-idura_verify).
2. Create a domain in the [Idura dashboard](https://dashboard.idura.app/domains), if you haven't done so already.
3. Create a new Verify application in the Idura dashboard.
   1. Add `https://[YOUR DOMAIN]/android/callback` and `https://[YOUR DOMAIN]/ios/callback` as redirect URLs.
   2. In the Native / Mobile section, set "App package name" and "Bundle ID" to `eu.idura.verify.flutter.example` (since this application will not be published, you don't need to use your own package name), and "Team ID" to your Apple team ID.

      You can find your Apple team ID at https://developer.apple.com/account. This requires a paid apple developer account.

   3. Add the fingerprint of the checked-in debug keystore to the "SHA256 fingerprints" section. Run `./gradlew :app:signingReport` in `example/android` to get it.
4. Add your domain and client ID:
   - Android: the `iduraDomain` and `iduraClientId` manifest placeholders in `android/app/build.gradle.kts`.
   - iOS: `IDURA_DOMAIN` and `IDURA_CLIENT_ID` in `ios/Flutter/Idura.xcconfig`, and set `DEVELOPMENT_TEAM` to your Apple team ID in Xcode.
5. Run the application with `flutter run`.
6. Run a mock login, to verify that everything works as expected
7. :tada:

The mock provider works out of the box, but other eID providers require you to register test users before you can run a login. See https://docs.idura.app/verify/e-ids/.
