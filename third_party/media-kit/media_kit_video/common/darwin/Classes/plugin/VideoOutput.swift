#if canImport(Flutter)
  import Flutter
#elseif canImport(FlutterMacOS)
  import FlutterMacOS
#endif

// This class creates and manipulates the different types of FlutterTexture,
// handles resizing, rendering calls, and notify Flutter when a new frame is
// available to render.
//
// To improve the user experience, a worker is used to execute heavy tasks on a
// dedicated thread.
public class VideoOutput: NSObject {
  // Will be called on the main thread
  public typealias TextureUpdateCallback = (Int64, CGSize) -> Void
  private static let dynamicRangeNotification = Notification.Name(
    "PiliPlusVideoDynamicRangeDidChange"
  )

  private static let isSimulator: Bool = {
    let isSim: Bool
    #if targetEnvironment(simulator)
      isSim = true
    #else
      isSim = false
    #endif
    return isSim
  }()

  private let handle: OpaquePointer
  private let enableHardwareAcceleration: Bool
  private let registry: FlutterTextureRegistry
  private let textureUpdateCallback: TextureUpdateCallback
  private let worker: Worker = .init()
  private var width: Int64?
  private var height: Int64?
  private var texture: ResizableTextureProtocol!
  private var textureId: Int64 = -1
  private var currentSize: CGSize = CGSize.zero
  private var nativeFrameSize: CGSize = CGSize.zero
  private var zeroSizeUpdateCount: Int = 0
  private var asynchronousFrameDelivery: Bool = false
  private var didProbeSourceFrameRate = false
  private let updateStateLock = NSLock()
  private var updateScheduled: Bool = false
  private var updateRequested: Bool = false
  private var disposed: Bool = false
  #if (canImport(Flutter) || canImport(FlutterMacOS)) && !targetEnvironment(simulator)
    private var nativePresenter: NativeVideoPresenter?
  #endif

  init(
    handle: Int64,
    configuration: VideoOutputConfiguration,
    registry: FlutterTextureRegistry,
    textureUpdateCallback: @escaping TextureUpdateCallback
  ) {
    let handle = OpaquePointer(bitPattern: Int(handle))
    assert(handle != nil, "handle casting")

    self.handle = handle!
    width = configuration.width
    height = configuration.height
    enableHardwareAcceleration = configuration.enableHardwareAcceleration
    self.registry = registry
    self.textureUpdateCallback = textureUpdateCallback

    super.init()

    #if canImport(FlutterMacOS)
      nativePresenter = NativeVideoPresenter()
    #elseif canImport(Flutter) && !targetEnvironment(simulator)
      nativePresenter = NativeVideoPresenter(
        handle: Int64(Int(bitPattern: self.handle))
      )
    #endif

    worker.enqueue {
      self._init()
    }
  }

  deinit {
    updateStateLock.lock()
    disposed = true
    updateRequested = false
    updateStateLock.unlock()
    worker.cancel()
    #if (canImport(Flutter) || canImport(FlutterMacOS)) && !targetEnvironment(simulator)
      nativePresenter?.dispose()
    #endif
    #if canImport(Flutter)
      publishDynamicRange(hdr: false, headroom: 1.0)
    #endif
    disposeTextureId()
  }

  #if canImport(FlutterMacOS)
    public func setNativeSurface(rect: CGRect?, fit: String) {
      nativePresenter?.setFrame(rect, fit: fit)
    }

    func attachNativePlatformView(_ view: NativeVideoPlatformView) {
      nativePresenter?.attachPlatformView(view)
    }

    public func setNativePlaybackRate(_ rate: Double) {
      nativePresenter?.setPlaybackRate(rate)
    }

    public func configureDanmaku(_ values: [String: Any]) {
      nativePresenter?.configureDanmaku(values)
    }

    public func addDanmaku(_ values: [[String: Any]], epoch: Int64) {
      nativePresenter?.addDanmaku(values, epoch: epoch)
    }

    public func pauseDanmaku(epoch: Int64) {
      nativePresenter?.pauseDanmaku(epoch: epoch)
    }

    public func resumeDanmaku(epoch: Int64) {
      nativePresenter?.resumeDanmaku(epoch: epoch)
    }

    public func clearDanmaku(epoch: Int64) {
      nativePresenter?.clearDanmaku(epoch: epoch)
    }

    public func setDanmakuOpacity(_ opacity: Float) {
      nativePresenter?.setDanmakuOpacity(opacity)
    }
  #endif

  public func setSize(width: Int64?, height: Int64?) {
    worker.enqueue {
      self.width = width
      self.height = height
    }
  }

  #if canImport(Flutter) && !targetEnvironment(simulator)
    public func setNativeSurface(fit: String) {
      nativePresenter?.setFit(fit)
    }

    public func setNativePlaybackRate(_ rate: Double) {
      nativePresenter?.setPlaybackRate(rate)
    }

    public func configureDanmaku(_ values: [String: Any]) {
      nativePresenter?.configureDanmaku(values)
    }

    public func addDanmaku(_ values: [[String: Any]], epoch: Int64) {
      nativePresenter?.addDanmaku(values, epoch: epoch)
    }

    public func pauseDanmaku(epoch: Int64) {
      nativePresenter?.pauseDanmaku(epoch: epoch)
    }

    public func resumeDanmaku(epoch: Int64) {
      nativePresenter?.resumeDanmaku(epoch: epoch)
    }

    public func clearDanmaku(epoch: Int64) {
      nativePresenter?.clearDanmaku(epoch: epoch)
    }

    public func setDanmakuOpacity(_ opacity: Float) {
      nativePresenter?.setDanmakuOpacity(opacity)
    }
  #endif

  private func _init() {
    let enableHardwareAcceleration =
      VideoOutput.isSimulator ? false : enableHardwareAcceleration

    NSLog(
      "VideoOutput: enableHardwareAcceleration: \(enableHardwareAcceleration)"
    )

    if VideoOutput.isSimulator {
      NSLog(
        "VideoOutput: warning: hardware rendering is disabled in the iOS simulator, due to an incompatibility with OpenGL ES"
      )
    }

    if enableHardwareAcceleration {
      #if (canImport(Flutter) || canImport(FlutterMacOS)) && !targetEnvironment(simulator)
        var iglError: NSString?
        let updateCallback: IGLMetalTextureUpdateCallback = { [weak self]() in
          guard let that = self else { return }
          that.updateCallback()
        }
        let frameReadyCallback: IGLMetalTextureFrameReadyCallback = { [weak self]() in
          guard let that = self else { return }
          that.notifyTextureFrameAvailable()
        }
        #if canImport(FlutterMacOS)
          let iglTexture = IGLMetalTexture(
            handle: UnsafeMutableRawPointer(handle),
            updateCallback: updateCallback,
            frameReadyCallback: frameReadyCallback,
            nativeFrameCallback: { [weak self] pixelBuffer, presentationTime,
              displayWidth, displayHeight, rotate in
              guard let self else { return }
              let normalizedRotation = (rotate % 360 + 360) % 360
              let swapsDimensions = normalizedRotation == 90 || normalizedRotation == 270
              let frameWidth = swapsDimensions ? displayHeight : displayWidth
              let frameHeight = swapsDimensions ? displayWidth : displayHeight
              if frameWidth > 0 && frameHeight > 0 {
                self.nativeFrameSize = CGSize(
                  width: Double(frameWidth),
                  height: Double(frameHeight)
                )
              }
              self.nativePresenter?.enqueue(
                pixelBuffer,
                presentationTime: presentationTime
              )
            },
            error: &iglError
          )
        #else
          let iglTexture = IGLMetalTexture(
            handle: UnsafeMutableRawPointer(handle),
            updateCallback: updateCallback,
            frameReadyCallback: frameReadyCallback,
            nativeFrameCallback: { [weak self] pixelBuffer, presentationTime,
              displayWidth, displayHeight, rotate in
              guard let self else { return false }
              let normalizedRotation = (rotate % 360 + 360) % 360
              let swapsDimensions = normalizedRotation == 90 || normalizedRotation == 270
              let frameWidth = swapsDimensions ? displayHeight : displayWidth
              let frameHeight = swapsDimensions ? displayWidth : displayHeight
              if frameWidth > 0 && frameHeight > 0 {
                self.nativeFrameSize = CGSize(
                  width: Double(frameWidth),
                  height: Double(frameHeight)
                )
              }
              return self.nativePresenter?.enqueue(
                pixelBuffer,
                presentationTime: presentationTime
              ) ?? false
            },
            dynamicRangeCallback: { [weak self] hdr, headroom in
              self?.publishDynamicRange(hdr: hdr, headroom: headroom)
            },
            error: &iglError
          )
        #endif
        if let iglTexture {
          NSLog(
            "VideoOutput: renderer: \(iglTexture.rendererDescription)"
          )
          asynchronousFrameDelivery = true
          texture = SafeResizableTexture(iglTexture)
        } else {
          NSLog(
            "VideoOutput: IGL Metal unavailable, falling back to platform OpenGL: \(iglError ?? "unknown")"
          )
          texture = SafeResizableTexture(
            TextureHW(
              handle: handle,
              updateCallback: { [weak self]() in
                guard let that = self else { return }
                that.updateCallback()
              }
            )
          )
        }
      #else
        texture = SafeResizableTexture(
          TextureHW(
            handle: handle,
            updateCallback: { [weak self]() in
              guard let that = self else { return }
              that.updateCallback()
            }
          )
        )
      #endif
    } else {
      texture = SafeResizableTexture(
        TextureSW(
          handle: handle,
          // Use `weak self` to prevent memory leaks
          updateCallback: { [weak self]() in
            guard let that = self else {
              return
            }
            that.updateCallback()
          }
        )
      )
    }

    DispatchQueue.main.sync { [weak self]() in
      guard let that = self else {
        return
      }
      that.registerTextureId()
    }
  }

  // Must be run on the main thread
  private func registerTextureId() {
    // Textures must be registered on the platform thread.
    textureId = registry.register(texture)
    // textureUpdateCallback must run on the main thread
    textureUpdateCallback(textureId, CGSize(width: 0, height: 0))
  }

  private func disposeTextureId() {
    let registry_ = self.registry
    let textureId_ = self.textureId
    textureId = -1
    DispatchQueue.main.async {
      // Textures must be unregistered on the platform thread
      registry_.unregisterTexture(textureId_)
    }
  }

  public func updateCallback() {
    updateStateLock.lock()
    guard !disposed else {
      updateStateLock.unlock()
      return
    }
    if updateScheduled {
      updateRequested = true
      updateStateLock.unlock()
      return
    }
    updateScheduled = true
    updateStateLock.unlock()

    worker.enqueue {
      [weak self] in
      self?.processUpdateCallback()
    }
  }

  private func processUpdateCallback() {
    updateStateLock.lock()
    if disposed {
      updateScheduled = false
      updateStateLock.unlock()
      return
    }
    updateRequested = false
    updateStateLock.unlock()

    _updateCallback()

    updateStateLock.lock()
    let shouldScheduleNext = updateRequested && !disposed
    if !shouldScheduleNext {
      updateScheduled = false
    }
    updateStateLock.unlock()

    if shouldScheduleNext {
      worker.enqueue { [weak self] in
        self?.processUpdateCallback()
      }
    }
  }

  private func _updateCallback() {
    let size = videoSize

    #if canImport(FlutterMacOS)
      if !didProbeSourceFrameRate {
        let estimatedFrameRate = MPVHelpers.getDoubleProperty(
          handle,
          name: "estimated-vf-fps"
        ) ?? 0
        let frameRate = estimatedFrameRate > 0
          ? estimatedFrameRate
          : MPVHelpers.getDoubleProperty(handle, name: "container-fps") ?? 0
        if frameRate > 0 {
          nativePresenter?.setSourceFrameRate(frameRate)
          didProbeSourceFrameRate = true
        }
      }
    #endif

    if size.width == 0 || size.height == 0 {
      zeroSizeUpdateCount += 1
      if zeroSizeUpdateCount <= 3 {
        NSLog("VideoOutput: update #\(zeroSizeUpdateCount) has zero video size")
      }
      return
    }
    zeroSizeUpdateCount = 0

    if currentSize != size {
      currentSize = size

      texture.resize(size)
      DispatchQueue.main.sync { [weak self] in
        guard let that = self else { return }
        // textureUpdateCallback must run on the main thread
        that.textureUpdateCallback(that.textureId, size)
      }
    }

    if disposed {
      return
    }

    texture.render(size)
    if !asynchronousFrameDelivery {
      DispatchQueue.main.sync { [weak self] in
        guard let that = self else { return }
        // Textures must be marked as available from the main thread
        that.registry.textureFrameAvailable(that.textureId)
      }
    }
  }

  private func notifyTextureFrameAvailable() {
    dispatchPrecondition(condition: .onQueue(.main))
    if !disposed && textureId >= 0 {
      registry.textureFrameAvailable(textureId)
    }
  }

  private func publishDynamicRange(hdr: Bool, headroom: CGFloat) {
    let handleValue = Int64(Int(bitPattern: handle))
    DispatchQueue.main.async {
      NotificationCenter.default.post(
        name: VideoOutput.dynamicRangeNotification,
        object: nil,
        userInfo: [
          "handle": handleValue,
          "hdr": hdr,
          "headroom": headroom,
        ]
      )
    }
  }

  private var videoSize: CGSize {
    if width != nil && height != nil {
      return CGSize(width: Double(width!), height: Double(height!))
    }

    if nativeFrameSize.width > 0 && nativeFrameSize.height > 0 {
      return CGSize(
        width: Double(width ?? Int64(nativeFrameSize.width)),
        height: Double(height ?? Int64(nativeFrameSize.height))
      )
    }

    let params = MPVHelpers.getVideoOutParams(handle)
    let keepsDimensions = params.rotate == 0 || params.rotate == 180
    return CGSize(
      width: Double(width ?? (keepsDimensions ? params.dw : params.dh)),
      height: Double(height ?? (keepsDimensions ? params.dh : params.dw))
    )
  }
}
