import Flutter
import UIKit
import flutter_radio_player_ios

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let engineGroup = FlutterEngineGroup(name: "frp-test", project: nil)
  private var secondEngine: FlutterEngine?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FrpTestHost") else { return }
    // Lets the conformance tests run a second engine against the shared player (C11).
    let channel = FlutterMethodChannel(name: "frp_test_host", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "spawnSecondEngine":
        self.secondEngine?.destroyContext()
        guard let handle = (call.arguments as? NSNumber)?.int64Value,
              let callback = FlutterCallbackCache.lookupCallbackInformation(handle) else {
          result(FlutterError(code: "no_callback", message: nil, details: nil))
          return
        }
        let engine = self.engineGroup.makeEngine(
          withEntrypoint: callback.callbackName, libraryURI: callback.callbackLibraryPath)
        GeneratedPluginRegistrant.register(with: engine)
        self.secondEngine = engine
        result(nil)
      case "coreExists":
        result(RadioPlayerCore.existing != nil)
      case "destroySecondEngine":
        self.secondEngine?.destroyContext()
        self.secondEngine = nil
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
