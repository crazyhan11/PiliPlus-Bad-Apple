#import "IGLMetalTexture.h"

#import <CoreVideo/CoreVideo.h>
#import <Metal/Metal.h>
#import <UIKit/UIKit.h>
#import <simd/simd.h>

#include <array>
#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>

#include <igl/IGL.h>
#include <igl/metal/CommandBuffer.h>
#include <igl/metal/HWDevice.h>
#include <igl/metal/PlatformDevice.h>
#include <mpv/render.h>

namespace {

constexpr char kShader[] = R"(
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
  float4 position [[position]];
  float2 uv;
};

struct ColorParams {
  float3x3 matrix;
  float3 offset;
  float2 cropOrigin;
  float2 cropSize;
  uint rotation;
  uint hdrMode;
  uint convertBT2020;
  uint hdrOutput;
};

float3 pqToLinear(float3 value) {
  const float m1 = 2610.0 / 16384.0;
  const float m2 = 2523.0 / 32.0;
  const float c1 = 3424.0 / 4096.0;
  const float c2 = 2413.0 / 128.0;
  const float c3 = 2392.0 / 128.0;
  const float3 p = fast::powr(max(value, 0.0), float3(1.0 / m2));
  return fast::powr(
      max(p - c1, 0.0) / max(c2 - c3 * p, 1e-6), float3(1.0 / m1));
}

float3 hlgToLinear(float3 value) {
  const float a = 0.17883277;
  const float b = 0.28466892;
  const float c = 0.55991073;
  const float3 scene = select(
      (value * value) / 3.0,
      (fast::exp((value - c) / a) + b) / 12.0,
      value > 0.5);
  const float sceneLuma = max(dot(scene, float3(0.2627, 0.6780, 0.0593)), 1e-6);
  return scene * fast::powr(sceneLuma, 0.2);
}

float toneMapChannel(float value) {
  const float knee = 0.5;
  if (value <= knee) {
    return max(value, 0.0);
  }
  const float excess = value - knee;
  return knee + (1.0 - knee) * excess / (excess + (1.0 - knee));
}

float3 toneMapHDR(float3 linear) {
  linear = max(linear, 0.0);
  const float peak = max(max(linear.r, linear.g), linear.b);
  if (peak <= 1e-6) {
    return 0.0;
  }
  return linear * (toneMapChannel(peak) / peak);
}

float3 bt2020ToExtendedSRGB(float3 value) {
  const float3x3 conversion = float3x3(
      float3(1.6605, -0.1246, -0.0182),
      float3(-0.5876, 1.1329, -0.1006),
      float3(-0.0728, -0.0083, 1.1187));
  return max(conversion * value, 0.0);
}

float3 compressGamut(float3 value) {
  const float peak = max(max(value.r, value.g), value.b);
  return peak > 1.0 ? value / peak : value;
}

float3 linearToSRGB(float3 value) {
  value = max(value, 0.0);
  return select(
      value * 12.92,
      1.055 * fast::powr(value, float3(1.0 / 2.4)) - 0.055,
      value > 0.0031308);
}

vertex VertexOut vertexMain(uint vertexID [[vertex_id]]) {
  const float2 positions[3] = {
    float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0)
  };
  const float2 texcoords[3] = {
    float2(0.0, 1.0), float2(2.0, 1.0), float2(0.0, -1.0)
  };
  VertexOut out;
  out.position = float4(positions[vertexID], 0.0, 1.0);
  out.uv = texcoords[vertexID];
  return out;
}

fragment float4 fragmentMain(VertexOut in [[stage_in]],
                             texture2d<float> luma [[texture(0)]],
                             texture2d<float> chroma [[texture(1)]],
                             sampler linearSampler [[sampler(0)]],
                             constant ColorParams& params [[buffer(0)]]) {
  float2 uv = in.uv;
  switch (params.rotation) {
    case 90: uv = float2(uv.y, 1.0 - uv.x); break;
    case 180: uv = float2(1.0 - uv.x, 1.0 - uv.y); break;
    case 270: uv = float2(1.0 - uv.y, uv.x); break;
    default: break;
  }
  uv = params.cropOrigin + uv * params.cropSize;
  const float y = luma.sample(linearSampler, uv).r;
  const float2 cbcr = chroma.sample(linearSampler, uv).rg;
  float3 rgb = params.matrix * (float3(y, cbcr) + params.offset);
  if (params.hdrMode != 0) {
    // PQ uses absolute luminance (1.0 = 10000 nits). HLG is evaluated for a
    // nominal 1000-nit display. Normalize both around 203-nit HDR diffuse white.
    rgb = params.hdrMode == 1
        ? pqToLinear(rgb) * (10000.0 / 203.0)
        : hlgToLinear(rgb) * (1000.0 / 203.0);
    if (params.convertBT2020 != 0) {
      rgb = bt2020ToExtendedSRGB(rgb);
    }
    if (params.hdrOutput != 0) {
      return float4(linearToSRGB(rgb), 1.0);
    }
    rgb = compressGamut(toneMapHDR(rgb));
    rgb = linearToSRGB(rgb);
  }
  return float4(saturate(rgb), 1.0);
}
)";

struct ColorParams {
  simd_float3x3 matrix;
  simd_float3 offset;
  simd_float2 cropOrigin;
  simd_float2 cropSize;
  uint32_t rotation;
  uint32_t hdrMode;
  uint32_t convertBT2020;
  uint32_t hdrOutput;
};

static simd_float3x3 Matrix(float yScale, float rV, float gU, float gV, float bU) {
  return simd_matrix_from_rows(
      simd_make_float3(yScale, 0.0f, rV),
      simd_make_float3(yScale, gU, gV),
      simd_make_float3(yScale, bU, 0.0f));
}

static ColorParams GetColorParams(CVPixelBufferRef buffer,
                                  const mpv_render_cvpixelbuffer_frame& frame,
                                  bool hdrOutput) {
  const OSType format = CVPixelBufferGetPixelFormatType(buffer);
  const bool tenBit = format == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange ||
                      format == kCVPixelFormatType_420YpCbCr10BiPlanarFullRange;
  const bool fullRange = format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange ||
                         format == kCVPixelFormatType_420YpCbCr10BiPlanarFullRange;
  CFTypeRef matrixAttachment = CVBufferGetAttachment(
      buffer, kCVImageBufferYCbCrMatrixKey, nullptr);
  CFTypeRef transferAttachment = CVBufferGetAttachment(
      buffer, kCVImageBufferTransferFunctionKey, nullptr);
  CFTypeRef primariesAttachment = CVBufferGetAttachment(
      buffer, kCVImageBufferColorPrimariesKey, nullptr);

  ColorParams result{};
  const float sampleMax = tenBit ? 1023.0f : 255.0f;
  const float videoBlack = tenBit ? 64.0f : 16.0f;
  const float videoRange = tenBit ? 876.0f : 219.0f;
  const float chromaCenter = tenBit ? (512.0f / 1023.0f) : 0.5f;
  const float yOffset = fullRange ? 0.0f : -(videoBlack / sampleMax);
  const float yScale = fullRange ? 1.0f : (sampleMax / videoRange);
  result.offset = simd_make_float3(yOffset, -chromaCenter, -chromaCenter);

  if (matrixAttachment && CFEqual(matrixAttachment, kCVImageBufferYCbCrMatrix_ITU_R_601_4)) {
    result.matrix = fullRange
        ? Matrix(1.0f, 1.4020f, -0.344136f, -0.714136f, 1.7720f)
        : Matrix(yScale, 1.596027f, -0.391762f, -0.812968f, 2.017232f);
  } else if (matrixAttachment &&
             CFEqual(matrixAttachment, kCVImageBufferYCbCrMatrix_ITU_R_2020)) {
    result.matrix = fullRange
        ? Matrix(1.0f, 1.4746f, -0.164553f, -0.571353f, 1.8814f)
        : Matrix(yScale, 1.678674f, -0.187326f, -0.650424f, 2.141772f);
  } else {
    result.matrix = fullRange
        ? Matrix(1.0f, 1.5748f, -0.187324f, -0.468124f, 1.8556f)
        : Matrix(yScale, 1.792741f, -0.213249f, -0.532909f, 2.112402f);
  }

  const float width = static_cast<float>(std::max(frame.width, 1));
  const float height = static_cast<float>(std::max(frame.height, 1));
  const bool hasCrop = frame.crop_x1 > frame.crop_x0 && frame.crop_y1 > frame.crop_y0;
  result.cropOrigin = hasCrop
      ? simd_make_float2(frame.crop_x0 / width, frame.crop_y0 / height)
      : simd_make_float2(0.0f, 0.0f);
  result.cropSize = hasCrop
      ? simd_make_float2((frame.crop_x1 - frame.crop_x0) / width,
                         (frame.crop_y1 - frame.crop_y0) / height)
      : simd_make_float2(1.0f, 1.0f);
  result.rotation = static_cast<uint32_t>((frame.rotate % 360 + 360) % 360);
  if (transferAttachment &&
      CFEqual(transferAttachment, kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ)) {
    result.hdrMode = 1;
  } else if (transferAttachment &&
             CFEqual(transferAttachment, kCVImageBufferTransferFunction_ITU_R_2100_HLG)) {
    result.hdrMode = 2;
  }
  result.convertBT2020 =
      (primariesAttachment &&
       CFEqual(primariesAttachment, kCVImageBufferColorPrimaries_ITU_R_2020)) ||
      (matrixAttachment &&
       CFEqual(matrixAttachment, kCVImageBufferYCbCrMatrix_ITU_R_2020));
  result.hdrOutput = hdrOutput;
  return result;
}

static NSString *ResultMessage(const igl::Result& result, NSString *operation) {
  if (result.isOk()) {
    return nil;
  }
  return [NSString stringWithFormat:@"%@: %s", operation.UTF8String, result.message.c_str()];
}

}  // namespace

@interface IGLMetalTexture () {
  mpv_render_context *_renderContext;
  IGLMetalTextureUpdateCallback _updateCallback;
  IGLMetalTextureFrameReadyCallback _frameReadyCallback;
  IGLMetalTextureNativeFrameCallback _nativeFrameCallback;
  IGLMetalTextureDynamicRangeCallback _dynamicRangeCallback;
  std::shared_ptr<igl::IDevice> _device;
  std::shared_ptr<igl::ICommandQueue> _queue;
  std::shared_ptr<igl::IRenderPipelineState> _sdrPipeline;
  std::shared_ptr<igl::IRenderPipelineState> _hdrPipeline;
  std::shared_ptr<igl::ISamplerState> _sampler;
  std::array<CVPixelBufferRef, 3> _buffers;
  std::array<std::shared_ptr<igl::ITexture>, 3> _targetTextures;
  std::array<std::shared_ptr<igl::IFramebuffer>, 3> _framebuffers;
  std::array<bool, 3> _inFlight;
  std::mutex _bufferMutex;
  std::atomic<int> _currentBuffer;
  std::atomic<int> _updateCount;
  std::atomic<int> _nativeFrameCount;
  int _writeBuffer;
  CVPixelBufferRef _renderTarget;
  bool _renderSubmitted;
  uint64_t _nextFrameSequence;
  uint64_t _displayedFrameSequence;
  NSInteger _bufferWidth;
  NSInteger _bufferHeight;
  bool _edrSupported;
  bool _outputHDR;
  NSString *_lastError;
}
@end

@implementation IGLMetalTexture

- (nullable instancetype)initWithHandle:(void *)handle
                         updateCallback:(IGLMetalTextureUpdateCallback)updateCallback
                      frameReadyCallback:(IGLMetalTextureFrameReadyCallback)frameReadyCallback
                    nativeFrameCallback:(IGLMetalTextureNativeFrameCallback)nativeFrameCallback
                    dynamicRangeCallback:(IGLMetalTextureDynamicRangeCallback)dynamicRangeCallback
                                   error:(NSString **)error {
  self = [super init];
  if (!self) {
    return nil;
  }

  _renderContext = nullptr;
  _updateCallback = [updateCallback copy];
  _frameReadyCallback = [frameReadyCallback copy];
  _nativeFrameCallback = [nativeFrameCallback copy];
  _dynamicRangeCallback = [dynamicRangeCallback copy];
  _buffers.fill(nullptr);
  _inFlight.fill(false);
  _currentBuffer.store(-1);
  _updateCount.store(0);
  _nativeFrameCount.store(0);
  _writeBuffer = -1;
  _renderTarget = nullptr;
  _renderSubmitted = false;
  _nextFrameSequence = 0;
  _displayedFrameSequence = 0;
  _bufferWidth = 0;
  _bufferHeight = 0;
  _edrSupported = UIScreen.mainScreen.potentialEDRHeadroom > 1.0;
  _outputHDR = false;

  igl::Result result;
  igl::metal::HWDevice hardware;
  std::unique_ptr<igl::IDevice> device = hardware.createWithSystemDefaultDevice(&result);
    if (!device || !result.isOk()) {
      [self fail:ResultMessage(result, @"IGL Metal device") output:error];
      return nil;
    }
    _device = std::shared_ptr<igl::IDevice>(std::move(device));
    _queue = _device->createCommandQueue({}, &result);
    if (!_queue || !result.isOk()) {
      [self fail:ResultMessage(result, @"IGL command queue") output:error];
      return nil;
    }

    auto sdrStages = igl::ShaderStagesCreator::fromLibraryStringInput(
        *_device, kShader, "vertexMain", "fragmentMain", "PiliPlusYUV", &result);
  if (!sdrStages || !result.isOk()) {
    [self fail:ResultMessage(result, @"IGL SDR Metal shader") output:error];
    return nil;
  }

  igl::RenderPipelineDesc sdrPipelineDesc;
  sdrPipelineDesc.shaderStages = std::move(sdrStages);
  sdrPipelineDesc.targetDesc.colorAttachments.resize(1);
  sdrPipelineDesc.targetDesc.colorAttachments[0].textureFormat =
      igl::TextureFormat::BGRA_UNorm8;
  sdrPipelineDesc.cullMode = igl::CullMode::Disabled;
  _sdrPipeline = _device->createRenderPipeline(sdrPipelineDesc, &result);
  if (!_sdrPipeline || !result.isOk()) {
    [self fail:ResultMessage(result, @"IGL SDR render pipeline") output:error];
    return nil;
  }

  auto hdrStages = igl::ShaderStagesCreator::fromLibraryStringInput(
      *_device, kShader, "vertexMain", "fragmentMain", "PiliPlusYUVHDR", &result);
  if (!hdrStages || !result.isOk()) {
    [self fail:ResultMessage(result, @"IGL HDR Metal shader") output:error];
    return nil;
  }

  igl::RenderPipelineDesc hdrPipelineDesc;
  hdrPipelineDesc.shaderStages = std::move(hdrStages);
  hdrPipelineDesc.targetDesc.colorAttachments.resize(1);
  hdrPipelineDesc.targetDesc.colorAttachments[0].textureFormat =
      igl::TextureFormat::RGBA_F16;
  hdrPipelineDesc.cullMode = igl::CullMode::Disabled;
  _hdrPipeline = _device->createRenderPipeline(hdrPipelineDesc, &result);
  if (!_hdrPipeline || !result.isOk()) {
    [self fail:ResultMessage(result, @"IGL HDR render pipeline") output:error];
    return nil;
  }

  igl::SamplerStateDesc samplerDesc;
  samplerDesc.minFilter = igl::SamplerMinMagFilter::Linear;
  samplerDesc.magFilter = igl::SamplerMinMagFilter::Linear;
  _sampler = _device->createSamplerState(samplerDesc, &result);
  if (!_sampler || !result.isOk()) {
    [self fail:ResultMessage(result, @"IGL sampler") output:error];
    return nil;
  }

  const char *api = MPV_RENDER_API_TYPE_CVPIXELBUFFER;
  mpv_render_param params[] = {
      {MPV_RENDER_PARAM_API_TYPE, const_cast<char *>(api)},
      {MPV_RENDER_PARAM_INVALID, nullptr},
  };
  const int status = mpv_render_context_create(
      &_renderContext, static_cast<mpv_handle *>(handle), params);
  if (status < 0) {
    [self fail:[NSString stringWithFormat:@"mpv cvpixelbuffer context: %d", status]
          output:error];
    return nil;
  }

  mpv_render_context_set_update_callback(
      _renderContext,
      [](void *context) {
        IGLMetalTexture *texture = (__bridge IGLMetalTexture *)context;
        const int count = texture->_updateCount.fetch_add(1) + 1;
        if (count <= 3) {
          NSLog(@"IGLMetalTexture: mpv update callback #%d", count);
        }
        texture->_updateCallback();
      },
      (__bridge void *)self);
  NSLog(@"IGLMetalTexture: initialized renderer=%@",
        _nativeFrameCallback ? @"apple-native-video-layer" : @"igl-metal interop=cvmetaltexture");
  return self;
}

- (void)dealloc {
  if (_renderContext) {
    mpv_render_context_set_update_callback(_renderContext, nullptr, nullptr);
    mpv_render_context_free(_renderContext);
    _renderContext = nullptr;
  }
  std::lock_guard<std::mutex> lock(_bufferMutex);
  for (CVPixelBufferRef& buffer : _buffers) {
    if (buffer) {
      CVPixelBufferRelease(buffer);
      buffer = nullptr;
    }
  }
}

- (CVPixelBufferRef)copyPixelBuffer {
  std::lock_guard<std::mutex> lock(_bufferMutex);
  const int index = _currentBuffer.load();
  if (index < 0 || !_buffers[index]) {
    return nullptr;
  }
  return CVPixelBufferRetain(_buffers[index]);
}

- (BOOL)rebuildBuffersWidth:(NSInteger)width
                     height:(NSInteger)height
                        hdr:(BOOL)hdr
                      error:(NSString **)error {
  if (width <= 0 || height <= 0) {
    return YES;
  }
  if (_bufferWidth == width && _bufferHeight == height && _outputHDR == hdr &&
      _buffers[0]) {
    return YES;
  }

  std::array<CVPixelBufferRef, 3> replacement{};
  std::array<std::shared_ptr<igl::ITexture>, 3> replacementTextures{};
  std::array<std::shared_ptr<igl::IFramebuffer>, 3> replacementFramebuffers{};
  NSDictionary *attributes = @{
    (NSString *)kCVPixelBufferIOSurfacePropertiesKey : @{},
    (NSString *)kCVPixelBufferMetalCompatibilityKey : @YES,
  };
  const OSType pixelFormat =
      hdr ? kCVPixelFormatType_64RGBAHalf : kCVPixelFormatType_32BGRA;
  CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(
      hdr ? kCGColorSpaceExtendedSRGB : kCGColorSpaceSRGB);
  for (CVPixelBufferRef& buffer : replacement) {
    const CVReturn result = CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        pixelFormat,
        (__bridge CFDictionaryRef)attributes,
        &buffer);
    if (result != kCVReturnSuccess) {
      for (CVPixelBufferRef created : replacement) {
        if (created) CVPixelBufferRelease(created);
      }
      [self fail:[NSString stringWithFormat:@"CVPixelBufferCreate: %d", result]
            output:error];
      if (colorSpace) CGColorSpaceRelease(colorSpace);
      return NO;
    }
    if (colorSpace) {
      CVBufferSetAttachment(
          buffer, kCVImageBufferCGColorSpaceKey, colorSpace, kCVAttachmentMode_ShouldPropagate);
    }
  }
  if (colorSpace) CGColorSpaceRelease(colorSpace);

  auto *platform = _device->getPlatformDevice<igl::metal::PlatformDevice>();
  const igl::TextureFormat textureFormat =
      hdr ? igl::TextureFormat::RGBA_F16 : igl::TextureFormat::BGRA_UNorm8;
  for (size_t index = 0; index < replacement.size(); ++index) {
    igl::Result result;
    auto texture = platform->createTextureFromNativePixelBuffer(
        replacement[index], textureFormat, 0, &result);
    if (!texture || !result.isOk()) {
      for (CVPixelBufferRef created : replacement) {
        if (created) CVPixelBufferRelease(created);
      }
      [self fail:ResultMessage(result, @"IGL cache render target") output:error];
      return NO;
    }
    replacementTextures[index] = std::shared_ptr<igl::ITexture>(std::move(texture));

    igl::FramebufferDesc framebufferDesc;
    framebufferDesc.colorAttachments[0].texture = replacementTextures[index];
    replacementFramebuffers[index] = _device->createFramebuffer(framebufferDesc, &result);
    if (!replacementFramebuffers[index] || !result.isOk()) {
      for (CVPixelBufferRef created : replacement) {
        if (created) CVPixelBufferRelease(created);
      }
      [self fail:ResultMessage(result, @"IGL cache framebuffer") output:error];
      return NO;
    }
  }

  std::array<CVPixelBufferRef, 3> previousBuffers{};
  std::array<std::shared_ptr<igl::ITexture>, 3> previousTextures{};
  std::array<std::shared_ptr<igl::IFramebuffer>, 3> previousFramebuffers{};
  const bool modeChanged = _outputHDR != hdr;
  {
    std::lock_guard<std::mutex> lock(_bufferMutex);
    previousBuffers = _buffers;
    previousTextures = std::move(_targetTextures);
    previousFramebuffers = std::move(_framebuffers);
    _buffers = replacement;
    _targetTextures = std::move(replacementTextures);
    _framebuffers = std::move(replacementFramebuffers);
    _inFlight.fill(false);
    _currentBuffer.store(-1);
    _writeBuffer = -1;
    _renderTarget = nullptr;
    _renderSubmitted = false;
    _bufferWidth = width;
    _bufferHeight = height;
    _outputHDR = hdr;
  }
  for (CVPixelBufferRef buffer : previousBuffers) {
    if (buffer) CVPixelBufferRelease(buffer);
  }
  auto *completedPlatform =
      _device->getPlatformDevice<igl::metal::PlatformDevice>();
  completedPlatform->flushNativeTextureCache();
  if (modeChanged) {
    _dynamicRangeCallback(hdr, hdr ? (1000.0 / 203.0) : 1.0);
  }
  NSLog(@"IGLMetalTexture: output: %ldx%ld %@",
        (long)width, (long)height, hdr ? @"RGBA16Float EDR" : @"BGRA8 SDR");
  return YES;
}

- (BOOL)resizeWidth:(NSInteger)width height:(NSInteger)height error:(NSString **)error {
  if (_nativeFrameCallback) {
    _bufferWidth = width;
    _bufferHeight = height;
    return YES;
  }
  return [self rebuildBuffersWidth:width height:height hdr:_outputHDR error:error];
}

- (BOOL)renderWidth:(NSInteger)width height:(NSInteger)height error:(NSString **)error {
  if (!_renderContext || width <= 0 || height <= 0) {
    return NO;
  }

  {
    std::lock_guard<std::mutex> lock(_bufferMutex);
    _writeBuffer = -1;
    _renderTarget = nullptr;
    _renderSubmitted = false;
  }

  mpv_render_cvpixelbuffer_fn callback = [](void *context,
                                             const mpv_render_cvpixelbuffer_frame *frame) {
    return [(__bridge IGLMetalTexture *)context renderNativeFrame:*frame];
  };
  int size[] = {static_cast<int>(width), static_cast<int>(height)};
  mpv_render_param params[] = {
      {MPV_RENDER_PARAM_CVPIXELBUFFER_CALLBACK, &callback},
      {MPV_RENDER_PARAM_CVPIXELBUFFER_CALLBACK_CTX, (__bridge void *)self},
      {MPV_RENDER_PARAM_CVPIXELBUFFER_SIZE, size},
      {MPV_RENDER_PARAM_INVALID, nullptr},
  };
  const int status = mpv_render_context_render(_renderContext, params);
  if (status < 0) {
    [self fail:[NSString stringWithFormat:@"mpv IGL render: %d", status] output:error];
    return NO;
  }

  {
    std::lock_guard<std::mutex> lock(_bufferMutex);
    if (_writeBuffer >= 0 && !_renderSubmitted) {
      _inFlight[_writeBuffer] = false;
    }
    _renderTarget = nullptr;
  }
  return YES;
}

- (int)renderNativeFrame:(const mpv_render_cvpixelbuffer_frame&)frame {
  if (!frame.pixel_buffer) {
    if (_nativeFrameCount.load() == 0) {
      NSLog(@"IGLMetalTexture: render callback without a native frame");
    }
    return 0;
  }

  CVPixelBufferRef source = static_cast<CVPixelBufferRef>(frame.pixel_buffer);
  const OSType format = CVPixelBufferGetPixelFormatType(source);
  const int frameCount = _nativeFrameCount.fetch_add(1) + 1;
  if (frameCount == 1) {
    CFTypeRef transfer = CVBufferGetAttachment(
        source, kCVImageBufferTransferFunctionKey, nullptr);
    CFTypeRef primaries = CVBufferGetAttachment(
        source, kCVImageBufferColorPrimariesKey, nullptr);
    CFTypeRef matrix = CVBufferGetAttachment(
        source, kCVImageBufferYCbCrMatrixKey, nullptr);
    NSLog(@"IGLMetalTexture: first native frame format=%u size=%dx%d planes=%zu",
          format, frame.width, frame.height, CVPixelBufferGetPlaneCount(source));
    NSLog(@"IGLMetalTexture: color transfer=%@ primaries=%@ matrix=%@",
          (__bridge id)transfer ?: @"none",
          (__bridge id)primaries ?: @"none",
          (__bridge id)matrix ?: @"none");
  }
  if (_nativeFrameCallback &&
      _nativeFrameCallback(source, frame.pts, frame.display_width,
                           frame.display_height, frame.rotate)) {
    return 0;
  }
  const bool tenBit = format == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange ||
                      format == kCVPixelFormatType_420YpCbCr10BiPlanarFullRange;
  const bool supported = tenBit ||
      format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ||
      format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
  if (!supported || CVPixelBufferGetPlaneCount(source) != 2) {
    _lastError = [NSString stringWithFormat:@"unsupported CVPixelBuffer: %u", format];
    NSLog(@"IGLMetalTexture: %@; preserving the last valid frame", _lastError);
    return 0;
  }

  ColorParams color = GetColorParams(source, frame, false);
  const bool hdrContent = color.hdrMode != 0;
  const bool hdrOutput = hdrContent && _edrSupported;
  if (![self rebuildBuffersWidth:_bufferWidth
                          height:_bufferHeight
                             hdr:hdrOutput
                           error:nullptr]) {
    return MPV_ERROR_GENERIC;
  }
  color.hdrOutput = hdrOutput;

  {
    std::lock_guard<std::mutex> lock(_bufferMutex);
    const int current = _currentBuffer.load();
    const int start = (_writeBuffer + 1) % static_cast<int>(_buffers.size());
    _writeBuffer = -1;
    for (int offset = 0; offset < static_cast<int>(_buffers.size()); ++offset) {
      const int candidate = (start + offset) % static_cast<int>(_buffers.size());
      if (!_inFlight[candidate] && candidate != current) {
        _writeBuffer = candidate;
        break;
      }
    }
    if (_writeBuffer < 0) {
      return 0;
    }
    _inFlight[_writeBuffer] = true;
    _renderTarget = _buffers[_writeBuffer];
  }

  igl::Result result;
  auto *platform = _device->getPlatformDevice<igl::metal::PlatformDevice>();
  const igl::TextureFormat yFormat = tenBit
      ? igl::TextureFormat::R_UNorm16 : igl::TextureFormat::R_UNorm8;
  const igl::TextureFormat uvFormat = tenBit
      ? igl::TextureFormat::RG_UNorm16 : igl::TextureFormat::RG_UNorm8;
  auto yTexture = platform->createTextureFromNativePixelBuffer(source, yFormat, 0, &result);
  if (!yTexture || !result.isOk()) {
    [self fail:ResultMessage(result, @"IGL import luma texture") output:nullptr];
    return MPV_ERROR_GENERIC;
  }
  auto uvTexture = platform->createTextureFromNativePixelBuffer(source, uvFormat, 1, &result);
  if (!uvTexture || !result.isOk()) {
    [self fail:ResultMessage(result, @"IGL import chroma texture") output:nullptr];
    return MPV_ERROR_GENERIC;
  }
  const int targetIndex = _writeBuffer;
  const auto& framebuffer = _framebuffers[targetIndex];
  if (!framebuffer) {
    [self fail:@"IGL cached framebuffer is unavailable" output:nullptr];
    return MPV_ERROR_GENERIC;
  }

  auto commandBuffer = _queue->createCommandBuffer({}, &result);
  if (!commandBuffer || !result.isOk()) {
    [self fail:ResultMessage(result, @"IGL command buffer") output:nullptr];
    return MPV_ERROR_GENERIC;
  }
  igl::RenderPassDesc renderPass;
  renderPass.colorAttachments.resize(1);
  renderPass.colorAttachments[0].loadAction = igl::LoadAction::Clear;
  renderPass.colorAttachments[0].storeAction = igl::StoreAction::Store;
  renderPass.colorAttachments[0].clearColor = {0.0f, 0.0f, 0.0f, 1.0f};

  auto encoder = commandBuffer->createRenderCommandEncoder(renderPass, framebuffer, &result);
  if (!encoder || !result.isOk()) {
    [self fail:ResultMessage(result, @"IGL render encoder") output:nullptr];
    return MPV_ERROR_GENERIC;
  }
  encoder->bindRenderPipelineState(hdrOutput ? _hdrPipeline : _sdrPipeline);
  encoder->bindTexture(0, igl::BindTarget::kFragment, yTexture.get());
  encoder->bindTexture(1, igl::BindTarget::kFragment, uvTexture.get());
  encoder->bindSamplerState(0, igl::BindTarget::kFragment, _sampler.get());
  encoder->bindBytes(0, igl::BindTarget::kFragment, &color, sizeof(color));
  encoder->draw(3);
  encoder->endEncoding();

  const int completedIndex = _writeBuffer;
  const uint64_t completedSequence = ++_nextFrameSequence;
  CVPixelBufferRef completedTarget = CVPixelBufferRetain(_renderTarget);
  _renderSubmitted = true;
  id<MTLCommandBuffer> metalCommandBuffer =
      static_cast<igl::metal::CommandBuffer&>(*commandBuffer).get();
  [metalCommandBuffer addCompletedHandler:^(id<MTLCommandBuffer> completed) {
    bool frameAccepted = false;
    {
      std::lock_guard<std::mutex> lock(self->_bufferMutex);
      if (self->_buffers[completedIndex] == completedTarget) {
        self->_inFlight[completedIndex] = false;
        if (completed.status != MTLCommandBufferStatusError &&
            completedSequence > self->_displayedFrameSequence) {
          self->_displayedFrameSequence = completedSequence;
          self->_currentBuffer.store(completedIndex);
          frameAccepted = true;
        }
      }
    }
    if (completed.status == MTLCommandBufferStatusError) {
      [self fail:[NSString stringWithFormat:@"Metal command buffer: %@",
                                             completed.error.localizedDescription ?: @"unknown"]
            output:nullptr];
    } else if (frameAccepted) {
      dispatch_async(dispatch_get_main_queue(), self->_frameReadyCallback);
    }
    CVPixelBufferRelease(completedTarget);
  }];
  _queue->submit(*commandBuffer, true);
  return 0;
}

- (NSString *)rendererDescription {
  return _nativeFrameCallback
      ? @"apple-native-video-layer / videotoolbox-cvpixelbuffer"
      : @"igl-metal / cvmetaltexture / flutter-cvpixelbuffer";
}

- (NSString *)lastError {
  return _lastError;
}

- (void)fail:(NSString *)message output:(NSString **)output {
  _lastError = message ?: @"unknown IGL error";
  NSLog(@"IGLMetalTexture: %@", _lastError);
  if (output) {
    *output = _lastError;
  }
}

@end
