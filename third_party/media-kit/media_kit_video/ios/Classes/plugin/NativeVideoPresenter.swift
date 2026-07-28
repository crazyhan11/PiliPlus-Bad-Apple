import AVFoundation
import Flutter
import UIKit

final class NativeVideoPresenterRegistry {
  private final class WeakHost {
    weak var value: NativeVideoHostView?

    init(_ value: NativeVideoHostView) {
      self.value = value
    }
  }

  private static var presenters: [Int64: NativeVideoPresenter] = [:]
  private static var hosts: [Int64: WeakHost] = [:]

  static func register(_ presenter: NativeVideoPresenter, handle: Int64) {
    dispatchPrecondition(condition: .onQueue(.main))
    presenters[handle] = presenter
    if let host = hosts[handle]?.value {
      presenter.attach(to: host)
    }
  }

  static func unregister(handle: Int64, presenter: NativeVideoPresenter) {
    let unregister = {
      guard presenters[handle] === presenter else { return }
      presenters.removeValue(forKey: handle)
    }
    if Thread.isMainThread {
      unregister()
    } else {
      DispatchQueue.main.async(execute: unregister)
    }
  }

  static func register(_ host: NativeVideoHostView, handle: Int64) {
    dispatchPrecondition(condition: .onQueue(.main))
    hosts[handle] = WeakHost(host)
    presenters[handle]?.attach(to: host)
  }

  static func unregister(_ host: NativeVideoHostView, handle: Int64) {
    let unregister = {
      guard hosts[handle]?.value === host else { return }
      presenters[handle]?.detach(from: host)
      hosts.removeValue(forKey: handle)
    }
    if Thread.isMainThread {
      unregister()
    } else {
      DispatchQueue.main.async(execute: unregister)
    }
  }
}

final class NativeVideoPresenter {
  private let handle: Int64
  private let displayLayer = AVSampleBufferDisplayLayer()
  private let videoSynchronizer = AVSampleBufferRenderSynchronizer()
  private let danmaku: NativeDanmakuPresenter
  private let danmakuHostView: NativeDanmakuAnimationView
  private let stateLock = NSLock()
  private let videoStateLock = NSLock()
  private weak var host: NativeVideoHostView?
  private var observers: [NSObjectProtocol] = []
  private var disposed = false
  private var cachedFormatDescription: CMVideoFormatDescription?
  private var videoPlaybackRate: Float = 1
  private var isVideoTimelinePaused = false
  private var videoAnchorPTS: Double?
  private var videoAnchorHostTime: Double?
  private var lastEnqueuedPTS: Double?

  init(handle: Int64) {
    dispatchPrecondition(condition: .onQueue(.main))
    self.handle = handle
    let danmakuHostView = NativeDanmakuAnimationView(frame: .zero)
    self.danmakuHostView = danmakuHostView
    danmaku = NativeDanmakuPresenter(renderView: danmakuHostView)
    displayLayer.backgroundColor = UIColor.black.cgColor
    displayLayer.videoGravity = .resize
    displayLayer.isHidden = true
    displayLayer.masksToBounds = true
    videoSynchronizer.addRenderer(displayLayer.sampleBufferRenderer)
    danmakuHostView.isHidden = true

    let center = NotificationCenter.default
    observers = [
      center.addObserver(
        forName: UIApplication.didEnterBackgroundNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.reset(removeImage: true)
      },
      center.addObserver(
        forName: UIApplication.willEnterForegroundNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.reset(removeImage: true)
      },
    ]
    NativeVideoPresenterRegistry.register(self, handle: handle)
  }

  func attach(to host: NativeVideoHostView) {
    dispatchPrecondition(condition: .onQueue(.main))
    if self.host === host, displayLayer.superlayer === host.layer {
      layout()
      return
    }
    stateLock.lock()
    guard !disposed else {
      stateLock.unlock()
      return
    }
    self.host = host
    stateLock.unlock()
    displayLayer.removeFromSuperlayer()
    host.layer.addSublayer(displayLayer)
    host.addSubview(danmakuHostView)
    layout()
  }

  func detach(from host: NativeVideoHostView) {
    dispatchPrecondition(condition: .onQueue(.main))
    guard self.host === host else { return }
    stateLock.lock()
    self.host = nil
    stateLock.unlock()
    displayLayer.removeFromSuperlayer()
    danmakuHostView.removeFromSuperview()
    videoSynchronizer.rate = 0
    reset(removeImage: true)
  }

  func layout() {
    dispatchPrecondition(condition: .onQueue(.main))
    guard let host else { return }
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    displayLayer.frame = host.bounds
    danmakuHostView.frame = host.bounds
    danmaku.setFrame(CGRect(origin: .zero, size: host.bounds.size))
    CATransaction.commit()
  }

  func setFit(_ fit: String) {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.displayLayer.videoGravity = switch fit {
      case "cover": .resizeAspectFill
      case "fill": .resize
      default: .resizeAspect
      }
    }
  }

  func configureDanmaku(_ values: [String: Any]) {
    performDanmakuCommand { [weak self] in self?.danmaku.configure(values) }
  }

  func addDanmaku(_ values: [[String: Any]], epoch: Int64) {
    performDanmakuCommand { [weak self] in
      self?.danmaku.add(values, epoch: epoch)
    }
  }

  func pauseDanmaku(epoch: Int64) {
    performDanmakuCommand { [weak self] in
      guard let self else { return }
      self.pauseVideoTimeline()
      self.danmaku.pause(epoch: epoch)
    }
  }

  func resumeDanmaku(epoch: Int64) {
    performDanmakuCommand { [weak self] in
      guard let self else { return }
      self.resumeVideoTimeline()
      self.danmaku.resume(epoch: epoch)
    }
  }

  func clearDanmaku(epoch: Int64) {
    performDanmakuCommand { [weak self] in self?.danmaku.clear(epoch: epoch) }
  }

  func setDanmakuOpacity(_ opacity: Float) {
    performDanmakuCommand { [weak self] in self?.danmaku.setOpacity(opacity) }
  }

  private func performDanmakuCommand(_ command: @escaping () -> Void) {
    if Thread.isMainThread {
      command()
    } else {
      DispatchQueue.main.async(execute: command)
    }
  }

  func enqueue(_ pixelBuffer: CVPixelBuffer, presentationTime: Double) -> Bool {
    stateLock.lock()
    let canPresent = !disposed && host != nil
    stateLock.unlock()
    guard canPresent else { return false }

    let formatDescription: CMVideoFormatDescription
    if let cachedFormatDescription,
       CMVideoFormatDescriptionMatchesImageBuffer(
         cachedFormatDescription,
         imageBuffer: pixelBuffer
       ) {
      formatDescription = cachedFormatDescription
    } else {
      var created: CMVideoFormatDescription?
      guard CMVideoFormatDescriptionCreateForImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pixelBuffer,
        formatDescriptionOut: &created
      ) == noErr, let created else {
        return false
      }
      cachedFormatDescription = created
      formatDescription = created
    }

    var timing = CMSampleTimingInfo(
      duration: .invalid,
      presentationTimeStamp: presentationTime.isFinite && presentationTime >= 0
        ? CMTime(seconds: presentationTime, preferredTimescale: 60_000)
        : .invalid,
      decodeTimeStamp: .invalid
    )
    var sampleBuffer: CMSampleBuffer?
    guard CMSampleBufferCreateReadyWithImageBuffer(
      allocator: kCFAllocatorDefault,
      imageBuffer: pixelBuffer,
      formatDescription: formatDescription,
      sampleTiming: &timing,
      sampleBufferOut: &sampleBuffer
    ) == noErr, let sampleBuffer else {
      return false
    }

    let renderer = displayLayer.sampleBufferRenderer
    if renderer.status == .failed {
      renderer.flush(removingDisplayedImage: true, completionHandler: nil)
    }
    guard renderer.isReadyForMoreMediaData else { return true }

    guard presentationTime.isFinite, presentationTime >= 0 else {
      if let attachments = CMSampleBufferGetSampleAttachmentsArray(
        sampleBuffer,
        createIfNecessary: true
      ) as? [NSMutableDictionary], let attachment = attachments.first {
        attachment[kCMSampleAttachmentKey_DisplayImmediately] = true
      }
      renderer.enqueue(sampleBuffer)
      revealNativeLayers()
      return true
    }

    let hostTime = CACurrentMediaTime()
    var shouldReanchor = false
    var timelineRate: Float = 1
    var timelinePaused = false
    videoStateLock.lock()
    timelineRate = videoPlaybackRate
    timelinePaused = isVideoTimelinePaused
    if let anchorPTS = videoAnchorPTS,
       let anchorHostTime = videoAnchorHostTime {
      let expectedPTS = anchorPTS
        + (timelinePaused ? 0 : (hostTime - anchorHostTime) * Double(timelineRate))
      let jumped = abs(presentationTime - expectedPTS) > 0.25
      let reversed = lastEnqueuedPTS.map { presentationTime < $0 - 0.001 } ?? false
      shouldReanchor = jumped || reversed
    } else {
      shouldReanchor = true
    }
    if shouldReanchor {
      videoAnchorPTS = presentationTime
      videoAnchorHostTime = hostTime
    }
    lastEnqueuedPTS = presentationTime
    videoStateLock.unlock()

    if shouldReanchor {
      renderer.flush(removingDisplayedImage: false, completionHandler: nil)
    }
    renderer.enqueue(sampleBuffer)
    if shouldReanchor {
      videoSynchronizer.setRate(
        timelinePaused ? 0 : timelineRate,
        time: CMTime(seconds: presentationTime, preferredTimescale: 60_000),
        atHostTime: CMTime(
          seconds: hostTime + (1.0 / 120.0),
          preferredTimescale: 60_000
        )
      )
    }
    revealNativeLayers()
    return true
  }

  func setPlaybackRate(_ rate: Double) {
    guard rate.isFinite, rate > 0 else { return }
    let hostTime = CACurrentMediaTime()
    let currentTime = videoSynchronizer.currentTime()
    videoStateLock.lock()
    videoPlaybackRate = Float(rate)
    if currentTime.isValid {
      videoAnchorPTS = currentTime.seconds
      videoAnchorHostTime = hostTime
    }
    let shouldApply = videoAnchorPTS != nil && !isVideoTimelinePaused
    videoStateLock.unlock()
    if shouldApply {
      videoSynchronizer.setRate(Float(rate), time: .invalid)
    }
  }

  private func pauseVideoTimeline() {
    let hostTime = CACurrentMediaTime()
    let currentTime = videoSynchronizer.currentTime()
    videoStateLock.lock()
    isVideoTimelinePaused = true
    if currentTime.isValid {
      videoAnchorPTS = currentTime.seconds
      videoAnchorHostTime = hostTime
    }
    let hasAnchor = videoAnchorPTS != nil
    videoStateLock.unlock()
    if hasAnchor {
      videoSynchronizer.setRate(0, time: .invalid)
    }
  }

  private func resumeVideoTimeline() {
    let hostTime = CACurrentMediaTime()
    let currentTime = videoSynchronizer.currentTime()
    videoStateLock.lock()
    isVideoTimelinePaused = false
    if currentTime.isValid {
      videoAnchorPTS = currentTime.seconds
      videoAnchorHostTime = hostTime
    }
    let rate = videoPlaybackRate
    let hasAnchor = videoAnchorPTS != nil
    videoStateLock.unlock()
    if hasAnchor {
      videoSynchronizer.setRate(rate, time: .invalid)
    }
  }

  private func revealNativeLayers() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.stateLock.lock()
      let canReveal = !self.disposed && self.host != nil
      self.stateLock.unlock()
      guard canReveal else { return }
      self.displayLayer.isHidden = false
      self.danmakuHostView.isHidden = false
    }
  }

  func dispose() {
    let cleanup = { [self] in
      guard !disposed else { return }
      stateLock.lock()
      disposed = true
      host = nil
      stateLock.unlock()
      NativeVideoPresenterRegistry.unregister(handle: handle, presenter: self)
      observers.forEach(NotificationCenter.default.removeObserver)
      observers.removeAll()
      videoSynchronizer.rate = 0
      reset(removeImage: true)
      danmaku.shutdown()
      displayLayer.removeFromSuperlayer()
      danmakuHostView.removeFromSuperview()
    }
    if Thread.isMainThread {
      cleanup()
    } else {
      DispatchQueue.main.async(execute: cleanup)
    }
  }

  private func reset(removeImage: Bool) {
    dispatchPrecondition(condition: .onQueue(.main))
    videoStateLock.lock()
    videoAnchorPTS = nil
    videoAnchorHostTime = nil
    lastEnqueuedPTS = nil
    videoStateLock.unlock()
    if removeImage {
      displayLayer.sampleBufferRenderer.flush(
        removingDisplayedImage: true,
        completionHandler: nil
      )
      displayLayer.isHidden = true
      danmakuHostView.isHidden = true
    } else {
      displayLayer.sampleBufferRenderer.flush(
        removingDisplayedImage: false,
        completionHandler: nil
      )
    }
  }
}

final class NativeVideoHostView: UIView {
  let handle: Int64

  init(frame: CGRect, handle: Int64) {
    self.handle = handle
    super.init(frame: frame)
    backgroundColor = .clear
    isOpaque = false
    isUserInteractionEnabled = false
    clipsToBounds = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    NativeVideoPresenterRegistry.unregister(self, handle: handle)
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil {
      NativeVideoPresenterRegistry.unregister(self, handle: handle)
    } else {
      NativeVideoPresenterRegistry.register(self, handle: handle)
    }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    guard window != nil else { return }
    NativeVideoPresenterRegistry.register(self, handle: handle)
  }
}

final class NativeVideoPlatformView: NSObject, FlutterPlatformView {
  private let host: NativeVideoHostView

  init(frame: CGRect, handle: Int64) {
    host = NativeVideoHostView(frame: frame, handle: handle)
    host.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    super.init()
  }

  func view() -> UIView {
    host
  }
}

final class NativeVideoPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let values = args as? [String: Any]
    let handle = (values?["handle"] as? NSNumber)?.int64Value ?? 0
    return NativeVideoPlatformView(frame: frame, handle: handle)
  }
}
