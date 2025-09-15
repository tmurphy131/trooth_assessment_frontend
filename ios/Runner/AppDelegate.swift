import UIKit
import Flutter

@UIApplicationMain
class AppDelegate: FlutterAppDelegate {
  var flutterEngine: FlutterEngine? = FlutterEngine(name: "primary")
  var windowRef: UIWindow?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    // Start engine early
    flutterEngine?.run()
    guard let engine = flutterEngine else { return false }
    GeneratedPluginRegistrant.register(with: engine)

    // Manually create window since we removed any main storyboard
    windowRef = UIWindow(frame: UIScreen.main.bounds)
    let flutterVC = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
    windowRef?.rootViewController = flutterVC
    windowRef?.makeKeyAndVisible()

    // Allow FlutterAppDelegate to handle plugins (push, links, etc.)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
