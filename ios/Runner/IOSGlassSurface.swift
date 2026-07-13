import Flutter
import UIKit

final class IOSGlassSurfaceFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> any FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> any FlutterPlatformView {
    IOSGlassSurfacePlatformView(frame: frame, arguments: args)
  }
}

private final class IOSGlassSurfacePlatformView: NSObject, FlutterPlatformView {
  private let glassView: UIVisualEffectView

  init(frame: CGRect, arguments: Any?) {
    let params = arguments as? [String: Any]
    let style: UIGlassEffect.Style = params?["style"] as? String == "regular"
      ? .regular
      : .clear
    let effect = UIGlassEffect(style: style)
    effect.isInteractive = false

    if let tint = params?["tint"] as? NSNumber {
      effect.tintColor = UIColor(argb: tint.uint32Value)
    }

    glassView = UIVisualEffectView(effect: effect)
    super.init()

    glassView.frame = frame
    glassView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    glassView.backgroundColor = .clear
    glassView.isUserInteractionEnabled = false
    glassView.clipsToBounds = true
    glassView.layer.cornerCurve = .continuous
    glassView.layer.cornerRadius = (params?["borderRadius"] as? NSNumber)?.doubleValue ?? 22
  }

  func view() -> UIView {
    glassView
  }
}

private extension UIColor {
  convenience init(argb: UInt32) {
    self.init(
      red: CGFloat((argb >> 16) & 0xff) / 255,
      green: CGFloat((argb >> 8) & 0xff) / 255,
      blue: CGFloat(argb & 0xff) / 255,
      alpha: CGFloat((argb >> 24) & 0xff) / 255
    )
  }
}
