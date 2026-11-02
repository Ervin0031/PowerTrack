import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterMethodChannel(name: "powertrack/health", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      HealthKitBridge.shared.handle(call, result: result)
    }
    let restIsland = FlutterMethodChannel(name: "powertrack/rest_island", binaryMessenger: messenger)
    restIsland.setMethodCallHandler { call, result in
      RestIslandAlert.handle(call, result: result)
    }
  }
}
