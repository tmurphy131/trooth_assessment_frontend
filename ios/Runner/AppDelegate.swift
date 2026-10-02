import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  var flutterEngine: FlutterEngine?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialize a Flutter engine and attach it to a visible window since we don't use a main storyboard.
    let engine = FlutterEngine(name: "root_engine")
    engine.run()
    GeneratedPluginRegistrant.register(with: engine)
    self.flutterEngine = engine

    let flutterViewController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
    // A view controller built around an existing engine doesn't show the launch
    // screen on its own, so the logo vanished (black screen) until Flutter's
    // first frame. Keep LaunchScreen.storyboard up until then; the first frame
    // is held by FlutterNativeSplash.preserve() until AuthGate is ready.
    flutterViewController.loadDefaultSplashScreenView()
    self.window = UIWindow(frame: UIScreen.main.bounds)
    self.window?.rootViewController = flutterViewController
    self.window?.makeKeyAndVisible()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
