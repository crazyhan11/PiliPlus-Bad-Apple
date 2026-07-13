# iOS AV1 与 IGL Metal 架构

## 目标与边界

本实现不替换 mpv。mpv 继续负责网络流、DASH、缓存、音频、时钟、选轨和 VideoToolbox 解码；只替换 iOS 硬件视频帧进入 Flutter 前的渲染端。

```text
mpv + FFmpeg 8 + VideoToolbox
  -> borrowed NV12/P010 CVPixelBuffer
  -> IGL Metal color conversion
  -> triple-buffered IOSurface BGRA
  -> Flutter external texture
  -> Impeller Metal composition with UI and danmaku
```

最低目标为 iOS 26.0，产物只验证 iOS arm64 真机。模拟器 slice 保留兼容用途，但不是此功能的验证目标。

## mpv Render API

`tool/libmpv-darwin-build/patches/mpv-cvpixelbuffer-render-api.patch` 新增 `cvpixelbuffer` render backend 和以下公共参数：

- `MPV_RENDER_API_TYPE_CVPIXELBUFFER`
- `MPV_RENDER_PARAM_CVPIXELBUFFER_CALLBACK`
- `MPV_RENDER_PARAM_CVPIXELBUFFER_CALLBACK_CTX`
- `MPV_RENDER_PARAM_CVPIXELBUFFER_SIZE`

backend 向 mpv 注册 `AV_HWDEVICE_TYPE_VIDEOTOOLBOX`。缺少这一步时，decoder 无法建立直接硬解设备，视频输出尺寸持续为零并表现为黑屏。

render callback 在 `mpv_render_context_render()` 内同步调用。`CVPixelBufferRef` 只在 callback 期间借用，不做 CPU copy；Metal command buffer 会持有其编码使用的资源直到 GPU 完成。

## IGL Metal 渲染

`IGLMetalTexture` 使用 IGL Metal-only 静态库：

- 8-bit NV12 video/full range
- 10-bit P010 video/full range
- BT.601、BT.709、BT.2020 YUV 矩阵
- crop、0/90/180/270 度旋转
- 全屏三角形和双线性采样

Metal-only 配置需显式关闭依赖部署，仓库已 vendor 所需 fmt/ldrutils：

```bash
cmake -S third_party/igl -B build/igl-ios-arm64 -G Ninja \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=26.0 \
  -DCMAKE_BUILD_TYPE=Release \
  -DIGL_DEPLOY_DEPS=OFF \
  -DIGL_WITH_METAL=ON \
  -DIGL_WITH_GLSLANG=OFF \
  -DIGL_WITH_OPENGL=OFF \
  -DIGL_WITH_OPENGLES=OFF \
  -DIGL_WITH_VULKAN=OFF \
  -DIGL_WITH_SHELL=OFF \
  -DIGL_WITH_SAMPLES=OFF \
  -DIGL_WITH_TESTS=OFF
cmake --build build/igl-ios-arm64 --parallel
```

输出是三个 `kCVPixelFormatType_32BGRA` 缓冲，创建时设置：

```text
kCVPixelBufferIOSurfacePropertiesKey
kCVPixelBufferMetalCompatibilityKey
```

输出 Metal texture 和 framebuffer 只在尺寸变化时建立并缓存。每帧只导入 VideoToolbox 的两个 plane、编码 shader 并提交 command buffer。

## 异步三缓冲

首个正确性版本每帧调用 `waitUntilCompleted()`，会阻塞视频工作线程。当前实现改为：

1. IGL 提交 Metal command buffer。
2. completion handler 确认 GPU 成功完成。
3. 将完成的 buffer 标记为 current。
4. 在主线程调用 Flutter `textureFrameAvailable`。

Flutter 不会读取 GPU 尚在写入的 buffer。尺寸变化时通过 buffer identity 丢弃旧尺寸的延迟 completion，避免旧帧覆盖新尺寸状态。

## IOSurface 与零拷贝

FlutterTexture 的方法名 `copyPixelBuffer` 不代表复制像素。当前实现只返回 `CVPixelBufferRetain(_buffers[index])`。

Flutter Engine 的 Impeller Metal 路径随后执行：

```text
CVMetalTextureCacheCreateTextureFromImage
CVMetalTextureGetTexture
impeller::TextureMTL::Wrapper
```

它们包装同一块 IOSurface，不锁定 base address、不把像素读回 CPU，也不执行 memcpy。因此 IGL 输出到 Impeller 的边界是像素零拷贝。

`irondash_texture` 的 `BoxedIOSurface` 在 iOS 上最终同样通过 `CVPixelBufferCreateWithIOSurface` 实现 `copyPixelBuffer` 并注册官方 `FlutterTextureRegistry`。它是有用的跨平台/Rust 抽象，但不会比当前 Objective-C++ 实现减少一次 iOS 像素复制，因为当前路径本身没有该复制。

## 仍然存在的 GPU 工作

当前仍有两个必要阶段：

1. IGL 将 NV12/P010 转为 BGRA。
2. Impeller 采样 BGRA，与 Flutter UI 和弹幕合成。

官方 Flutter Engine 直接外部纹理路径只识别 8-bit NV12/BGRA，并将 NV12 色彩空间限制为 BT.601；不能完整覆盖 BT.709/BT.2020 和 P010。因此不能在保持当前色彩与 10-bit 支持的前提下直接删除 IGL pass。

进一步减少一次 GPU pass 需要维护定制 Flutter Engine：让 Impeller external texture 接收 NV12/P010 两个 `id<MTLTexture>` plane，并在最终合成 shader 中完成矩阵转换。这不是 IOSurface 零拷贝的前提，只是未来可选的 GPU pass 合并优化。

## 回退与诊断

成功路径日志：

```text
IGLMetalTexture: initialized renderer=igl-metal interop=cvmetaltexture
VideoOutput: renderer: igl-metal / cvmetaltexture / flutter-cvpixelbuffer
IGLMetalTexture: resize: <width>x<height>
IGLMetalTexture: first native frame format=<fourcc> size=<width>x<height> planes=2
```

若 IGL 初始化失败，自动回退 OpenGL ES：

```text
VideoOutput: IGL Metal unavailable, falling back to OpenGL ES: <reason>
```

纹理导入、framebuffer、command buffer、encoder 和 GPU completion 错误都会留下具体阶段日志。mpv 调试信息应同时显示：

```text
pixelformat: videotoolbox
hwPixelformat: nv12
hwdec-current: videotoolbox
```

## 已验证结果

- iPad mini (A17 Pro)：VideoToolbox 硬解、IGL Metal、Flutter Impeller 路径正常
- iPhone 12 mini：横屏安全区、比例、全屏显示正常
- 4K AV1、普通 H.264/HEVC 内容
- 画面色彩、方向、crop 与比例
- 弹幕/UI 继续由 Flutter 合成
- 拖动、暂停/恢复、横竖屏及多分辨率切换
- 异步三缓冲期间无 Metal completion 或 CoreVideo 导入错误

## 版本与来源

- IGL: `01ce414ff6266c3b71bc11b7fc720c0d28cc066c`
- fmt: `e69e5f977d458f2650bb346dadf2ad30c5320281`
- ldrutils: `e30c3e56be2c676f6f81b1973924270ce82797cb`
- mpv: 0.41.0 source snapshot
- FFmpeg: 8.0
- libplacebo: 7.360.1
- IGL merged static archive SHA-256: `bb9343b1881ef58d1c25e106d9701c588a2b6633ad43172936625e766c3b42f7`
- XCFramework archive SHA-256: `d70a2a7b412a972f5cf7263e39155e43ff9863948f7f2a0322936a6fb3c4de56`

各上游组件继续遵循其原始许可证；vendored IGL、fmt 和 ldrutils 目录保留对应许可证文件。

## 未签名 IPA

`tool/package_ios_unsigned.sh` 使用 Release 模式与 `--no-codesign` 构建，验证 `Runner.app` 未签名后，再封装为标准 `Payload/Runner.app` IPA。该产物不能直接安装，必须由使用者自行签名。
