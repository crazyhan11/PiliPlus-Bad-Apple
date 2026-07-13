# Device slices use mpv 0.41, FFmpeg 8, VideoToolbox AV1 and the custom
# CVPixelBuffer Render API. Simulator slices remain compatible legacy slices.
# SHA-256: d70a2a7b412a972f5cf7263e39155e43ff9863948f7f2a0322936a6fb3c4de56
AV1_XCFRAMEWORKS_ARCHIVE=vendor/libmpv-xcframeworks_v0.41.0-ffmpeg8-av1-vt-cvpixelbuffer_igl_ios-universal-video-default.tar.gz
AV1_XCFRAMEWORKS_STAMP=Frameworks/.igl-metal-av1-videotoolbox-extracted

ifneq ($(wildcard ${AV1_XCFRAMEWORKS_ARCHIVE}),)
all: Frameworks/.symlinks
Frameworks/.symlinks: ${AV1_XCFRAMEWORKS_STAMP}
${AV1_XCFRAMEWORKS_STAMP}: ${AV1_XCFRAMEWORKS_ARCHIVE}
	mkdir -p Frameworks
	rm -rf Frameworks/*.xcframework
	tar -xvf ${AV1_XCFRAMEWORKS_ARCHIVE} --strip-components 1 -C Frameworks
	touch Frameworks/*.xcframework
	touch ${AV1_XCFRAMEWORKS_STAMP}
else
all: Frameworks/*.xcframework Frameworks/.symlinks
Frameworks/.symlinks: Frameworks/*.xcframework

MPV_XCFRAMEWORKS_VERSION=v0.39.0
MPV_XCFRAMEWORKS_SHA256SUM=d7a996b2afad622e9bafb53f1f988235938af33fe162840c9c74a1894bde4bfc

.cache/xcframeworks/libmpv-xcframeworks-${MPV_XCFRAMEWORKS_VERSION}-ios-universal.tar.gz:
	mkdir -p .cache/xcframeworks
	rm -f .cache/xcframeworks/*.tmp .cache/xcframeworks/*-ios-universal.tar.gz
	curl -L \
		https://github.com/gungun974/melodink-libmpv-darwin-build/releases/download/${MPV_XCFRAMEWORKS_VERSION}/libmpv-xcframeworks_${MPV_XCFRAMEWORKS_VERSION}_ios-universal-video-default.tar.gz \
		-o .cache/xcframeworks/libmpv.tar.gz.tmp
	shasum -a 256 -c <<< '${MPV_XCFRAMEWORKS_SHA256SUM}  .cache/xcframeworks/libmpv.tar.gz.tmp'
	mv .cache/xcframeworks/libmpv.tar.gz.tmp .cache/xcframeworks/libmpv-xcframeworks-${MPV_XCFRAMEWORKS_VERSION}-ios-universal.tar.gz
	touch .cache/xcframeworks/libmpv-xcframeworks-${MPV_XCFRAMEWORKS_VERSION}-ios-universal.tar.gz

.cache/xcframeworks/libmpv-xcframeworks-ios-universal.tar.gz: .cache/xcframeworks/libmpv-xcframeworks-${MPV_XCFRAMEWORKS_VERSION}-ios-universal.tar.gz
	rm -f .cache/xcframeworks/libmpv-xcframeworks-ios-universal.tar.gz
	ln -s libmpv-xcframeworks-${MPV_XCFRAMEWORKS_VERSION}-ios-universal.tar.gz .cache/xcframeworks/libmpv-xcframeworks-ios-universal.tar.gz

Frameworks/*.xcframework: .cache/xcframeworks/libmpv-xcframeworks-ios-universal.tar.gz
	mkdir -p Frameworks
	rm -rf Frameworks/*.xcframework
	tar -xvf .cache/xcframeworks/libmpv-xcframeworks-ios-universal.tar.gz --strip-components 1 -C Frameworks
	touch Frameworks/*.xcframework

endif

Frameworks/.symlinks:
	rm -rf Frameworks/.symlinks
	mkdir -p Frameworks/.symlinks/mpv
	sed -i '' 's/\r$$//g' create_framework_symlinks.sh # remove CRLF line terminator added by Flutter packaging (https://github.com/media-kit/media-kit/issues/338)
	sh create_framework_symlinks.sh Frameworks/Mpv.xcframework Frameworks/.symlinks/mpv

.PHONY: clean
clean:
	rm -rf .cache
	rm -f ./Headers/mpv/*.h
	rm -rf ./Frameworks/*.xcframework
	rm -f ${AV1_XCFRAMEWORKS_STAMP}
