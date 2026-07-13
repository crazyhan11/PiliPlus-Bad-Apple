import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Hosts iOS 26's native UIGlassEffect behind Flutter content.
///
/// The platform view is display-only so gestures continue to be handled by
/// the Flutter controls above it.
class IOSGlassSurface extends StatelessWidget {
  const IOSGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = 22,
    this.tintColor = const Color(0x24000000),
    this.style = IOSGlassStyle.clear,
  });

  static const _viewType = 'com.piliplus.badapple/ios-glass-surface';

  final Widget child;
  final double borderRadius;
  final Color tintColor;
  final IOSGlassStyle style;

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    if (!isSupported) {
      return child;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: UiKitView(
              viewType: _viewType,
              hitTestBehavior: PlatformViewHitTestBehavior.transparent,
              creationParams: {
                'borderRadius': borderRadius,
                'style': style.name,
                'tint': tintColor.toARGB32(),
              },
              creationParamsCodec: const StandardMessageCodec(),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

enum IOSGlassStyle { clear, regular }
