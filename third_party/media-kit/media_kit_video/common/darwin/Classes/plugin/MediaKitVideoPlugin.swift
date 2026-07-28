#if canImport(Flutter)
  import Flutter
#elseif canImport(FlutterMacOS)
  import FlutterMacOS
#endif

public class MediaKitVideoPlugin: NSObject, FlutterPlugin {
  private static let CHANNEL_NAME = "com.alexmercerind/media_kit_video"

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if canImport(Flutter)
      let binaryMessenger = registrar.messenger()
      let registry = registrar.textures()
      let utils: UtilsProtocol? = nil
      registrar.register(
        NativeVideoPlatformViewFactory(),
        withId: "com.alexmercerind/media_kit_video/native-video"
      )
    #elseif canImport(FlutterMacOS)
      let binaryMessenger = registrar.messenger
      let registry = registrar.textures
      let utils: UtilsProtocol? = Utils(registrar)
    #endif

    let channel = FlutterMethodChannel(
      name: CHANNEL_NAME,
      binaryMessenger: binaryMessenger
    )
    let instance = MediaKitVideoPlugin(
      registry: registry,
      channel: channel,
      utils: utils
    )
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private let channel: FlutterMethodChannel
  private let videoOutputManager: VideoOutputManager
  private let utils: UtilsProtocol?

  init(
    registry: FlutterTextureRegistry,
    channel: FlutterMethodChannel,
    utils: UtilsProtocol?
  ) {
    self.channel = channel
    videoOutputManager = VideoOutputManager(
      registry: registry
    )
    self.utils = utils
  }

  public func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "VideoOutputManager.Create":
      handleCreateMethodCall(call.arguments, result)
    case "VideoOutputManager.SetSize":
      handleSetSizeMethodCall(call.arguments, result)
    case "VideoOutputManager.SetNativeSurface":
      handleSetNativeSurfaceMethodCall(call.arguments, result)
    case "VideoOutputManager.SetNativePlaybackRate":
      handleSetNativePlaybackRateMethodCall(call.arguments, result)
    case "Danmaku.Configure", "Danmaku.Add", "Danmaku.AddBatch", "Danmaku.Pause", "Danmaku.Resume", "Danmaku.Clear", "Danmaku.SetOpacity":
      handleDanmakuMethodCall(call.method, call.arguments, result)
    case "VideoOutputManager.Dispose":
      handleDisposeMethodCall(call.arguments, result)
    case "Utils.EnterNativeFullscreen":
      handleEnterNativeFullscreenMethodCall(call.arguments, result)
    case "Utils.ExitNativeFullscreen":
      handleExitNativeFullscreenMethodCall(call.arguments, result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleCreateMethodCall(
    _ arguments: Any?,
    _ result: FlutterResult
  ) {
    let args = arguments as? [String: Any]
    let handleStr = args?["handle"] as! String
    let handle: Int64? = Int64(handleStr)
    let configDict = args?["configuration"] as! [String: Any]
    let configuration = VideoOutputConfiguration.fromDict(configDict)

    assert(handle != nil, "handle must be an Int64")

    videoOutputManager.create(
      handle: handle!,
      configuration: configuration,
      textureUpdateCallback: { (_ textureId: Int64, _ size: CGSize) in
        self.channel.invokeMethod(
          "VideoOutput.Resize",
          arguments: [
            "handle": handle!,
            "id": textureId,
            "rect": [
              "top": 0,
              "left": 0,
              "width": size.width,
              "height": size.height,
            ],
          ] as [String: Any]
        )
      }
    )

    result(nil)
  }

  private func handleSetSizeMethodCall(
    _ arguments: Any?,
    _ result: FlutterResult
  ) {
    let args = arguments as? [String: Any]
    let handleStr = args?["handle"] as! String
    let widthStr = args?["width"] as! String
    let heightStr = args?["height"] as! String

    let handle: Int64? = Int64(handleStr)
    let width: Int64? = Int64(widthStr)
    let height: Int64? = Int64(heightStr)

    assert(handle != nil, "handle must be an Int64")

    self.videoOutputManager.setSize(
      handle: handle!,
      width: width,
      height: height
    )

    result(nil)
  }

  private func handleDisposeMethodCall(
    _ arguments: Any?,
    _ result: FlutterResult
  ) {
    let args = arguments as? [String: Any]
    let handleStr = args?["handle"] as! String
    let handle: Int64? = Int64(handleStr)

    assert(handle != nil, "handle must be an Int64")

    videoOutputManager.destroy(
      handle: handle!
    )

    result(nil)
  }

  private func handleSetNativeSurfaceMethodCall(
    _ arguments: Any?,
    _ result: FlutterResult
  ) {
    #if canImport(Flutter) && !targetEnvironment(simulator)
      let args = arguments as? [String: Any]
      guard
        let handleString = args?["handle"] as? String,
        let handle = Int64(handleString)
      else {
        return result(FlutterError(code: "invalid-arguments", message: nil, details: nil))
      }
      videoOutputManager.setNativeSurface(
        handle: handle,
        fit: args?["fit"] as? String ?? "contain"
      )
      result(nil)
    #else
      result(FlutterMethodNotImplemented)
    #endif
  }

  private func handleDanmakuMethodCall(
    _ method: String,
    _ arguments: Any?,
    _ result: FlutterResult
  ) {
    #if canImport(Flutter) && !targetEnvironment(simulator)
      guard
        let args = arguments as? [String: Any],
        let handleString = args["handle"] as? String,
        let handle = Int64(handleString)
      else {
        return result(FlutterError(code: "invalid-arguments", message: nil, details: nil))
      }
      switch method {
      case "Danmaku.Configure":
        videoOutputManager.configureDanmaku(handle: handle, values: args)
      case "Danmaku.Add":
        videoOutputManager.addDanmaku(handle: handle, values: args, epoch: 0)
      case "Danmaku.AddBatch":
        let epoch = (args["epoch"] as? NSNumber)?.int64Value ?? 0
        let items = args["items"] as? [[String: Any]] ?? []
        videoOutputManager.addDanmaku(
          handle: handle,
          values: items,
          epoch: epoch
        )
      case "Danmaku.Pause":
        let epoch = (args["epoch"] as? NSNumber)?.int64Value ?? 0
        videoOutputManager.pauseDanmaku(handle: handle, epoch: epoch)
      case "Danmaku.Resume":
        let epoch = (args["epoch"] as? NSNumber)?.int64Value ?? 0
        videoOutputManager.resumeDanmaku(handle: handle, epoch: epoch)
      case "Danmaku.Clear":
        let epoch = (args["epoch"] as? NSNumber)?.int64Value ?? 0
        videoOutputManager.clearDanmaku(handle: handle, epoch: epoch)
      case "Danmaku.SetOpacity":
        let opacity = (args["opacity"] as? NSNumber)?.floatValue ?? 1
        videoOutputManager.setDanmakuOpacity(handle: handle, opacity: opacity)
      default:
        break
      }
      result(nil)
    #else
      result(FlutterMethodNotImplemented)
    #endif
  }

  private func handleSetNativePlaybackRateMethodCall(
    _ arguments: Any?,
    _ result: FlutterResult
  ) {
    #if canImport(Flutter) && !targetEnvironment(simulator)
      let args = arguments as? [String: Any]
      guard
        let handleString = args?["handle"] as? String,
        let handle = Int64(handleString),
        let rate = (args?["rate"] as? NSNumber)?.doubleValue
      else {
        return result(FlutterError(code: "invalid-arguments", message: nil, details: nil))
      }
      videoOutputManager.setNativePlaybackRate(handle: handle, rate: rate)
      result(nil)
    #else
      result(FlutterMethodNotImplemented)
    #endif
  }

  private func handleEnterNativeFullscreenMethodCall(
    _: Any?,
    _ result: FlutterResult
  ) {
    if utils == nil {
      return result(FlutterMethodNotImplemented)
    }

    utils?.enterNativeFullscreen()
    result(nil)
  }

  private func handleExitNativeFullscreenMethodCall(
    _: Any?,
    _ result: FlutterResult
  ) {
    if utils == nil {
      return result(FlutterMethodNotImplemented)
    }

    utils?.exitNativeFullscreen()
    result(nil)
  }
}
