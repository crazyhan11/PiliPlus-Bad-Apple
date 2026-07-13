#import <CoreVideo/CoreVideo.h>
#import <Flutter/Flutter.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^IGLMetalTextureUpdateCallback)(void);
typedef void (^IGLMetalTextureFrameReadyCallback)(void);

@interface IGLMetalTexture : NSObject <FlutterTexture>

- (nullable instancetype)initWithHandle:(void *)handle
                         updateCallback:(IGLMetalTextureUpdateCallback)updateCallback
                      frameReadyCallback:(IGLMetalTextureFrameReadyCallback)frameReadyCallback
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
