#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint media_kit_video.podspec` to validate before publishing.
#

require_relative '../common/darwin/Podspec/media_kit_utils.rb'

Pod::Spec.new do |s|
  # Setup required files
  system("make -C ../common/darwin HEADERS_DESTDIR=\"$(pwd)/Headers\"")

  # Initialize `MediaKitUtils`
  mku = MediaKitUtils.new(MediaKitUtils::Platform::MACOS)

  s.name             = 'media_kit_video'
  s.version          = '0.0.1'
  s.summary          = 'Native implementation for video playback in package:media_kit'
  s.description      = <<-DESC
  Native implementation for video playback in package:media_kit.
                       DESC
  s.homepage         = 'https://github.com/media-kit/media-kit.git'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Hitesh Kumar Saini' => 'saini123hitesh@gmail.com' }

  s.source           = { :path => '.' }
  s.platform         = :osx, '10.9'
  s.swift_version    = '5.0'
  s.dependency         'FlutterMacOS'

  if mku.libs_found
    # Define paths to frameworks dir
    framework_search_paths_macosx = sprintf('$(PROJECT_DIR)/../Flutter/ephemeral/.symlinks/plugins/%s/macos/Frameworks/.symlinks/mpv/macos', mku.libs_package)

    s.source_files        = 'Classes/plugin/**/*.{swift,h,mm}', 'Headers/**/*.h'
    s.public_header_files = 'Classes/plugin/igl/IGLMetalTexture.h', 'Headers/**/*.h'
    s.vendored_libraries  = 'vendor/igl/libIGLLibrary.a', 'vendor/igl/libIGLMetal.a'
    s.frameworks          = 'AVFoundation', 'CoreMedia', 'QuartzCore', 'Metal', 'MetalKit', 'CoreVideo', 'IOSurface'
    s.preserve_paths      = '../../../igl/src/**/*', '../../../igl/third-party/deps/src/{fmt,ldrutils}/**/*'
    s.pod_target_xcconfig = {
      'DEFINES_MODULE'                      => 'YES',
      'GCC_WARN_INHIBIT_ALL_WARNINGS'       => 'YES',
      'GCC_PREPROCESSOR_DEFINITIONS'        => '"$(inherited)" IGL_CMAKE_BUILD=1 GL_SILENCE_DEPRECATION COREVIDEO_SILENCE_GL_DEPRECATION',
      'CLANG_CXX_LANGUAGE_STANDARD'         => 'c++20',
      'HEADER_SEARCH_PATHS'                 => '"$(inherited)" "${PODS_ROOT}/../../third_party/igl/src" "${PODS_ROOT}/../../third_party/igl/third-party/deps/src" "${PODS_ROOT}/../../third_party/igl/third-party/deps/src/fmt/include"',
      'FRAMEWORK_SEARCH_PATHS[sdk=macosx*]' => sprintf('"$(inherited)" "%s"', framework_search_paths_macosx),
      'OTHER_LDFLAGS'                       => '"$(inherited)" -framework Mpv -lc++ -framework AVFoundation -framework CoreMedia -framework QuartzCore -framework Metal -framework MetalKit -framework CoreVideo -framework IOSurface',
    }
  else
    s.source_files        = 'Classes/stub/**/*.swift'
    s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  end
end
