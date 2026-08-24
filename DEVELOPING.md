# Developing

## Toolchain

The Flutter version is pinned in [`.fvmrc`](.fvmrc) and managed with
[fvm](https://fvm.app), so everyone builds against the same SDK:

```sh
brew install fvm
fvm install   # reads .fvmrc
```

Then prefix commands with `fvm`, e.g. `fvm flutter test`, `fvm dart analyze`. If you
would rather not type the prefix, `fvm use` writes a `.fvm/` symlink that most IDEs
pick up automatically.

Beyond Flutter you need:

| Tool | Why |
| --- | --- |
| JDK 17 | The Android SDK builds with a JVM 11 target on a 17 toolchain |
| Android SDK platform 36 | `eu.idura:verify` compiles against API 36 |
| Xcode 16 or newer, with the iOS 17.4 SDK | The iOS SDK requires iOS 17.4 |
| A physical iPhone | **No iOS login flow works on the Simulator** — see below |
| [ktlint](https://pinterest.github.io/ktlint/) 1.8.0 | Lints the Android bridge |
| [swiftlint](https://github.com/realm/SwiftLint) | Lints the iOS bridge |

CocoaPods is **not** required, and is not supported — see "iOS is SwiftPM-only".

## Why we do not support CocoaPods on iOS

`idura-verify-ios` is distributed exclusively as a Swift package, and most of its
dependency graph (jwt-kit, opentelemetry-swift, swift-uuidv7, …) has no podspec at
all, so there is nothing for CocoaPods to resolve. This plugin therefore ships a
`Package.swift` and **deliberately ships no `.podspec`**.

That omission is load-bearing. With no podspec present, `flutter_tools` recognises
the plugin as SwiftPM-only and tells the user exactly what to do:

> The following plugin(s) are only compatible with Swift Package Manager … Try
> enabling Swift Package Manager by running `flutter config --enable-swift-package-manager`

If we shipped a podspec to "be safe", the tool would treat us as CocoaPods-compatible
and the user would instead get an unexplained link failure. Do not add one.

Swift Package Manager is the default from Flutter 3.44, which is also the first
version that generates the `FlutterFramework` package our `Package.swift` depends on.
Hence the `>= 3.44.0` floor.

## Why iOS testing needs a physical device

The OAuth callback arrives through an `ASWebAuthenticationSession` HTTPS
(associated-domain) callback, and `com.apple.developer.associated-domains` is a
provisioned entitlement that is stripped from Simulator builds. Without it the
session fails immediately. **Every** login flow needs a physical device signed with a
team whose App ID has Associated Domains enabled — including the mock flow, which on
Android does run on an emulator.

## Commit conventions

- One logical change per commit; message is title, blank line, then *why*.
- Fix review comments with `git commit --fixup` and autosquash before merging. CI
  rejects any commit whose subject starts with `fixup!`, `amend!`, `squash!` or `wip`.
