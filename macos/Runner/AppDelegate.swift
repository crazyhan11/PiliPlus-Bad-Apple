import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      for window in NSApp.windows {
        if !window.isVisible {
          window.setIsVisible(true)
        }
        window.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
      }
    }
    return true
  }
}

final class MacOSGlassSurfaceFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol)? {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withViewIdentifier viewIdentifier: Int64, arguments args: Any?) -> NSView {
    MacOSGlassSurface(arguments: args)
  }
}

private final class MacOSGlassSurface: NSView {
  private let effectView = NSVisualEffectView()
  private let tintView = NSView()

  init(arguments: Any?) {
    let params = arguments as? [String: Any]
    super.init(frame: .zero)

    wantsLayer = true
    layer?.cornerCurve = .continuous
    layer?.cornerRadius = (params?["borderRadius"] as? NSNumber)?.doubleValue ?? 22
    layer?.masksToBounds = true

    effectView.blendingMode = .withinWindow
    effectView.state = .active
    effectView.material = params?["style"] as? String == "regular"
      ? .contentBackground
      : .underWindowBackground

    tintView.wantsLayer = true
    if let tint = params?["tint"] as? NSNumber {
      tintView.layer?.backgroundColor = NSColor(argb: tint.uint32Value).cgColor
    }

    for subview in [effectView, tintView] {
      subview.translatesAutoresizingMaskIntoConstraints = false
      addSubview(subview)
      NSLayoutConstraint.activate([
        subview.leadingAnchor.constraint(equalTo: leadingAnchor),
        subview.trailingAnchor.constraint(equalTo: trailingAnchor),
        subview.topAnchor.constraint(equalTo: topAnchor),
        subview.bottomAnchor.constraint(equalTo: bottomAnchor),
      ])
    }
  }

  required init?(coder: NSCoder) {
    nil
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    nil
  }
}

private extension NSColor {
  convenience init(argb: UInt32) {
    self.init(
      calibratedRed: CGFloat((argb >> 16) & 0xff) / 255,
      green: CGFloat((argb >> 8) & 0xff) / 255,
      blue: CGFloat(argb & 0xff) / 255,
      alpha: CGFloat((argb >> 24) & 0xff) / 255
    )
  }
}
