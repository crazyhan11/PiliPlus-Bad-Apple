import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Hosts the native Apple glass material behind Flutter content.
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
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Widget build(BuildContext context) {
    if (!isSupported) {
      return child;
    }
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return _macOSGlassSurface();
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: _nativeGlassView(),
          ),
        ),
        child,
      ],
    );
  }

  Widget _macOSGlassSurface() {
    final radius = BorderRadius.circular(borderRadius);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: style == IOSGlassStyle.regular ? 22 : 30,
          sigmaY: style == IOSGlassStyle.regular ? 22 : 30,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tintColor,
            borderRadius: radius,
            border: Border.all(color: const Color(0x38FFFFFF), width: 0.75),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _nativeGlassView() {
    final creationParams = {
      'borderRadius': borderRadius,
      'style': style.name,
      'tint': tintColor.toARGB32(),
    };
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return AppKitView(
        viewType: _viewType,
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }
    return UiKitView(
      viewType: _viewType,
      hitTestBehavior: PlatformViewHitTestBehavior.transparent,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}

enum IOSGlassStyle { clear, regular }
