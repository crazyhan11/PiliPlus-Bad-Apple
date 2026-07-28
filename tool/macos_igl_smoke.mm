#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>

#import "../third_party/media-kit/media_kit_video/macos/Classes/plugin/igl/IGLMetalTexture.h"

#include <client.h>
#include <cstring>

static BOOL WaitForLoadedFile(mpv_handle *handle, NSTimeInterval timeout) {
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
  while ([deadline timeIntervalSinceNow] > 0) {
    mpv_event *event = mpv_wait_event(handle, 0.05);
    if (event->event_id == MPV_EVENT_FILE_LOADED) {
      return YES;
    }
    if (event->event_id == MPV_EVENT_END_FILE ||
        event->event_id == MPV_EVENT_SHUTDOWN) {
      return NO;
    }
  }
  return NO;
}

static void PrintVideoMetadata(mpv_handle *handle) {
  const char *properties[] = {
      "video-params/pixelformat", "video-params/hw-pixelformat",
      "video-params/colormatrix", "video-params/colorlevels",
      "video-params/primaries", "video-params/gamma",
      "video-params/min-luma", "video-params/max-luma",
      "video-params/max-cll", "video-params/max-fall",
      "video-params/max-pq-y", "video-params/avg-pq-y", NULL};
  printf("macOS IGL smoke: video metadata");
  for (int i = 0; properties[i]; i++) {
    char *value = mpv_get_property_string(handle, properties[i]);
    if (value) {
      printf(" %s=%s", properties[i], value);
      mpv_free(value);
    }
  }

  int64_t trackCount = 0;
  if (mpv_get_property(handle, "track-list/count", MPV_FORMAT_INT64, &trackCount) >= 0) {
    for (int64_t i = 0; i < trackCount; i++) {
      NSString *typeProperty = [NSString stringWithFormat:@"track-list/%lld/type", i];
      char *type = mpv_get_property_string(handle, typeProperty.UTF8String);
      if (type && strcmp(type, "video") == 0) {
        NSString *profileProperty =
            [NSString stringWithFormat:@"track-list/%lld/dolby-vision-profile", i];
        NSString *levelProperty =
            [NSString stringWithFormat:@"track-list/%lld/dolby-vision-level", i];
        char *profile = mpv_get_property_string(handle, profileProperty.UTF8String);
        char *level = mpv_get_property_string(handle, levelProperty.UTF8String);
        if (profile)
          printf(" dolby-profile=%s", profile);
        if (level)
          printf(" dolby-level=%s", level);
        mpv_free(profile);
        mpv_free(level);
      }
      mpv_free(type);
    }
  }
  printf("\n");
}

static int RunAudioSmoke(mpv_handle *handle, const char *path) {
  const char *command[] = {"loadfile", path, "replace", NULL};
  if (mpv_command(handle, command) < 0) {
    fprintf(stderr, "macOS audio smoke: loadfile failed\n");
    return 1;
  }

  BOOL loaded = NO;
  BOOL reconfigured = NO;
  double maximumPosition = 0.0;
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:8.0];
  while ([deadline timeIntervalSinceNow] > 0) {
    mpv_event *event = mpv_wait_event(handle, 0.05);
    if (event->event_id == MPV_EVENT_FILE_LOADED)
      loaded = YES;
    if (event->event_id == MPV_EVENT_AUDIO_RECONFIG)
      reconfigured = YES;
    if (event->event_id == MPV_EVENT_END_FILE ||
        event->event_id == MPV_EVENT_SHUTDOWN)
      break;

    double position = 0.0;
    if (mpv_get_property(handle, "time-pos", MPV_FORMAT_DOUBLE, &position) >= 0)
      maximumPosition = MAX(maximumPosition, position);

    if (loaded && reconfigured && maximumPosition >= 0.5)
      break;
  }

  char *audioOutput = NULL;
  int64_t audioId = 0;
  int64_t channelCount = 0;
  int muted = 1;
  double volume = 0.0;
  const BOOL hasAudioOutput =
      mpv_get_property(handle, "current-ao", MPV_FORMAT_STRING, &audioOutput) >= 0 &&
      audioOutput && strcmp(audioOutput, "coreaudio") == 0;
  const BOOL hasAudioId =
      mpv_get_property(handle, "aid", MPV_FORMAT_INT64, &audioId) >= 0 && audioId > 0;
  const BOOL hasChannels =
      mpv_get_property(handle, "audio-params/channel-count", MPV_FORMAT_INT64,
                       &channelCount) >= 0 && channelCount > 0;
  const BOOL isUnmuted =
      mpv_get_property(handle, "mute", MPV_FORMAT_FLAG, &muted) >= 0 && !muted;
  const BOOL hasVolume =
      mpv_get_property(handle, "volume", MPV_FORMAT_DOUBLE, &volume) >= 0 && volume > 0.0;

  printf("macOS audio smoke: loaded=%s reconfigured=%s ao=%s aid=%lld "
         "channels=%lld mute=%d volume=%.1f position=%.3f\n",
         loaded ? "yes" : "no", reconfigured ? "yes" : "no",
         audioOutput ?: "none", audioId, channelCount, muted, volume,
         maximumPosition);
  mpv_free(audioOutput);

  return loaded && reconfigured && hasAudioOutput && hasAudioId && hasChannels &&
                 isUnmuted && hasVolume && maximumPosition >= 0.5
             ? 0
             : 1;
}

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    mpv_handle *handle = mpv_create();
    if (!handle) {
      fprintf(stderr, "macOS IGL smoke: mpv_create failed\n");
      return 1;
    }

    mpv_set_option_string(handle, "terminal", "no");
    mpv_set_option_string(handle, "vo", "libmpv");
    mpv_set_option_string(handle, "hwdec", "videotoolbox");
    if (mpv_initialize(handle) < 0) {
      fprintf(stderr, "macOS IGL smoke: mpv_initialize failed\n");
      mpv_terminate_destroy(handle);
      return 1;
    }

    const BOOL audioMode = argc > 2 && strcmp(argv[2], "audio") == 0;
    if (audioMode) {
      const int result = RunAudioSmoke(handle, argv[1]);
      mpv_terminate_destroy(handle);
      return result;
    }

    __block int updateCount = 0;
    __block int readyCount = 0;
    __block int nativeFrameCount = 0;
    __block OSType nativeFrameFormat = 0;
    __block size_t nativeFrameWidth = 0;
    __block size_t nativeFrameHeight = 0;
    __block int nativeDisplayWidth = 0;
    __block int nativeDisplayHeight = 0;
    __block int nativeRotation = 0;
    NSString *error = nil;
    IGLMetalTexture *texture = [[IGLMetalTexture alloc]
        initWithHandle:handle
        updateCallback:^{ updateCount++; }
        frameReadyCallback:^{ readyCount++; }
        nativeFrameCallback:^(CVPixelBufferRef pixelBuffer, double presentationTime,
                              int displayWidth, int displayHeight, int rotate) {
          (void)presentationTime;
          nativeFrameCount++;
          nativeFrameFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
          nativeFrameWidth = CVPixelBufferGetWidth(pixelBuffer);
          nativeFrameHeight = CVPixelBufferGetHeight(pixelBuffer);
          nativeDisplayWidth = displayWidth;
          nativeDisplayHeight = displayHeight;
          nativeRotation = rotate;
        }
        error:&error];
    if (!texture) {
      fprintf(stderr, "macOS IGL smoke: initialization failed: %s\n",
              error.UTF8String ?: "unknown");
      mpv_terminate_destroy(handle);
      return 1;
    }

    NSString *expected = @"apple-native-video-layer / videotoolbox-cvpixelbuffer";
    if (![texture.rendererDescription isEqualToString:expected]) {
      fprintf(stderr, "macOS IGL smoke: unexpected renderer: %s\n",
              texture.rendererDescription.UTF8String);
      texture = nil;
      mpv_terminate_destroy(handle);
      return 1;
    }

    if (![texture resizeWidth:320 height:180 error:&error]) {
      fprintf(stderr, "macOS IGL smoke: resize failed: %s\n",
              error.UTF8String ?: "unknown");
      texture = nil;
      mpv_terminate_destroy(handle);
      return 1;
    }

    BOOL decodedFrame = NO;
    OSType decodedFormat = 0;
    if (argc > 1) {
      const char *command[] = {"loadfile", argv[1], "replace", NULL};
      if (mpv_command(handle, command) >= 0 && WaitForLoadedFile(handle, 5.0)) {
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
        while ([deadline timeIntervalSinceNow] > 0 && nativeFrameCount == 0) {
          [texture renderWidth:320 height:180 error:&error];
          [NSThread sleepForTimeInterval:0.02];
        }
        decodedFrame = nativeFrameCount > 0;
        decodedFormat = nativeFrameFormat;
        if (decodedFrame) {
          PrintVideoMetadata(handle);
          printf("macOS IGL smoke: frame=%zux%zu display=%dx%d rotation=%d format=%u\n",
                 nativeFrameWidth,
                 nativeFrameHeight,
                 nativeDisplayWidth,
                 nativeDisplayHeight,
                 nativeRotation,
                 (unsigned int)decodedFormat);
        }
      }
    }

    printf("macOS IGL smoke: renderer=%s updates=%d ready=%d native=%d "
           "native_format=%u decoded_frame=%s\n",
           texture.rendererDescription.UTF8String,
           updateCount,
           readyCount,
           nativeFrameCount,
           (unsigned int)nativeFrameFormat,
           decodedFrame ? "yes" : "no");

    const BOOL directYUV =
        decodedFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange ||
        decodedFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange ||
        decodedFormat == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange ||
        decodedFormat == kCVPixelFormatType_420YpCbCr10BiPlanarFullRange;
    const BOOL wrongPath = decodedFrame && !directYUV;
    const BOOL invalidDisplaySize = decodedFrame &&
                                    (nativeDisplayWidth <= 0 || nativeDisplayHeight <= 0);
    const BOOL requiredFrameMissing =
        argc > 1 && (!decodedFrame || wrongPath || invalidDisplaySize);
    if (wrongPath)
      fprintf(stderr, "macOS IGL smoke: native layer received unsupported format\n");
    if (invalidDisplaySize)
      fprintf(stderr, "macOS IGL smoke: native frame has invalid display size\n");
    texture = nil;
    mpv_terminate_destroy(handle);
    return requiredFrameMissing ? 1 : 0;
  }
}
