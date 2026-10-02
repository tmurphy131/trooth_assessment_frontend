import Flutter
import UIKit

// Forwards scene events (URLs, universal links, lifecycle) to plugins.
class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    // Keep LaunchScreen.storyboard (the logo) on screen until Flutter's first
    // frame; FlutterNativeSplash.preserve() holds that frame back until the
    // first route is ready. Without this the wait is a blank white view.
    (window?.rootViewController as? FlutterViewController)?.loadDefaultSplashScreenView()
  }
}
