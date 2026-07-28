#if canImport(Flutter)
  import Flutter
#elseif canImport(FlutterMacOS)
  import FlutterMacOS
#endif

public class VideoOutputManager: NSObject {
  private let registry: FlutterTextureRegistry
  private var videoOutputs = [Int64: VideoOutput]()

  init(registry: FlutterTextureRegistry) {
    self.registry = registry
  }

  public func create(
    handle: Int64,
    configuration: VideoOutputConfiguration,
    textureUpdateCallback: @escaping VideoOutput.TextureUpdateCallback
  ) {
    let videoOutput = VideoOutput(
      handle: handle,
      configuration: configuration,
      registry: self.registry,
      textureUpdateCallback: textureUpdateCallback
    )

    self.videoOutputs[handle] = videoOutput
  }

  public func setSize(
    handle: Int64,
    width: Int64?,
    height: Int64?
  ) {
    let videoOutput = self.videoOutputs[handle]
    if videoOutput == nil {
      return
    }

    videoOutput!.setSize(
      width: width,
      height: height
    )
  }

  public func destroy(
    handle: Int64
  ) {
    let videoOutput = self.videoOutputs[handle]
    if videoOutput == nil {
      return
    }

    self.videoOutputs[handle] = nil
  }

  #if canImport(FlutterMacOS)
    public func setNativeSurface(handle: Int64, rect: CGRect?, fit: String) {
      videoOutputs[handle]?.setNativeSurface(rect: rect, fit: fit)
    }

    func attachNativePlatformView(
      handle: Int64,
      view: NativeVideoPlatformView
    ) {
      videoOutputs[handle]?.attachNativePlatformView(view)
    }

    public func setNativePlaybackRate(handle: Int64, rate: Double) {
      videoOutputs[handle]?.setNativePlaybackRate(rate)
    }

    public func configureDanmaku(handle: Int64, values: [String: Any]) {
      videoOutputs[handle]?.configureDanmaku(values)
    }

    public func addDanmaku(handle: Int64, values: [String: Any], epoch: Int64) {
      videoOutputs[handle]?.addDanmaku([values], epoch: epoch)
    }

    public func addDanmaku(handle: Int64, values: [[String: Any]], epoch: Int64) {
      videoOutputs[handle]?.addDanmaku(values, epoch: epoch)
    }

    public func pauseDanmaku(handle: Int64, epoch: Int64) {
      videoOutputs[handle]?.pauseDanmaku(epoch: epoch)
    }

    public func resumeDanmaku(handle: Int64, epoch: Int64) {
      videoOutputs[handle]?.resumeDanmaku(epoch: epoch)
    }

    public func clearDanmaku(handle: Int64, epoch: Int64) {
      videoOutputs[handle]?.clearDanmaku(epoch: epoch)
    }

    public func setDanmakuOpacity(handle: Int64, opacity: Float) {
      videoOutputs[handle]?.setDanmakuOpacity(opacity)
    }
  #endif
}
