import Flutter
import QuartzCore
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let videoDynamicRangeNotification = Notification.Name(
    "PiliPlusVideoDynamicRangeDidChange"
  )
  private var videoHeadrooms: [Int64: CGFloat] = [:]

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    application.applicationSupportsShakeToEdit = false // Disable shake to undo
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(videoDynamicRangeDidChange(_:)),
      name: Self.videoDynamicRangeNotification,
      object: nil
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func videoDynamicRangeDidChange(_ notification: Notification) {
    guard let handleValue = notification.userInfo?["handle"] as? NSNumber,
          let hdrValue = notification.userInfo?["hdr"] as? NSNumber,
          let headroomValue = notification.userInfo?["headroom"] as? NSNumber
    else {
      return
    }
    let handle = handleValue.int64Value
    let hdr = hdrValue.boolValue
    let headroom = CGFloat(headroomValue.doubleValue)

    if hdr {
      videoHeadrooms[handle] = max(headroom, 1.0)
    } else {
      videoHeadrooms.removeValue(forKey: handle)
    }
    applyVideoDynamicRange()
  }

  private func applyVideoDynamicRange() {
    let headroom = videoHeadrooms.values.max() ?? 1.0
    let dynamicRange: CALayer.DynamicRange = headroom > 1.0 ? .high : .standard
    for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
      for window in scene.windows {
        let layer = window.rootViewController?.view.layer
        layer?.preferredDynamicRange = dynamicRange
        layer?.contentsHeadroom = headroom
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak scene] in
        guard let screen = scene?.screen else { return }
        NSLog(
          "PiliPlus EDR: requested=%.3f current=%.3f potential=%.3f",
          Double(headroom),
          Double(screen.currentEDRHeadroom),
          Double(screen.potentialEDRHeadroom)
        )
      }
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    engineBridge.pluginRegistry
      .registrar(forPlugin: "IOSGlassSurface")?
      .register(
        IOSGlassSurfaceFactory(),
        withId: "com.piliplus.badapple/ios-glass-surface"
      )
  }
}
