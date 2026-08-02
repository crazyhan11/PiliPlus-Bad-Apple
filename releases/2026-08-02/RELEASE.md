# PiliPlus Bad Apple 2026-08-02

## Artifacts

- Android: `PiliPlus-Android-arm64-5396-com.example.piliplus.apk`
  - Package: `com.example.piliplus`
  - Architecture: arm64-v8a
  - Version: 2.1.0 (5396)
  - Built with Flutter 3.44.6 + local engine, Direct SurfaceControl rendering
- iOS: `PiliPlus-Bad-Apple-iOS-arm64-PostV5.0.1-iPhone12Mini-VideoLiveFullscreen-BottomInsetFix-Candidate.ipa`
  - Source: local PiliPlus macOS port task, iOS arm64 candidate
  - Unsigned; no provisioning profile
- macOS: `PiliPlus-Bad-Apple-v5.0.1-macOS-arm64.zip`
  - Source: accepted V5.0.1 macOS arm64 build
  - Minimum system: macOS 14.0
  - Local ad-hoc signature; not Developer ID signed or notarized

Checksums are in `SHA256SUMS`.

## Notes

- Android 版在不同机型上可能受系统帧率白名单限制；如遇帧率受限，自行改包名使用会更合适。
