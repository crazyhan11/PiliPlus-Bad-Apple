# libmpv iOS builder overlay

此目录记录生成 PiliPlus Bad Apple iOS device frameworks 的 builder 改动。基线仓库为 `gungun974/melodink-libmpv-darwin-build` 的 `v0.39.0` tag；这里的文件按相同相对路径覆盖基线 checkout。

关键改动：

- `downloads.lock`: FFmpeg 8.0、mpv 0.41 snapshot、libplacebo 7.360.1 与可访问镜像
- `scripts/ffmpeg/meson.build`: 启用 `av1_videotoolbox`
- `patches/mpv-cvpixelbuffer-render-api.patch`: 新增 CVPixelBuffer Render API 与 VideoToolbox device registration
- `scripts/mpv/build.sh`: 构建前应用 mpv patch
- `cross-files`: 适配 Xcode 26 toolchain
- 其余脚本：适配当前依赖版本和构建工具

构建目标：

```bash
make build/intermediate/frameworks_ios-arm64-video-default
```

生成的 `frameworks_ios-arm64-video-default` 用于替换各 XCFramework 的 `ios-arm64` slice。仓库中的 frameworks 归档同时保留旧 simulator slice；真机 IGL/AV1 功能仅验证 arm64 device slice。

Clash 环境可显式设置：

```bash
export http_proxy=http://127.0.0.1:7897
export https_proxy=http://127.0.0.1:7897
```

完整架构和运行验证见 `docs/ios-igl-metal.md`。
