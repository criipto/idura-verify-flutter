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

## Scripts

| Script | What it does |
| --- | --- |
| `scripts/lint.sh` | Every static check CI runs: format, analyze, ktlint, swiftlint |
| `scripts/format.sh` | Rewrites hand-written Dart. `--check` reports instead, for CI |
| `scripts/generate.sh` | Regenerates the bridge from [`pigeons/messages.dart`](pigeons/messages.dart) |
| `scripts/verify-generated.sh` | Fails if the committed bridge no longer matches the schema |

**Never reformat generated code.** `Messages.g.dart`, `Messages.g.kt` and
`Messages.g.swift` are committed exactly as pigeon emits them, which is what lets
`verify-generated.sh` be a plain regenerate-and-diff. Pigeon's Dart output is *not*
`dart format`-clean, so `dart format lib` silently breaks the drift check — use
`scripts/format.sh`, which excludes `*.g.dart`. The Kotlin exclusion lives in
`.editorconfig` and the Swift one in `.swiftlint.yml`.

Change the schema and its output in the same commit, or CI fails on the next PR.

[`.gitattributes`](.gitattributes) marks the three files `linguist-generated`, so GitHub
collapses them in a pull request diff. If a diff looks suspiciously small, that is why —
expand it, or read `pigeons/messages.dart`, which is the part worth reviewing anyway.

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

## Clone into a directory named `idura_verify`

```sh
git clone git@github.com:criipto/idura-verify-flutter.git idura_verify
```

Not cosmetic: with any other directory name, `flutter build ios` in `example/` fails
to resolve packages with

> unable to override package 'idura_verify' because its identity
> 'idura-verify-flutter' doesn't match override's identity (directory name)
> 'idura_verify'

`flutter_tools` symlinks the plugin into
`example/ios/Flutter/ephemeral/Packages/.packages/` under the *plugin root
directory's* basename, and SwiftPM derives the dependency's package identity from
that basename. Because the plugin root is an ancestor of the example's Xcode
project, Xcode also registers `ios/idura_verify` as a graph root, and
`Workspace+Manifests.swift` rejects a root that shares a package name with a
dependency resolved from a different location. The two only agree when the checkout
directory is named `idura_verify`, matching the `ios/<plugin_name>` directory that
`flutter_tools` requires.

This affects **only this repository's own example app**. Consumers are unaffected:
their plugin directory (`idura_verify-1.2.3` in the pub cache) is not an ancestor of
their project, so it is a plain dependency and never a root. `pub` canonicalises
symlinked path dependencies, so a symlink inside `example/` does not work around it.

## What the example's tenant has registered

The example app logs in against the `samples-flutter.test.idura.broker` tenant, which has to
know each of these before a callback will come back. Change one and logins stop
working with no useful error.

| | Value |
| --- | --- |
| Client id | `urn:criipto:samples:idura:verify-flutter` |
| Android package name | `eu.idura.verify.flutter.example` |
| Android signing cert SHA-256 | `8D:42:58:35:AE:15:03:2D:D6:BD:6B:76:79:CC:61:CF:F1:DB:4C:28:0C:F2:92:B4:19:28:77:FA:46:DE:2B:77` |
| iOS bundle id | `eu.idura.verify.flutter.example` |
| iOS App ID (team + bundle) | `P56KU6NT8A.eu.idura.verify.flutter.example` |

The Android SHA-256 comes from `example/android/app/debug.keystore`, which is
**deliberately checked in** — it is the stock Android debug keystore, password
`android`, and signs nothing that is published. Digital Asset Links binds a
(package name, cert SHA-256) pair, so a per-developer `~/.android/debug.keystore`
would mean the App Link that carries the login callback only verified for whoever
happened to register their own cert. It is byte-for-byte the keystore
`idura-verify-android`'s example checks in, for the same reason. Confirm it with:

```sh
cd example/android && ./gradlew :app:signingReport
```

The iOS App ID needs the **Associated Domains** capability enabled in the Apple
Developer portal, and `DEVELOPMENT_TEAM` is already set to `P56KU6NT8A` on all three
Runner configurations.

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

## Releasing

Releases are published to pub.dev by [`publish.yml`](.github/workflows/publish.yml),
authenticated with GitHub's OIDC token, so there is no pub.dev credential to keep.
There is no `CHANGELOG.md`: the GitHub release notes are the changelog.

1. Bump `version` in `pubspec.yaml` and merge it.
2. Create a GitHub release on `master` with the tag `v<version>`, e.g. `v1.2.3`, and
   write the release notes there. Publishing the release creates the tag, which
   starts the workflow.
3. If the `pub.dev` environment requires reviewers, approve the run.

pub.dev only accepts the upload if the tag matches `version` exactly, and only from
a tag push in this repository, through the `pub.dev` environment. Both are configured
on pub.dev under the package's Admin tab, "Automated publishing".
