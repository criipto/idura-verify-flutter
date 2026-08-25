import Flutter
import Foundation
import IduraVerify

/// Binds the Flutter `idura_verify` package to the `IduraVerify` Swift package.
public class IduraVerifyPlugin: NSObject, FlutterPlugin, IduraVerifyHostApi {
  /// Where the configuration is read from. Injected so `Bundle.main` is not baked in.
  private let info: (String) -> String?

  /// Built on first use and kept for the life of the process, which is what the
  /// SDK asks for: its initialiser starts OIDC discovery and a JWKS fetch and
  /// stands up a telemetry exporter, so a second instance wastes both.
  ///
  /// First use is normally `warmUp` from the screen that logs in, and `login`
  /// builds it if nobody called that. Deliberately *not* built in
  /// `register(with:)`, which `GeneratedPluginRegistrant` runs at app launch: an
  /// app that never logs in should not pay for any of the above.
  ///
  /// Nothing invalidates it, and nothing here mirrors the Android side's per-activity
  /// teardown: `ASWebAuthenticationSession` presents itself from the key window rather
  /// than from a view controller we would have to hold.
  @MainActor private var sdk: IduraVerify?

  init(info: @escaping (String) -> String?) {
    self.info = info
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = IduraVerifyPlugin { key in
      Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
    IduraVerifyHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
    registrar.publish(instance)
  }

  /// Not `public`, for the same reason `login` is not.
  ///
  /// Declared without `throws`, which the generated requirement permits, because a
  /// warm-up has nothing to report: there is no result variant for it, and the same
  /// failure comes back out of `login` with a message naming the fix.
  func warmUp() async {
    await warmUpSdk()
  }

  @MainActor
  private func warmUpSdk() {
    do {
      _ = try requireSdk()
    } catch {
      // Logged only so the reason is visible while an integration is being wired
      // up. A warm-up that quietly does nothing is otherwise indistinguishable
      // from one that worked.
      NSLog("[idura_verify] warmUp() could not build the Idura Verify SDK: \(error)")
    }
  }

  /// Not `public`: the generated host API and its request type are internal, so this
  /// is only ever reached through the channel.
  ///
  /// Pigeon's `setUp` already dispatches this onto the main actor, so the hop below is
  /// only there because the generated protocol requirement is not itself isolated.
  func login(request: NativeLoginRequest) async throws -> NativeLoginResult {
    await performLogin(request)
  }

  @MainActor
  private func performLogin(_ request: NativeLoginRequest) async -> NativeLoginResult {
    let sdk: IduraVerify
    do {
      sdk = try requireSdk()
    } catch {
      return nativeLoginResult(from: error)
    }

    do {
      let result = try await sdk.login(
        eid: makeEid(request),
        // Null stays null rather than falling back to the SDK's own `.login` default:
        // Dart already applied that default, so a null here is a caller explicitly
        // asking for the parameter to be omitted.
        prompt: request.prompt.map { sdkPrompt($0) },
        useEphemeralBrowserSession: request.preferEphemeralSession
      )
      return NativeLoginSuccess(idToken: result.jwt.idToken, traceId: result.traceId)
    } catch {
      return nativeLoginResult(from: error)
    }
  }

  @MainActor
  private func requireSdk() throws -> IduraVerify {
    if let sdk { return sdk }

    let created = try constructSdk(info)
    sdk = created
    return created
  }
}
