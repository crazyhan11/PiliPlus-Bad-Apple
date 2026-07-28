import CoreText
import MetalKit
import UIKit

private struct NativeDanmakuVisual {
  let image: CGImage
  let logicalSize: CGSize
  let usesLinearFiltering: Bool
}

private final class NativeDanmakuMetalItem {
  let kind: String
  let texture: MTLTexture
  let logicalSize: CGSize
  let startPosition: CGPoint
  let endPosition: CGPoint
  let anchorPoint: CGPoint
  let transform: CGAffineTransform
  let startTime: CFTimeInterval
  let duration: CFTimeInterval
  let translationDelay: CFTimeInterval
  let translationDuration: CFTimeInterval
  let startAlpha: Float
  let endAlpha: Float
  let easeInCubic: Bool
  let usesLinearFiltering: Bool
  let zPosition: Int64

  init(
    kind: String,
    texture: MTLTexture,
    logicalSize: CGSize,
    startPosition: CGPoint,
    endPosition: CGPoint,
    anchorPoint: CGPoint = CGPoint(x: 0.5, y: 0.5),
    transform: CGAffineTransform = .identity,
    startTime: CFTimeInterval,
    duration: CFTimeInterval,
    translationDelay: CFTimeInterval = 0,
    translationDuration: CFTimeInterval,
    startAlpha: Float = 1,
    endAlpha: Float = 1,
    easeInCubic: Bool = false,
    usesLinearFiltering: Bool,
    zPosition: Int64
  ) {
    self.kind = kind
    self.texture = texture
    self.logicalSize = logicalSize
    self.startPosition = startPosition
    self.endPosition = endPosition
    self.anchorPoint = anchorPoint
    self.transform = transform
    self.startTime = startTime
    self.duration = duration
    self.translationDelay = translationDelay
    self.translationDuration = translationDuration
    self.startAlpha = startAlpha
    self.endAlpha = endAlpha
    self.easeInCubic = easeInCubic
    self.usesLinearFiltering = usesLinearFiltering
    self.zPosition = zPosition
  }
}

private struct NativeDanmakuVertex {
  var position: SIMD2<Float>
  var textureCoordinate: SIMD2<Float>
  var opacity: Float
}

private final class NativeDanmakuMetalDisplayLinkDriver: NSObject,
  CAMetalDisplayLinkDelegate {
  weak var view: NativeDanmakuMetalView?
  let displayLink: CAMetalDisplayLink

  init(view: NativeDanmakuMetalView, metalLayer: CAMetalLayer) {
    self.view = view
    displayLink = CAMetalDisplayLink(metalLayer: metalLayer)
    super.init()
    displayLink.delegate = self
    displayLink.preferredFrameLatency = 1
  }

  func metalDisplayLink(
    _ link: CAMetalDisplayLink,
    needsUpdate update: CAMetalDisplayLink.Update
  ) {
    view?.renderMetalFrame(link: link, update: update)
  }

}

private final class NativeDanmakuMetalView: UIView {
  var timeProvider: ((CFTimeInterval) -> CFTimeInterval)?

  private let renderDevice: MTLDevice
  private let renderCommandQueue: MTLCommandQueue
  private let textureLoader: MTKTextureLoader
  private let pipeline: MTLRenderPipelineState
  private let linearSampler: MTLSamplerState
  private let nearestSampler: MTLSamplerState
  private var items: [NativeDanmakuMetalItem] = []
  private var logicalSize: CGSize = .zero
  private var globalOpacity: Float = 1
  private var rendersContinuously = false
  private var pauseAfterNextFrame = false
  private var metalDisplayLinkDriver: NativeDanmakuMetalDisplayLinkDriver?

  private static let shader = """
  #include <metal_stdlib>
  using namespace metal;

  struct DanmakuVertex {
    float2 position;
    float2 textureCoordinate;
    float opacity;
  };

  struct RasterData {
    float4 position [[position]];
    float2 textureCoordinate;
    float opacity;
  };

  vertex RasterData danmakuVertex(
    uint vertexID [[vertex_id]],
    const device DanmakuVertex *vertices [[buffer(0)]]) {
    RasterData out;
    out.position = float4(vertices[vertexID].position, 0.0, 1.0);
    out.textureCoordinate = vertices[vertexID].textureCoordinate;
    out.opacity = vertices[vertexID].opacity;
    return out;
  }

  fragment float4 danmakuFragment(
    RasterData in [[stage_in]],
    texture2d<float> texture [[texture(0)]],
    sampler textureSampler [[sampler(0)]]) {
    return texture.sample(textureSampler, in.textureCoordinate) * in.opacity;
  }
  """

  override class var layerClass: AnyClass {
    CAMetalLayer.self
  }

  init(frame frameRect: CGRect, device: MTLDevice, commandQueue: MTLCommandQueue) {
    renderDevice = device
    renderCommandQueue = commandQueue
    textureLoader = MTKTextureLoader(device: device)
    guard let library = try? device.makeLibrary(source: Self.shader, options: nil),
          let vertexFunction = library.makeFunction(name: "danmakuVertex"),
          let fragmentFunction = library.makeFunction(name: "danmakuFragment") else {
      fatalError("Unable to compile the native danmaku shader")
    }
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
    pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
    pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
    pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
    pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
    guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
      fatalError("Unable to create the native danmaku pipeline")
    }
    pipeline = pipelineState
    let linearDescriptor = MTLSamplerDescriptor()
    linearDescriptor.minFilter = .linear
    linearDescriptor.magFilter = .linear
    linearDescriptor.sAddressMode = .clampToZero
    linearDescriptor.tAddressMode = .clampToZero
    let nearestDescriptor = MTLSamplerDescriptor()
    nearestDescriptor.minFilter = .nearest
    nearestDescriptor.magFilter = .nearest
    nearestDescriptor.sAddressMode = .clampToZero
    nearestDescriptor.tAddressMode = .clampToZero
    guard let linearSampler = device.makeSamplerState(descriptor: linearDescriptor),
          let nearestSampler = device.makeSamplerState(descriptor: nearestDescriptor) else {
      fatalError("Unable to create the native danmaku samplers")
    }
    self.linearSampler = linearSampler
    self.nearestSampler = nearestSampler
    super.init(frame: frameRect)
    guard let metalLayer = layer as? CAMetalLayer else {
      fatalError("NativeDanmakuMetalView requires CAMetalLayer")
    }
    metalLayer.device = device
    metalLayer.pixelFormat = .bgra8Unorm
    metalLayer.framebufferOnly = true
    metalLayer.isOpaque = false
    metalLayer.backgroundColor = UIColor.clear.cgColor
    metalLayer.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
    metalLayer.maximumDrawableCount = 3
    autoresizingMask = []
    backgroundColor = .clear
    isOpaque = false
    isUserInteractionEnabled = false
  }

  required init?(coder: NSCoder) {
    fatalError("NativeDanmakuMetalView must be initialized with a Metal device")
  }

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    nil
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window != nil, let metalLayer = layer as? CAMetalLayer {
      configureMetalDisplayLink(metalLayer: metalLayer)
    } else {
      metalDisplayLinkDriver?.displayLink.invalidate()
      metalDisplayLinkDriver = nil
    }
    updateDisplayConfiguration()
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    updateDisplayConfiguration()
  }

  func setLogicalFrame(_ frame: CGRect) {
    logicalSize = frame.size
    updateDisplayConfiguration()
    drawOneFrame()
  }

  func makeTexture(from image: CGImage) -> MTLTexture? {
    try? textureLoader.newTexture(
      cgImage: image,
      options: [
        .origin: MTKTextureLoader.Origin.topLeft,
        .SRGB: false,
        .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
      ]
    )
  }

  func add(_ item: NativeDanmakuMetalItem) {
    items.append(item)
  }

  func removeItems(kind: String) {
    items.removeAll { $0.kind == kind }
    drawOneFrame()
  }

  func clearItems() {
    items.removeAll()
    drawOneFrame()
  }

  func setOpacity(_ opacity: Float) {
    globalOpacity = min(1, max(0, opacity))
    drawOneFrame()
  }

  var hasItems: Bool {
    !items.isEmpty
  }

  private func updateDisplayConfiguration() {
    let maximum = window?.screen.maximumFramesPerSecond
      ?? UIScreen.main.maximumFramesPerSecond
    let maximumRate = Float(maximum)
    metalDisplayLinkDriver?.displayLink.preferredFrameRateRange = CAFrameRateRange(
      minimum: min(60, maximumRate),
      maximum: maximumRate,
      preferred: maximumRate
    )
    if let metalLayer = layer as? CAMetalLayer {
      let scale = window?.screen.scale ?? UIScreen.main.scale
      metalLayer.contentsScale = scale
      metalLayer.drawableSize = CGSize(
        width: max(1, bounds.width * scale),
        height: max(1, bounds.height * scale)
      )
    }
  }

  private func configureMetalDisplayLink(metalLayer: CAMetalLayer) {
    metalDisplayLinkDriver?.displayLink.invalidate()
    let driver = NativeDanmakuMetalDisplayLinkDriver(view: self, metalLayer: metalLayer)
    driver.displayLink.isPaused = !rendersContinuously
    driver.displayLink.add(to: .main, forMode: .common)
    metalDisplayLinkDriver = driver
    updateDisplayConfiguration()
  }

  func startContinuousRendering() {
    rendersContinuously = true
    pauseAfterNextFrame = false
    metalDisplayLinkDriver?.displayLink.isPaused = false
  }

  func pausePreservingFrame() {
    rendersContinuously = false
    pauseAfterNextFrame = false
    metalDisplayLinkDriver?.displayLink.isPaused = true
  }

  func drawOneFrame() {
    pauseAfterNextFrame = !rendersContinuously
    metalDisplayLinkDriver?.displayLink.isPaused = false
  }

  func shutdown() {
    rendersContinuously = false
    pauseAfterNextFrame = false
    metalDisplayLinkDriver?.displayLink.isPaused = true
    metalDisplayLinkDriver?.displayLink.invalidate()
    metalDisplayLinkDriver = nil
    items.removeAll()
    timeProvider = nil
  }

  fileprivate func renderMetalFrame(
    link: CAMetalDisplayLink,
    update: CAMetalDisplayLink.Update
  ) {
    render(drawable: update.drawable, at: update.targetPresentationTimestamp)
    if pauseAfterNextFrame || !rendersContinuously {
      pauseAfterNextFrame = false
      link.isPaused = true
    }
  }

  private func render(drawable: CAMetalDrawable, at mediaTime: CFTimeInterval) {
    guard logicalSize.width > 0, logicalSize.height > 0,
          let commandBuffer = renderCommandQueue.makeCommandBuffer() else {
      return
    }
    let now = timeProvider?(mediaTime) ?? 0
    items.removeAll { now >= $0.startTime + $0.duration }
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = drawable.texture
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
    guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
      return
    }
    encoder.setRenderPipelineState(pipeline)
    for item in items.sorted(by: { $0.zPosition < $1.zPosition }) {
      var vertices = vertices(for: item, at: now)
      encoder.setVertexBytes(
        &vertices,
        length: MemoryLayout<NativeDanmakuVertex>.stride * vertices.count,
        index: 0
      )
      encoder.setFragmentTexture(item.texture, index: 0)
      encoder.setFragmentSamplerState(
        item.usesLinearFiltering ? linearSampler : nearestSampler,
        index: 0
      )
      encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertices.count)
    }
    encoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
    if items.isEmpty {
      rendersContinuously = false
      pauseAfterNextFrame = true
    }
  }

  private func vertices(
    for item: NativeDanmakuMetalItem,
    at time: CFTimeInterval
  ) -> [NativeDanmakuVertex] {
    let age = max(0, time - item.startTime)
    let rawProgress = min(
      1,
      max(0, (age - item.translationDelay) / item.translationDuration)
    )
    let progress = item.easeInCubic ? cubicEaseIn(rawProgress) : rawProgress
    let x = item.startPosition.x
      + (item.endPosition.x - item.startPosition.x) * CGFloat(progress)
    let y = item.startPosition.y
      + (item.endPosition.y - item.startPosition.y) * CGFloat(progress)
    let alphaProgress = min(1, max(0, age / item.duration))
    let opacity = (
      item.startAlpha + (item.endAlpha - item.startAlpha) * Float(alphaProgress)
    ) * globalOpacity
    let width = item.logicalSize.width
    let height = item.logicalSize.height
    let localCorners = [
      CGPoint(x: -item.anchorPoint.x * width, y: -item.anchorPoint.y * height),
      CGPoint(x: (1 - item.anchorPoint.x) * width, y: -item.anchorPoint.y * height),
      CGPoint(x: -item.anchorPoint.x * width, y: (1 - item.anchorPoint.y) * height),
      CGPoint(x: (1 - item.anchorPoint.x) * width, y: (1 - item.anchorPoint.y) * height),
    ]
    let points = localCorners.map { local -> CGPoint in
      let transformed = local.applying(item.transform)
      return CGPoint(x: transformed.x + x, y: transformed.y + y)
    }
    let coordinates = [
      SIMD2<Float>(0, 0), SIMD2<Float>(1, 0),
      SIMD2<Float>(0, 1), SIMD2<Float>(1, 1),
    ]
    let order = [0, 1, 2, 2, 1, 3]
    return order.map { index in
      NativeDanmakuVertex(
        position: normalizedPosition(points[index]),
        textureCoordinate: coordinates[index],
        opacity: opacity
      )
    }
  }

  private func normalizedPosition(_ point: CGPoint) -> SIMD2<Float> {
    SIMD2<Float>(
      Float(point.x / logicalSize.width * 2 - 1),
      Float(1 - point.y / logicalSize.height * 2)
    )
  }

  private func cubicEaseIn(_ progress: CFTimeInterval) -> CFTimeInterval {
    // CAMediaTimingFunction(0.55, 0.055, 0.675, 0.19), solved by x.
    var lower = 0.0
    var upper = 1.0
    for _ in 0..<8 {
      let t = (lower + upper) / 2
      let x = cubicBezier(t, 0.55, 0.675)
      if x < progress { lower = t } else { upper = t }
    }
    return cubicBezier((lower + upper) / 2, 0.055, 0.19)
  }

  private func cubicBezier(
    _ t: CFTimeInterval,
    _ first: CFTimeInterval,
    _ second: CFTimeInterval
  ) -> CFTimeInterval {
    let inverse = 1 - t
    return 3 * inverse * inverse * t * first
      + 3 * inverse * t * t * second
      + t * t * t
  }

  deinit {
    metalDisplayLinkDriver?.displayLink.invalidate()
  }
}

final class NativeDanmakuAnimationView: UIView {
  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    isOpaque = false
    isUserInteractionEnabled = false
    autoresizingMask = []
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("NativeDanmakuAnimationView must be initialized programmatically")
  }
}

final class NativeDanmakuPresenter {
  let layer = CALayer()
  private weak var renderView: NativeDanmakuAnimationView?

  private struct ActiveLayer {
    let layer: CALayer
    let expiresAt: CFTimeInterval
  }

  private final class Clock {
    private var accumulatedTime: CFTimeInterval = 0
    private var mediaTimeAnchor: CFTimeInterval
    private(set) var isPaused = false

    init() {
      mediaTimeAnchor = CACurrentMediaTime()
    }

    var time: CFTimeInterval {
      time(at: CACurrentMediaTime())
    }

    func time(at mediaTime: CFTimeInterval) -> CFTimeInterval {
      if isPaused {
        return accumulatedTime
      }
      return accumulatedTime + max(0, mediaTime - mediaTimeAnchor)
    }

    func pause(at mediaTime: CFTimeInterval = CACurrentMediaTime()) {
      guard !isPaused else { return }
      accumulatedTime += max(0, mediaTime - mediaTimeAnchor)
      isPaused = true
    }

    func resume() {
      guard isPaused else { return }
      let mediaTime = CACurrentMediaTime()
      mediaTimeAnchor = mediaTime
      isPaused = false
    }
  }

  private struct Settings {
    var fontSize = 16.0
    var fontWeight = 4
    var lineHeight = 1.6
    var strokeWidth = 1.5
    var area = 1.0
    var duration = 10.0
    var staticDuration = 5.0
    var scrollFixedVelocity = false
    var massiveMode = false
    var safeArea = true
  }

  private struct ScrollOccupancy {
    let start: CFTimeInterval
    let width: CGFloat
    let duration: CFTimeInterval
  }

  private var settings = Settings()
  private var scrollTracks: [ScrollOccupancy?] = []
  private var staticTrackEnd: [CFTimeInterval] = []
  private var nextZPosition: Int64 = 0
  private var commandEpoch: Int64 = 0
  private let clock: Clock
  private var activeLayers: [ActiveLayer] = []

  init(renderView: NativeDanmakuAnimationView) {
    self.renderView = renderView
    layer.masksToBounds = true
    clock = Clock()
    renderView.layer.addSublayer(layer)
  }

  func setFrame(_ frame: CGRect) {
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.frame = frame
    CATransaction.commit()
    resizeTracks()
  }

  func configure(_ values: [String: Any]) {
    settings.fontSize = number(values["fontSize"], settings.fontSize)
    settings.fontWeight = Int(number(values["fontWeight"], Double(settings.fontWeight)))
    settings.lineHeight = number(values["lineHeight"], settings.lineHeight)
    settings.strokeWidth = number(values["strokeWidth"], settings.strokeWidth)
    settings.area = min(1, max(0.1, number(values["area"], settings.area)))
    settings.duration = max(0.1, number(values["duration"], settings.duration))
    settings.staticDuration = max(0.1, number(values["staticDuration"], settings.staticDuration))
    settings.scrollFixedVelocity = values["scrollFixedVelocity"] as? Bool ?? settings.scrollFixedVelocity
    settings.massiveMode = values["massiveMode"] as? Bool ?? settings.massiveMode
    settings.safeArea = values["safeArea"] as? Bool ?? settings.safeArea
    removeLayers(named: "scroll", if: values["hideScroll"] as? Bool == true)
    removeLayers(named: "top", if: values["hideTop"] as? Bool == true)
    removeLayers(named: "bottom", if: values["hideBottom"] as? Bool == true)
    removeLayers(named: "special", if: values["hideSpecial"] as? Bool == true)
    setOpacity(Float(number(values["opacity"], Double(layer.opacity))))
    resizeTracks()
  }

  func add(_ items: [[String: Any]], epoch: Int64) {
    guard accept(epoch), !clock.isPaused,
          layer.bounds.width > 0, layer.bounds.height > 0 else {
      return
    }
    removeExpiredLayers(at: localTime)
    for values in items {
      guard let text = values["text"] as? String, !text.isEmpty else {
        continue
      }
      switch values["type"] as? String ?? "scroll" {
      case "top":
        addStatic(values, text: text, bottom: false)
      case "bottom":
        addStatic(values, text: text, bottom: true)
      case "special":
        addSpecial(values, text: text)
      default:
        addScroll(values, text: text)
      }
    }
  }

  func pause(epoch: Int64) {
    guard accept(epoch), !clock.isPaused else { return }
    let mediaTime = CACurrentMediaTime()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    for active in activeLayers {
      let localPauseTime = active.layer.convertTime(mediaTime, from: nil)
      active.layer.speed = 0
      active.layer.timeOffset = localPauseTime
    }
    CATransaction.commit()
    CATransaction.flush()
    clock.pause(at: mediaTime)
  }

  func resume(epoch: Int64) {
    guard accept(epoch), clock.isPaused else { return }
    let mediaTime = CACurrentMediaTime()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    for active in activeLayers where active.layer.speed == 0 {
      let pausedTime = active.layer.timeOffset
      active.layer.speed = 1
      active.layer.timeOffset = 0
      active.layer.beginTime = 0
      let resumedLocalTime = active.layer.convertTime(mediaTime, from: nil)
      active.layer.beginTime = resumedLocalTime - pausedTime
    }
    CATransaction.commit()
    clock.resume()
    removeExpiredLayers(at: localTime)
  }

  func clear(epoch: Int64) {
    guard accept(epoch) else { return }
    activeLayers.forEach { $0.layer.removeFromSuperlayer() }
    activeLayers.removeAll(keepingCapacity: true)
    nextZPosition = 0
    scrollTracks = Array(repeating: nil, count: trackCount)
    staticTrackEnd = Array(repeating: 0, count: trackCount)
  }

  private func accept(_ epoch: Int64) -> Bool {
    guard epoch >= commandEpoch else { return false }
    commandEpoch = epoch
    return true
  }

  func setOpacity(_ opacity: Float) {
    let value = min(1, max(0, opacity))
    layer.opacity = value
  }

  func shutdown() {
    activeLayers.forEach { $0.layer.removeFromSuperlayer() }
    activeLayers.removeAll()
  }

  private var trackHeight: CGFloat {
    max(1, CGFloat(settings.fontSize * settings.lineHeight))
  }

  private var trackCount: Int {
    let count = Int((layer.bounds.height * CGFloat(settings.area)) / trackHeight)
    return max(0, settings.safeArea && settings.area == 1 ? count - 1 : count)
  }

  private var localTime: CFTimeInterval {
    clock.time
  }

  private func trackCenterY(_ index: Int) -> CGFloat {
    CGFloat(index) * trackHeight + trackHeight / 2
  }

  private func resizeTracks() {
    let count = trackCount
    if scrollTracks.count < count {
      scrollTracks.append(contentsOf: repeatElement(nil, count: count - scrollTracks.count))
      staticTrackEnd.append(contentsOf: repeatElement(0, count: count - staticTrackEnd.count))
    } else if scrollTracks.count > count {
      scrollTracks.removeLast(scrollTracks.count - count)
      staticTrackEnd.removeLast(staticTrackEnd.count - count)
    }
  }

  private func addScroll(_ values: [String: Any], text: String) {
    let commentLayer = makeTextLayer(values, text: text)
    let width = commentLayer.bounds.width
    // Keep per-frame travel consistent across short and long comments.
    let duration = settings.duration
      * Double((layer.bounds.width + width) / layer.bounds.width)
    let now = localTime
    let index = scrollTracks.indices.first {
      canAddScroll(to: $0, width: width, duration: duration, now: now)
    } ?? (settings.massiveMode ? Int.random(in: scrollTracks.indices) : -1)
    guard index >= 0 else { return }

    let y = trackCenterY(index)
    let start = CGPoint(x: layer.bounds.width + width / 2, y: y)
    let end = CGPoint(x: -width / 2, y: y)
    addAnimatedLayer(
      commentLayer,
      kind: "scroll",
      startPosition: start,
      endPosition: end,
      duration: duration,
      expiresAt: now + duration
    )
    scrollTracks[index] = ScrollOccupancy(start: now, width: width, duration: duration)
  }

  private func canAddScroll(
    to index: Int,
    width: CGFloat,
    duration: CFTimeInterval,
    now: CFTimeInterval
  ) -> Bool {
    guard let previous = scrollTracks[index] else { return true }
    let viewWidth = layer.bounds.width
    let elapsed = max(0, now - previous.start)
    let previousSpeed = Double(viewWidth + previous.width) / previous.duration
    let newSpeed = Double(viewWidth + width) / duration
    let gap = previousSpeed * elapsed - Double(previous.width)
    guard gap >= settings.fontSize else { return false }
    if newSpeed <= previousSpeed { return true }
    let catchTime = gap / (newSpeed - previousSpeed)
    let previousExit = max(
      0,
      (Double(viewWidth + previous.width) - previousSpeed * elapsed) / previousSpeed
    )
    return catchTime >= previousExit
  }

  private func addStatic(_ values: [String: Any], text: String, bottom: Bool) {
    let now = localTime
    let indices = bottom
      ? Array(staticTrackEnd.indices.reversed())
      : Array(staticTrackEnd.indices)
    guard let index = indices.first(where: { staticTrackEnd[$0] <= now }) else {
      return
    }
    let commentLayer = makeTextLayer(values, text: text)
    let y = trackCenterY(index)
    let position = pixelAlignedPosition(
      CGPoint(x: layer.bounds.midX, y: y),
      size: commentLayer.bounds.size
    )
    addAnimatedLayer(
      commentLayer,
      kind: bottom ? "bottom" : "top",
      startPosition: position,
      endPosition: position,
      duration: settings.staticDuration,
      expiresAt: now + settings.staticDuration,
      hidesAtEnd: true
    )
    staticTrackEnd[index] = now + settings.staticDuration
  }

  private func addSpecial(_ values: [String: Any], text: String) {
    let commentLayer = makeTextLayer(values, text: text)
    let startX = CGFloat(number(values["startX"], 0)) * layer.bounds.width
    let startY = CGFloat(number(values["startY"], 0)) * layer.bounds.height
    let endX = CGFloat(number(
      values["endX"],
      number(values["startX"], 0)
    )) * layer.bounds.width
    let endY = CGFloat(number(
      values["endY"],
      number(values["startY"], 0)
    )) * layer.bounds.height
    let start: CGPoint
    let end: CGPoint
    let anchorPoint: CGPoint
    let transform: CGAffineTransform
    if values["raster"] != nil {
      let offsetX = CGFloat(number(values["rasterOffsetX"], 0))
      let offsetY = CGFloat(number(values["rasterOffsetY"], 0))
      let centerX = commentLayer.bounds.width / 2
      let centerY = commentLayer.bounds.height / 2
      start = CGPoint(x: startX + offsetX + centerX, y: startY + offsetY + centerY)
      end = CGPoint(x: endX + offsetX + centerX, y: endY + offsetY + centerY)
      anchorPoint = CGPoint(x: 0.5, y: 0.5)
      transform = .identity
    } else {
      anchorPoint = .zero
      transform = CGAffineTransform(
        a: CGFloat(number(values["transformA"], 1)),
        b: CGFloat(number(values["transformB"], 0)),
        c: CGFloat(number(values["transformC"], 0)),
        d: CGFloat(number(values["transformD"], 1)),
        tx: 0,
        ty: 0
      )
      start = CGPoint(x: startX, y: startY)
      end = CGPoint(x: endX, y: endY)
    }
    let total = max(0.1, number(values["durationMs"], 1000) / 1000)
    let moveDuration = max(0.001, number(values["translationDurationMs"], total * 1000) / 1000)
    let delay = max(0, number(values["translationDelayMs"], 0) / 1000)
    addAnimatedLayer(
      commentLayer,
      kind: "special",
      startPosition: start,
      endPosition: end,
      duration: total,
      expiresAt: localTime + total,
      translationDelay: delay,
      translationDuration: moveDuration,
      startAlpha: Float(number(values["startAlpha"], 1)),
      endAlpha: Float(number(
        values["endAlpha"],
        number(values["startAlpha"], 1)
      )),
      anchorPoint: anchorPoint,
      transform: transform,
      easeInCubic: values["easeInCubic"] as? Bool == true,
      hidesAtEnd: true
    )
  }

  private func addAnimatedLayer(
    _ commentLayer: CALayer,
    kind: String,
    startPosition: CGPoint,
    endPosition: CGPoint,
    duration: CFTimeInterval,
    expiresAt: CFTimeInterval,
    translationDelay: CFTimeInterval = 0,
    translationDuration: CFTimeInterval? = nil,
    startAlpha: Float = 1,
    endAlpha: Float = 1,
    anchorPoint: CGPoint = CGPoint(x: 0.5, y: 0.5),
    transform: CGAffineTransform = .identity,
    easeInCubic: Bool = false,
    hidesAtEnd: Bool = false
  ) {
    commentLayer.name = kind
    commentLayer.anchorPoint = anchorPoint
    commentLayer.position = endPosition
    commentLayer.setAffineTransform(transform)
    commentLayer.opacity = hidesAtEnd ? 0 : endAlpha
    commentLayer.zPosition = CGFloat(takeNextZPosition())
    layer.addSublayer(commentLayer)

    let beginTime = commentLayer.convertTime(CACurrentMediaTime(), from: nil)
    let position = CABasicAnimation(keyPath: "position")
    position.fromValue = startPosition
    position.toValue = endPosition
    position.beginTime = beginTime + translationDelay
    position.duration = max(0.001, translationDuration ?? duration)
    position.fillMode = .backwards
    position.timingFunction = easeInCubic
      ? CAMediaTimingFunction(name: .easeIn)
      : CAMediaTimingFunction(name: .linear)
    commentLayer.add(position, forKey: "danmaku.position")

    if hidesAtEnd || startAlpha != 1 || endAlpha != 1 {
      let opacity = CABasicAnimation(keyPath: "opacity")
      opacity.fromValue = startAlpha
      opacity.toValue = endAlpha
      opacity.beginTime = beginTime
      opacity.duration = max(0.001, duration)
      opacity.timingFunction = CAMediaTimingFunction(name: .linear)
      commentLayer.add(opacity, forKey: "danmaku.opacity")
    }
    activeLayers.append(ActiveLayer(layer: commentLayer, expiresAt: expiresAt))
  }

  private func removeExpiredLayers(at time: CFTimeInterval) {
    activeLayers.removeAll { active in
      guard active.expiresAt <= time else { return false }
      active.layer.removeFromSuperlayer()
      return true
    }
  }

  private func makeVisual(_ values: [String: Any], text: String) -> NativeDanmakuVisual? {
    let textLayer = makeTextLayer(values, text: text)
    let size = textLayer.bounds.size
    let scale = max(1, backingScale * ((values["type"] as? String == "scroll") ? 1.5 : 1))
    let pixelWidth = max(1, Int(ceil(size.width * scale)))
    let pixelHeight = max(1, Int(ceil(size.height * scale)))
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else {
      return nil
    }
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: 0, y: size.height)
    context.scaleBy(x: 1, y: -1)
    textLayer.position = .zero
    textLayer.anchorPoint = .zero
    textLayer.render(in: context)
    guard let image = context.makeImage() else { return nil }
    return NativeDanmakuVisual(
      image: image,
      logicalSize: size,
      usesLinearFiltering: values["type"] as? String != "top"
        && values["type"] as? String != "bottom"
    )
  }

  private func makeTextLayer(_ values: [String: Any], text: String) -> CALayer {
    if let rasterLayer = makeRasterLayer(values) {
      return rasterLayer
    }
    if let nativeLayer = makeCoreTextLayer(values, text: text) {
      return nativeLayer
    }
    return makeCATextLayer(values, text: text)
  }

  private func makeCATextLayer(_ values: [String: Any], text: String) -> CALayer {
    let fontSize = CGFloat(number(values["fontSize"], settings.fontSize))
    let font = danmakuFont(ofSize: fontSize)
    let color = colorFromARGB(values["color"] as? NSNumber)
    let count = (values["count"] as? NSNumber)?.intValue
    let stroke = values["hasStroke"] as? Bool == false ? 0 : settings.strokeWidth
    let attributed = NSMutableAttributedString(string: "")
    if let count {
      let countFont = danmakuFont(ofSize: fontSize * 0.6)
      attributed.append(
        NSAttributedString(
          string: "(\(count))",
          attributes: textAttributes(
            font: countFont,
            color: color,
            stroke: stroke
          )
        )
      )
    }
    attributed.append(
      NSAttributedString(
        string: text,
        attributes: textAttributes(font: font, color: color, stroke: stroke)
      )
    )
    let measured = attributed.boundingRect(
      with: CGSize(
        width: CGFloat.greatestFiniteMagnitude,
        height: CGFloat.greatestFiniteMagnitude
      ),
      options: [.usesFontLeading, .usesLineFragmentOrigin],
      context: nil
    ).integral.size
    let selfSend = values["selfSend"] as? Bool == true
    let strokePadding = CGFloat(stroke)
    let selfSendPadding: CGFloat = selfSend ? 4 : 0
    let container = CALayer()
    container.bounds = CGRect(
      x: 0,
      y: 0,
      width: ceil(measured.width + strokePadding + selfSendPadding),
      height: trackHeight
    )
    let textLayer = CATextLayer()
    textLayer.contentsScale = UIScreen.main.scale
    textLayer.string = attributed
    textLayer.alignmentMode = .left
    textLayer.isWrapped = false
    textLayer.truncationMode = .none
    textLayer.allowsFontSubpixelQuantization = true
    textLayer.frame = CGRect(
      x: strokePadding / 2 + selfSendPadding / 2,
      y: strokePadding / 2,
      width: ceil(measured.width),
      height: min(trackHeight, ceil(measured.height))
    )
    container.addSublayer(textLayer)
    if selfSend {
      container.borderColor = UIColor.systemGreen.cgColor
      container.borderWidth = strokePadding
    }
    return container
  }

  private func makeCoreTextLayer(_ values: [String: Any], text: String) -> CALayer? {
    let isSpecial = values["type"] as? String == "special"
    let fontSize = CGFloat(number(values["fontSize"], settings.fontSize))
    var color = colorFromARGB(values["color"] as? NSNumber)
    if isSpecial, values["startAlpha"] is NSNumber {
      color = color.withAlphaComponent(1)
    }
    let attributed = NSMutableAttributedString(string: "")
    if let count = (values["count"] as? NSNumber)?.intValue {
      attributed.append(
        NSAttributedString(
          string: "(\(count))",
          attributes: [
            .font: danmakuFont(ofSize: fontSize * 0.6),
            .foregroundColor: color,
          ]
        )
      )
    }
    attributed.append(
      NSAttributedString(
        string: text,
        attributes: [
          .font: danmakuFont(ofSize: fontSize),
          .foregroundColor: color,
        ]
      )
    )

    let line = CTLineCreateWithAttributedString(attributed)
    var ascent: CGFloat = 0
    var descent: CGFloat = 0
    var leading: CGFloat = 0
    let textWidth = CGFloat(
      CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
    )
    let configuredStroke = values["hasStroke"] as? Bool == false
      ? 0
      : CGFloat(settings.strokeWidth)
    // CoreText's outlined glyphs read heavier than Flutter's canvas stroke at
    // the same logical width. Keep special-danmaku shadows unchanged.
    let stroke = isSpecial ? configuredStroke : configuredStroke * (2 / 3)
    let selfSend = values["selfSend"] as? Bool == true
    let selfSendPadding: CGFloat = selfSend ? 4 : 0
    let logicalWidth = max(1, ceil(textWidth + stroke + selfSendPadding))
    let logicalHeight = max(1, ceil(ascent + descent + leading + stroke))
    let isScrolling = values["type"] as? String == "scroll"
    // A denser scrolling texture keeps subpixel interpolation crisp while the
    // compositor advances it independently at the display cadence.
    let scale = backingScale * (isScrolling ? 1.5 : 1)
    let pixelWidth = max(1, Int(ceil(logicalWidth * scale)))
    let pixelHeight = max(1, Int(ceil(logicalHeight * scale)))
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else {
      return nil
    }

    context.scaleBy(x: scale, y: scale)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    // Transparent text textures need grayscale antialiasing. LCD smoothing
    // creates a soft fringe once CoreAnimation composites the layer.
    context.setAllowsFontSmoothing(false)
    context.setShouldSmoothFonts(false)
    let origin = CGPoint(
      x: stroke / 2 + (selfSend ? 2 : 0),
      y: stroke / 2 + descent
    )
    if stroke > 0 {
      context.saveGState()
      context.textPosition = origin
      if isSpecial {
        context.setShadow(
          offset: .zero,
          blur: stroke,
          color: UIColor.black.cgColor
        )
        context.setTextDrawingMode(.fill)
        CTLineDraw(line, context)
      } else if values["isColorful"] as? Bool == true {
        context.setLineWidth(stroke)
        context.setTextDrawingMode(.strokeClip)
        CTLineDraw(line, context)
        if let gradient = CGGradient(
          colorsSpace: colorSpace,
          colors: [
            UIColor(red: 0xF2 / 255, green: 0x50 / 255, blue: 0x9E / 255, alpha: 1).cgColor,
            UIColor(red: 0x30 / 255, green: 0x8B / 255, blue: 0xCD / 255, alpha: 1).cgColor,
          ] as CFArray,
          locations: [0, 1]
        ) {
          context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: logicalWidth, y: 0),
            options: []
          )
        }
      } else {
        let outlined = NSMutableAttributedString(attributedString: attributed)
        outlined.enumerateAttribute(
          .font,
          in: NSRange(location: 0, length: outlined.length)
        ) { value, range, _ in
          guard let font = value as? UIFont else { return }
          outlined.addAttributes(
            [
              .foregroundColor: UIColor.clear,
              .strokeColor: overlapSeparatingStrokeColor(for: color),
              .strokeWidth: stroke / font.pointSize * 100,
            ],
            range: range
          )
        }
        context.setTextDrawingMode(.fill)
        CTLineDraw(CTLineCreateWithAttributedString(outlined), context)
      }
      context.restoreGState()
    }
    context.textPosition = origin
    context.setTextDrawingMode(.fill)
    CTLineDraw(line, context)

    if selfSend {
      context.setStrokeColor(UIColor.systemGreen.cgColor)
      context.setLineWidth(max(stroke, 1))
      let inset = max(stroke, 1) / 2
      context.stroke(
        CGRect(
          x: inset,
          y: inset,
          width: max(0, logicalWidth - inset * 2),
          height: max(0, logicalHeight - inset * 2)
        )
      )
    }
    guard let image = context.makeImage() else { return nil }

    let container = CALayer()
    container.bounds = CGRect(
      x: 0,
      y: 0,
      width: logicalWidth,
      height: isSpecial ? logicalHeight : trackHeight
    )
    let imageLayer = CALayer()
    imageLayer.contents = image
    imageLayer.contentsScale = scale
    imageLayer.contentsGravity = .resize
    // Fixed text stays pixel-snapped. Scrolling text uses a denser texture and
    // subpixel interpolation so full-screen motion does not advance in visible
    // whole-pixel steps; special danmaku still needs linear transform sampling.
    let textFilter: CALayerContentsFilter = isScrolling || isSpecial
      ? .linear
      : .nearest
    imageLayer.magnificationFilter = textFilter
    imageLayer.minificationFilter = textFilter
    imageLayer.frame = CGRect(x: 0, y: 0, width: logicalWidth, height: logicalHeight)
    container.addSublayer(imageLayer)
    return container
  }

  private func makeRasterLayer(_ values: [String: Any]) -> CALayer? {
    guard let raster = values["raster"] as? FlutterStandardTypedData,
          let pixelWidth = (values["pixelWidth"] as? NSNumber)?.intValue,
          let pixelHeight = (values["pixelHeight"] as? NSNumber)?.intValue,
          pixelWidth > 0, pixelHeight > 0,
          raster.data.count == pixelWidth * pixelHeight * 4,
          let provider = CGDataProvider(data: raster.data as CFData),
          let image = CGImage(
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: pixelWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(
              rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
            ).union(.byteOrder32Big),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
          ) else {
      return nil
    }
    let logicalWidth = CGFloat(number(values["logicalWidth"], Double(pixelWidth)))
    let logicalHeight = CGFloat(number(values["logicalHeight"], Double(pixelHeight)))
    let isSpecial = values["type"] as? String == "special"
    let container = CALayer()
    container.bounds = CGRect(
      x: 0,
      y: 0,
      width: logicalWidth,
      height: isSpecial ? logicalHeight : trackHeight
    )
    let imageLayer = CALayer()
    imageLayer.contents = image
    imageLayer.contentsGravity = .resize
    imageLayer.magnificationFilter = .linear
    imageLayer.minificationFilter = .linear
    imageLayer.frame = CGRect(x: 0, y: 0, width: logicalWidth, height: logicalHeight)
    container.addSublayer(imageLayer)
    return container
  }

  private func textAttributes(
    font: UIFont,
    color: UIColor,
    stroke: Double
  ) -> [NSAttributedString.Key: Any] {
    var attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: color,
    ]
    if stroke > 0 {
      // NSAttributedString expresses stroke width as a percentage of font size.
      attributes[.strokeColor] = overlapSeparatingStrokeColor(for: color)
      attributes[.strokeWidth] = -CGFloat(stroke) / font.pointSize * 100
    }
    return attributes
  }

  private func removeLayers(named type: String, if shouldRemove: Bool) {
    guard shouldRemove else { return }
    activeLayers.removeAll { active in
      guard active.layer.name == type else { return false }
      active.layer.removeFromSuperlayer()
      return true
    }
  }

  private func takeNextZPosition() -> Int64 {
    nextZPosition += 1
    return nextZPosition
  }

  private func overlapSeparatingStrokeColor(for color: UIColor) -> UIColor {
    // This matches 72% black over white, while the higher source alpha keeps
    // text from lower danmaku layers from bleeding through the top outline.
    UIColor(
      red: 0.217,
      green: 0.217,
      blue: 0.217,
      alpha: 0.92 * color.cgColor.alpha
    )
  }

  private var backingScale: CGFloat {
    UIScreen.main.scale
  }

  private func pixelAlignedPosition(
    _ position: CGPoint,
    size: CGSize
  ) -> CGPoint {
    let scale = max(1, backingScale)
    let origin = CGPoint(
      x: position.x - size.width / 2,
      y: position.y - size.height / 2
    )
    let alignedOrigin = CGPoint(
      x: (origin.x * scale).rounded() / scale,
      y: (origin.y * scale).rounded() / scale
    )
    return CGPoint(
      x: alignedOrigin.x + size.width / 2,
      y: alignedOrigin.y + size.height / 2
    )
  }

  private func number(_ value: Any?, _ fallback: Double) -> Double {
    (value as? NSNumber)?.doubleValue ?? fallback
  }

  private func fontWeight(_ value: Int) -> UIFont.Weight {
    switch value {
    case ...0: return .ultraLight
    case 1: return .thin
    case 2: return .light
    case 3: return .regular
    case 4: return .medium
    case 5: return .semibold
    case 6: return .bold
    case 7: return .heavy
    default: return .black
    }
  }

  private func danmakuFont(ofSize size: CGFloat) -> UIFont {
    let weight = max(0, min(8, settings.fontWeight + 1))
    let name = switch weight {
    case 5...: "PingFangSC-Semibold"
    case 3...: "PingFangSC-Medium"
    default: "PingFangSC-Regular"
    }
    return UIFont(name: name, size: size)
      ?? UIFont.systemFont(ofSize: size, weight: fontWeight(weight))
  }

  private func colorFromARGB(_ value: NSNumber?) -> UIColor {
    let argb = value?.uint32Value ?? 0xFFFFFFFF
    return UIColor(
      red: CGFloat((argb >> 16) & 0xFF) / 255,
      green: CGFloat((argb >> 8) & 0xFF) / 255,
      blue: CGFloat(argb & 0xFF) / 255,
      alpha: CGFloat((argb >> 24) & 0xFF) / 255
    )
  }
}
