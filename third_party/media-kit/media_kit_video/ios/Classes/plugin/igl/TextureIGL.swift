import Flutter

extension IGLMetalTexture: ResizableTextureProtocol {
  public func resize(_ size: CGSize) {
    var error: NSString?
    if !resizeWidth(Int(size.width), height: Int(size.height), error: &error) {
      NSLog("TextureIGL: resize failed: \(error ?? "unknown")")
    }
  }

  public func render(_ size: CGSize) {
    var error: NSString?
    if !renderWidth(Int(size.width), height: Int(size.height), error: &error) {
      NSLog("TextureIGL: render failed: \(error ?? "unknown")")
    }
  }
}
