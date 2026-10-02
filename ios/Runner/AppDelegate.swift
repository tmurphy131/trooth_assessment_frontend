import Flutter
import UIKit

// UIScene lifecycle (required on iOS 27): Flutter creates the engine
// implicitly and SceneDelegate/Main.storyboard host the Flutter view.
// The storyboard's FlutterViewController shows LaunchScreen.storyboard until
// Flutter's first frame, which FlutterNativeSplash.preserve() holds back.
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
  }
}
