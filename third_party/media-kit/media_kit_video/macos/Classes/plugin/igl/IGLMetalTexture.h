#import <CoreVideo/CoreVideo.h>
#import <FlutterMacOS/FlutterMacOS.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^IGLMetalTextureUpdateCallback)(void);
typedef void (^IGLMetalTextureFrameReadyCallback)(void);
typedef void (^IGLMetalTextureNativeFrameCallback)(CVPixelBufferRef pixelBuffer,
                                                    double presentationTime,
                                                    int displayWidth,
                                                    int displayHeight,
                                                    int rotate);

@interface IGLMetalTexture : NSObject <FlutterTexture>

- (nullable instancetype)initWithHandle:(void *)handle
                         updateCallback:(IGLMetalTextureUpdateCallback)updateCallback
                      frameReadyCallback:(IGLMetalTextureFrameReadyCallback)frameReadyCallback
                    nativeFrameCallback:(IGLMetalTextureNativeFrameCallback _Nullable)nativeFrameCallback
                                   error:(NSString *_Nullable *_Nullable)error;

- (BOOL)resizeWidth:(NSInteger)width
             height:(NSInteger)height
              error:(NSString *_Nullable *_Nullable)error;

- (BOOL)renderWidth:(NSInteger)width
             height:(NSInteger)height
              error:(NSString *_Nullable *_Nullable)error;

@property(nonatomic, readonly) NSString *rendererDescription;
@property(nonatomic, readonly, nullable) NSString *lastError;

@end

NS_ASSUME_NONNULL_END
