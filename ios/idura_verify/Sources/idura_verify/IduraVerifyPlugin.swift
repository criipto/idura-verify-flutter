import Flutter
import UIKit

public class IduraVerifyPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "idura_verify", binaryMessenger: registrar.messenger())
    let instance = IduraVerifyPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    default:
      // Not `FlutterMethodNotImplemented`: it is imported from Objective-C as a
      // mutable global, which Swift 6 language mode rejects as shared mutable
      // state. Pigeon replaces this channel, so an equivalent error will do.
      result(FlutterError(code: "unimplemented", message: "Unknown method \(call.method)", details: nil))
    }
  }
}
