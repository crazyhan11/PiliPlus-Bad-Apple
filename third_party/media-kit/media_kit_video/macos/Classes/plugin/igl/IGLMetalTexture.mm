#import "IGLMetalTexture.h"

#import <CoreVideo/CoreVideo.h>
#import <Metal/Metal.h>
#import <simd/simd.h>

#include <array>
#include <atomic>
#include <memory>
#include <mutex>

#include <igl/IGL.h>
#include <igl/metal/CommandBuffer.h>
#include <igl/metal/HWDevice.h>
#include <igl/metal/PlatformDevice.h>
#include <mpv/render.h>

namespace {

CFStringRef const kPiliPlusVideoTransformKey = CFSTR("dev.piliplus.video-transform");

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
  int rotation;
};

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
  const float3 rgb = params.matrix * (float3(y, cbcr) + params.offset);
  return float4(saturate(rgb), 1.0);
}
)";

struct ColorParams {
  simd_float3x3 matrix;
  simd_float3 offset;
  simd_float2 cropOrigin;
  simd_float2 cropSize;
  int32_t rotation;
};

static simd_float3x3 Matrix(float yScale, float rV, float gU, float gV, float bU) {
  return simd_matrix_from_rows(simd_make_float3(yScale, 0.0f, rV), simd_make_float3(yScale, gU, gV),
                               simd_make_float3(yScale, bU, 0.0f));
}

static ColorParams GetColorParams(CVPixelBufferRef buffer,
                                  const mpv_render_cvpixelbuffer_frame& frame) {
  const OSType format = CVPixelBufferGetPixelFormatType(buffer);
  const bool fullRange = format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange ||
                         format == kCVPixelFormatType_420YpCbCr10BiPlanarFullRange;
  CFTypeRef matrixAttachment = CVBufferGetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, nullptr);

  ColorParams result{};
  const float yOffset = fullRange ? 0.0f : -(16.0f / 255.0f);
  const float yScale = fullRange ? 1.0f : (255.0f / 219.0f);
  result.offset = simd_make_float3(yOffset, -0.5f, -0.5f);

  if (matrixAttachment && CFEqual(matrixAttachment, kCVImageBufferYCbCrMatrix_ITU_R_601_4)) {
    result.matrix = fullRange ? Matrix(1.0f, 1.4020f, -0.344136f, -0.714136f, 1.7720f)
                              : Matrix(yScale, 1.596027f, -0.391762f, -0.812968f, 2.017232f);
  } else if (matrixAttachment && CFEqual(matrixAttachment, kCVImageBufferYCbCrMatrix_ITU_R_2020)) {
    result.matrix = fullRange ? Matrix(1.0f, 1.4746f, -0.164553f, -0.571353f, 1.8814f)
                              : Matrix(yScale, 1.678674f, -0.187326f, -0.650424f, 2.141772f);
  } else {
    result.matrix = fullRange ? Matrix(1.0f, 1.5748f, -0.187324f, -0.468124f, 1.8556f)
                              : Matrix(yScale, 1.792741f, -0.213249f, -0.532909f, 2.112402f);
  }

  const float width = static_cast<float>(std::max(frame.width, 1));
  const float height = static_cast<float>(std::max(frame.height, 1));
  const bool hasCrop = frame.crop_x1 > frame.crop_x0 && frame.crop_y1 > frame.crop_y0;
  result.cropOrigin = hasCrop ? simd_make_float2(frame.crop_x0 / width, frame.crop_y0 / height)
                              : simd_make_float2(0.0f, 0.0f);
  result.cropSize = hasCrop ? simd_make_float2((frame.crop_x1 - frame.crop_x0) / width,
                                               (frame.crop_y1 - frame.crop_y0) / height)
                            : simd_make_float2(1.0f, 1.0f);
  result.rotation = static_cast<int32_t>((frame.rotate % 360 + 360) % 360);
  return result;
}

static bool IsDirectYUV(CVPixelBufferRef buffer) {
  const OSType format = CVPixelBufferGetPixelFormatType(buffer);
  if ((format != kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange &&
       format != kCVPixelFormatType_420YpCbCr8BiPlanarFullRange &&
       format != kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange &&
       format != kCVPixelFormatType_420YpCbCr10BiPlanarFullRange) ||
      CVPixelBufferGetPlaneCount(buffer) != 2) {
    return false;
  }

  const bool tenBit = format == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange ||
                      format == kCVPixelFormatType_420YpCbCr10BiPlanarFullRange;
  CFTypeRef transfer = CVBufferGetAttachment(buffer, kCVImageBufferTransferFunctionKey, nullptr);
  CFTypeRef primaries = CVBufferGetAttachment(buffer, kCVImageBufferColorPrimariesKey, nullptr);
  CFTypeRef matrix = CVBufferGetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, nullptr);
  const bool pq = transfer &&
                  CFEqual(transfer, kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ);
  const bool hlg = transfer &&
                   CFEqual(transfer, kCVImageBufferTransferFunction_ITU_R_2100_HLG);
  const bool hdr = pq || hlg;
  if (hdr) {
    return tenBit && primaries &&
           CFEqual(primaries, kCVImageBufferColorPrimaries_ITU_R_2020) && matrix &&
           CFEqual(matrix, kCVImageBufferYCbCrMatrix_ITU_R_2020);
  }
  if (primaries && CFEqual(primaries, kCVImageBufferColorPrimaries_ITU_R_2020)) {
    return false;
  }
  return !matrix || CFEqual(matrix, kCVImageBufferYCbCrMatrix_ITU_R_601_4) ||
         CFEqual(matrix, kCVImageBufferYCbCrMatrix_ITU_R_709_2);
}

static void AttachVideoTransform(CVPixelBufferRef buffer,
                                 const mpv_render_cvpixelbuffer_frame& frame) {
  if (!CVBufferGetAttachment(buffer, kCVImageBufferYCbCrMatrixKey, nullptr)) {
    CVBufferSetAttachment(buffer, kCVImageBufferYCbCrMatrixKey,
                          kCVImageBufferYCbCrMatrix_ITU_R_709_2,
                          kCVAttachmentMode_ShouldNotPropagate);
  }
  const int width = std::max(frame.width, 1);
  const int height = std::max(frame.height, 1);
  const bool validCrop = frame.crop_x0 >= 0 && frame.crop_y0 >= 0 &&
                         frame.crop_x1 > frame.crop_x0 && frame.crop_y1 > frame.crop_y0 &&
                         frame.crop_x1 <= width && frame.crop_y1 <= height;
  const int rotation = (frame.rotate % 360 + 360) % 360;
  NSDictionary* metadata = @{
    @"x0" : @(validCrop ? frame.crop_x0 : 0),
    @"y0" : @(validCrop ? frame.crop_y0 : 0),
    @"x1" : @(validCrop ? frame.crop_x1 : width),
    @"y1" : @(validCrop ? frame.crop_y1 : height),
    @"rotation" : @(rotation),
  };
  CVBufferSetAttachment(buffer, kPiliPlusVideoTransformKey, (__bridge CFDictionaryRef)metadata,
                        kCVAttachmentMode_ShouldNotPropagate);
}

static NSString* ResultMessage(const igl::Result& result, NSString* operation) {
  if (result.isOk()) {
    return nil;
  }
  return [NSString stringWithFormat:@"%@: %s", operation, result.message.c_str()];
}

}  // namespace

@interface IGLMetalTexture () {
  mpv_render_context* _renderContext;
  IGLMetalTextureUpdateCallback _updateCallback;
  IGLMetalTextureFrameReadyCallback _frameReadyCallback;
  IGLMetalTextureNativeFrameCallback _nativeFrameCallback;
  std::shared_ptr<igl::IDevice> _device;
  std::shared_ptr<igl::ICommandQueue> _queue;
  std::shared_ptr<igl::IRenderPipelineState> _pipeline;
  std::shared_ptr<igl::ISamplerState> _sampler;
  std::array<CVPixelBufferRef, 3> _buffers;
  CVPixelBufferRef _directBuffer;
  std::array<std::shared_ptr<igl::ITexture>, 3> _targetTextures;
  std::array<std::shared_ptr<igl::IFramebuffer>, 3> _framebuffers;
  std::mutex _bufferMutex;
  std::atomic<int> _currentBuffer;
  std::atomic<int> _updateCount;
  std::atomic<int> _nativeFrameCount;
  std::atomic<int> _directFrameCount;
  int _writeBuffer;
  CVPixelBufferRef _renderTarget;
  NSString* _lastError;
}
@end

@implementation IGLMetalTexture

- (nullable instancetype)initWithHandle:(void*)handle
                         updateCallback:(IGLMetalTextureUpdateCallback)updateCallback
                     frameReadyCallback:(IGLMetalTextureFrameReadyCallback)frameReadyCallback
                    nativeFrameCallback:(IGLMetalTextureNativeFrameCallback)nativeFrameCallback
                                  error:(NSString**)error {
  self = [super init];
  if (!self) {
    return nil;
  }

  _renderContext = nullptr;
  _updateCallback = [updateCallback copy];
  _frameReadyCallback = [frameReadyCallback copy];
  _nativeFrameCallback = [nativeFrameCallback copy];
  _buffers.fill(nullptr);
  _directBuffer = nullptr;
  _currentBuffer.store(-1);
  _updateCount.store(0);
  _nativeFrameCount.store(0);
  _directFrameCount.store(0);
  _writeBuffer = -1;
  _renderTarget = nullptr;

  if (!_nativeFrameCallback) {
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

    auto stages = igl::ShaderStagesCreator::fromLibraryStringInput(
        *_device, kShader, "vertexMain", "fragmentMain", "PiliPlusYUV", &result);
    if (!stages || !result.isOk()) {
      [self fail:ResultMessage(result, @"IGL Metal shader") output:error];
      return nil;
    }

    igl::RenderPipelineDesc pipelineDesc;
    pipelineDesc.shaderStages = std::move(stages);
    pipelineDesc.targetDesc.colorAttachments.resize(1);
    pipelineDesc.targetDesc.colorAttachments[0].textureFormat = igl::TextureFormat::BGRA_UNorm8;
    pipelineDesc.cullMode = igl::CullMode::Disabled;
    _pipeline = _device->createRenderPipeline(pipelineDesc, &result);
    if (!_pipeline || !result.isOk()) {
      [self fail:ResultMessage(result, @"IGL render pipeline") output:error];
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
  }

  const char* api = MPV_RENDER_API_TYPE_CVPIXELBUFFER;
  mpv_render_param params[] = {
      {MPV_RENDER_PARAM_API_TYPE, const_cast<char*>(api)},
      {MPV_RENDER_PARAM_INVALID, nullptr},
  };
  const int status =
      mpv_render_context_create(&_renderContext, static_cast<mpv_handle*>(handle), params);
  if (status < 0) {
    [self fail:[NSString stringWithFormat:@"mpv cvpixelbuffer context: %d", status] output:error];
    return nil;
  }

  mpv_render_context_set_update_callback(
      _renderContext,
      [](void* context) {
        IGLMetalTexture* texture = (__bridge IGLMetalTexture*)context;
        const int count = texture->_updateCount.fetch_add(1) + 1;
        if (count <= 3) {
          NSLog(@"IGLMetalTexture: mpv update callback #%d", count);
        }
        if (texture->_nativeFrameCallback) {
          texture->_updateCallback();
        } else {
          dispatch_async(dispatch_get_main_queue(), texture->_updateCallback);
        }
      },
      (__bridge void*)self);
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
  if (_directBuffer) {
    CVPixelBufferRelease(_directBuffer);
    _directBuffer = nullptr;
  }
}

- (CVPixelBufferRef)copyPixelBuffer {
  std::lock_guard<std::mutex> lock(_bufferMutex);
  if (_directBuffer) {
    return CVPixelBufferRetain(_directBuffer);
  }
  const int index = _currentBuffer.load();
  if (index < 0 || !_buffers[index]) {
    return nullptr;
  }
  return CVPixelBufferRetain(_buffers[index]);
}

- (BOOL)resizeWidth:(NSInteger)width height:(NSInteger)height error:(NSString**)error {
  if (width <= 0 || height <= 0) {
    return YES;
  }
  if (_nativeFrameCallback) {
    NSLog(@"IGLMetalTexture: native surface resize: %ldx%ld", (long)width, (long)height);
    return YES;
  }

  std::array<CVPixelBufferRef, 3> replacement{};
  std::array<std::shared_ptr<igl::ITexture>, 3> replacementTextures{};
  std::array<std::shared_ptr<igl::IFramebuffer>, 3> replacementFramebuffers{};
  NSDictionary* attributes = @{
    (NSString*)kCVPixelBufferIOSurfacePropertiesKey : @{},
    (NSString*)kCVPixelBufferMetalCompatibilityKey : @YES,
  };
  for (CVPixelBufferRef& buffer : replacement) {
    const CVReturn result =
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
                            (__bridge CFDictionaryRef)attributes, &buffer);
    if (result != kCVReturnSuccess) {
      for (CVPixelBufferRef created : replacement) {
        if (created)
          CVPixelBufferRelease(created);
      }
      [self fail:[NSString stringWithFormat:@"CVPixelBufferCreate: %d", result] output:error];
      return NO;
    }
  }

  auto* platform = _device->getPlatformDevice<igl::metal::PlatformDevice>();
  for (size_t index = 0; index < replacement.size(); ++index) {
    igl::Result result;
    auto texture = platform->createTextureFromNativePixelBuffer(
        replacement[index], igl::TextureFormat::BGRA_UNorm8, 0, &result);
    if (!texture || !result.isOk()) {
      for (CVPixelBufferRef created : replacement) {
        if (created)
          CVPixelBufferRelease(created);
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
        if (created)
          CVPixelBufferRelease(created);
      }
      [self fail:ResultMessage(result, @"IGL cache framebuffer") output:error];
      return NO;
    }
  }

  {
    std::lock_guard<std::mutex> lock(_bufferMutex);
    for (CVPixelBufferRef& buffer : _buffers) {
      if (buffer)
        CVPixelBufferRelease(buffer);
    }
    _buffers = replacement;
    _targetTextures = std::move(replacementTextures);
    _framebuffers = std::move(replacementFramebuffers);
    _currentBuffer.store(-1);
    _writeBuffer = -1;
  }
  NSLog(@"IGLMetalTexture: resize: %ldx%ld", (long)width, (long)height);
  return YES;
}

- (BOOL)renderWidth:(NSInteger)width height:(NSInteger)height error:(NSString**)error {
  if (!_renderContext || width <= 0 || height <= 0) {
    return NO;
  }

  if (!_nativeFrameCallback) {
    std::lock_guard<std::mutex> lock(_bufferMutex);
    _writeBuffer = (_writeBuffer + 1) % static_cast<int>(_buffers.size());
    _renderTarget = _buffers[_writeBuffer];
  }

  mpv_render_cvpixelbuffer_fn callback = [](void* context,
                                            const mpv_render_cvpixelbuffer_frame* frame) {
    return [(__bridge IGLMetalTexture*)context renderNativeFrame:*frame];
  };
  int size[] = {static_cast<int>(width), static_cast<int>(height)};
  mpv_render_param params[] = {
      {MPV_RENDER_PARAM_CVPIXELBUFFER_CALLBACK, &callback},
      {MPV_RENDER_PARAM_CVPIXELBUFFER_CALLBACK_CTX, (__bridge void*)self},
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
  if (_nativeFrameCallback) {
    _nativeFrameCallback(source, frame.pts, frame.display_width, frame.display_height,
                         frame.rotate);
  }
  const OSType format = CVPixelBufferGetPixelFormatType(source);
  const int frameCount = _nativeFrameCount.fetch_add(1) + 1;
  if (frameCount == 1) {
    NSLog(@"IGLMetalTexture: first native frame format=%u size=%dx%d planes=%zu", format,
          frame.width, frame.height, CVPixelBufferGetPlaneCount(source));
    CFTypeRef transfer = CVBufferGetAttachment(source, kCVImageBufferTransferFunctionKey, nullptr);
    CFTypeRef primaries = CVBufferGetAttachment(source, kCVImageBufferColorPrimariesKey, nullptr);
    CFTypeRef matrix = CVBufferGetAttachment(source, kCVImageBufferYCbCrMatrixKey, nullptr);
    NSLog(@"IGLMetalTexture: first frame color transfer=%@ primaries=%@ matrix=%@",
          transfer ? (__bridge id)transfer : @"unspecified",
          primaries ? (__bridge id)primaries : @"unspecified",
          matrix ? (__bridge id)matrix : @"unspecified");
  }
  if (_nativeFrameCallback) {
    return 0;
  }
  if (!_renderTarget) {
    return 0;
  }
  const bool tenBit = format == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange ||
                      format == kCVPixelFormatType_420YpCbCr10BiPlanarFullRange;
  const bool supported = tenBit || format == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ||
                         format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
  if (!supported || CVPixelBufferGetPlaneCount(source) != 2) {
    _lastError = [NSString stringWithFormat:@"unsupported CVPixelBuffer: %u", format];
    return MPV_ERROR_UNSUPPORTED;
  }

  if (IsDirectYUV(source)) {
    AttachVideoTransform(source, frame);
    CVPixelBufferRef retainedSource = CVPixelBufferRetain(source);
    {
      std::lock_guard<std::mutex> lock(_bufferMutex);
      CVPixelBufferRef previous = _directBuffer;
      _directBuffer = retainedSource;
      _currentBuffer.store(-1);
      if (previous) {
        CVPixelBufferRelease(previous);
      }
    }
    const int directCount = _directFrameCount.fetch_add(1) + 1;
    if (directCount == 1) {
      CFTypeRef matrix = CVBufferGetAttachment(source, kCVImageBufferYCbCrMatrixKey, nullptr);
      const NSString* matrixName = matrix ? (__bridge NSString*)matrix : @"unspecified";
      CFTypeRef transfer = CVBufferGetAttachment(source, kCVImageBufferTransferFunctionKey, nullptr);
      const NSString* transferName = transfer ? (__bridge NSString*)transfer : @"unspecified";
      NSLog(@"IGLMetalTexture: direct YUV fast path format=%u matrix=%@ transfer=%@ rotation=%d crop=%d,%d-%d,%d",
            format, matrixName, transferName, frame.rotate, frame.crop_x0, frame.crop_y0,
            frame.crop_x1, frame.crop_y1);
    }
    dispatch_async(dispatch_get_main_queue(), _frameReadyCallback);
    return 0;
  }

  igl::Result result;
  auto* platform = _device->getPlatformDevice<igl::metal::PlatformDevice>();
  const igl::TextureFormat yFormat =
      tenBit ? igl::TextureFormat::R_UNorm16 : igl::TextureFormat::R_UNorm8;
  const igl::TextureFormat uvFormat =
      tenBit ? igl::TextureFormat::RG_UNorm16 : igl::TextureFormat::RG_UNorm8;
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
  encoder->bindRenderPipelineState(_pipeline);
  encoder->bindTexture(0, igl::BindTarget::kFragment, yTexture.get());
  encoder->bindTexture(1, igl::BindTarget::kFragment, uvTexture.get());
  encoder->bindSamplerState(0, igl::BindTarget::kFragment, _sampler.get());
  const ColorParams color = GetColorParams(source, frame);
  encoder->bindBytes(0, igl::BindTarget::kFragment, &color, sizeof(color));
  encoder->draw(3);
  encoder->endEncoding();

  const int completedIndex = _writeBuffer;
  CVPixelBufferRef completedTarget = CVPixelBufferRetain(_renderTarget);
  id<MTLCommandBuffer> metalCommandBuffer =
      static_cast<igl::metal::CommandBuffer&>(*commandBuffer).get();
  [metalCommandBuffer addCompletedHandler:^(id<MTLCommandBuffer> completed) {
    if (completed.status == MTLCommandBufferStatusError) {
      [self fail:[NSString stringWithFormat:@"Metal command buffer: %@",
                                            completed.error.localizedDescription ?: @"unknown"]
          output:nullptr];
    } else {
      bool frameAccepted = false;
      {
        std::lock_guard<std::mutex> lock(self->_bufferMutex);
        if (self->_buffers[completedIndex] == completedTarget) {
          if (self->_directBuffer) {
            CVPixelBufferRelease(self->_directBuffer);
            self->_directBuffer = nullptr;
          }
          self->_currentBuffer.store(completedIndex);
          frameAccepted = true;
        }
      }
      if (frameAccepted) {
        dispatch_async(dispatch_get_main_queue(), self->_frameReadyCallback);
      }
    }
    CVPixelBufferRelease(completedTarget);
  }];
  _queue->submit(*commandBuffer, true);
  return 0;
}

- (NSString*)rendererDescription {
  return _nativeFrameCallback
             ? @"apple-native-video-layer / videotoolbox-cvpixelbuffer"
             : @"yuv-sdr-hdr-direct + igl-metal-fallback / cvmetaltexture / flutter-cvpixelbuffer";
}

- (NSString*)lastError {
  return _lastError;
}

- (void)fail:(NSString*)message output:(NSString**)output {
  _lastError = message ?: @"unknown IGL error";
  NSLog(@"IGLMetalTexture: %@", _lastError);
  if (output) {
    *output = _lastError;
  }
}

@end
