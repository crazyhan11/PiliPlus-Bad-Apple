# mpv 0.41, FFmpeg 8, VideoToolbox AV1 and the custom CVPixelBuffer Render API.
# SHA-256: ec74c4ffc850393179a33775925ef0013746c37ed085a895347e29ac14586e7d
CUSTOM_XCFRAMEWORKS_ARCHIVE=vendor/libmpv-xcframeworks_v0.41.0-ffmpeg8-av1-vt-cvpixelbuffer_igl_macos-arm64-video-default.tar.gz
CUSTOM_XCFRAMEWORKS_STAMP=Frameworks/.bad-apple-cvpixelbuffer-extracted

ifneq ($(wildcard ${CUSTOM_XCFRAMEWORKS_ARCHIVE}),)
all: Frameworks/.symlinks
Frameworks/.symlinks: ${CUSTOM_XCFRAMEWORKS_STAMP}
${CUSTOM_XCFRAMEWORKS_STAMP}: ${CUSTOM_XCFRAMEWORKS_ARCHIVE}
	mkdir -p Frameworks
	rm -rf Frameworks/*.xcframework
	shasum -a 256 -c <<< 'ec74c4ffc850393179a33775925ef0013746c37ed085a895347e29ac14586e7d  ${CUSTOM_XCFRAMEWORKS_ARCHIVE}'
	tar -xvf ${CUSTOM_XCFRAMEWORKS_ARCHIVE} --strip-components 1 -C Frameworks
	touch Frameworks/*.xcframework
	touch ${CUSTOM_XCFRAMEWORKS_STAMP}
else
all: Frameworks/*.xcframework Frameworks/.symlinks
Frameworks/.symlinks: Frameworks/*.xcframework

MPV_XCFRAMEWORKS_VERSION=v0.6.0
MPV_XCFRAMEWORKS_SHA256SUM=84d2ad98e046e82c6dc34d8547d76c2afeaee89c0f53032773be8985c95536d6

.cache/xcframeworks/libmpv-xcframeworks-${MPV_XCFRAMEWORKS_VERSION}-macos-universal.tar.gz:
	mkdir -p .cache/xcframeworks
	rm -f .cache/xcframeworks/*.tmp .cache/xcframeworks/*-macos-universal.tar.gz
	curl -L \
		https://github.com/media-kit/libmpv-darwin-build/releases/download/${MPV_XCFRAMEWORKS_VERSION}/libmpv-xcframeworks_${MPV_XCFRAMEWORKS_VERSION}_macos-universal-video-default.tar.gz \
		-o .cache/xcframeworks/libmpv.tar.gz.tmp
	shasum -a 256 -c <<< '${MPV_XCFRAMEWORKS_SHA256SUM}  .cache/xcframeworks/libmpv.tar.gz.tmp'
	mv .cache/xcframeworks/libmpv.tar.gz.tmp .cache/xcframeworks/libmpv-xcframeworks-${MPV_XCFRAMEWORKS_VERSION}-macos-universal.tar.gz
	touch .cache/xcframeworks/libmpv-xcframeworks-${MPV_XCFRAMEWORKS_VERSION}-macos-universal.tar.gz

.cache/xcframeworks/libmpv-xcframeworks-macos-universal.tar.gz: .cache/xcframeworks/libmpv-xcframeworks-${MPV_XCFRAMEWORKS_VERSION}-macos-universal.tar.gz
	rm -f .cache/xcframeworks/libmpv-xcframeworks-macos-universal.tar.gz
	ln -s libmpv-xcframeworks-${MPV_XCFRAMEWORKS_VERSION}-macos-universal.tar.gz .cache/xcframeworks/libmpv-xcframeworks-macos-universal.tar.gz

Frameworks/*.xcframework: .cache/xcframeworks/libmpv-xcframeworks-macos-universal.tar.gz
	mkdir -p Frameworks
	rm -rf Frameworks/*.xcframework
	tar -xvf .cache/xcframeworks/libmpv-xcframeworks-macos-universal.tar.gz --strip-components 1 -C Frameworks
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
	rm -f ${CUSTOM_XCFRAMEWORKS_STAMP}
