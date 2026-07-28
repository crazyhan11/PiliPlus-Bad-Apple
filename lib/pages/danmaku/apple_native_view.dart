import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:canvas_danmaku/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppleNativeDanmaku<T> extends StatefulWidget {
  const AppleNativeDanmaku({
    super.key,
    required this.handle,
    required this.createdController,
    required this.option,
    required this.size,
    required this.opacity,
  });

  final int handle;
  final ValueChanged<DanmakuController<T>> createdController;
  final DanmakuOption option;
  final Size size;
  final double opacity;

  @override
  State<AppleNativeDanmaku<T>> createState() => _AppleNativeDanmakuState<T>();
}

class _AppleNativeDanmakuState<T> extends State<AppleNativeDanmaku<T>> {
  static const _useFlutterRaster = bool.fromEnvironment(
    'PILIPLUS_APPLE_FLUTTER_RASTER_DANMAKU',
  );
  static const _channel = MethodChannel(
    'com.alexmercerind/media_kit_video',
  );

  late DanmakuOption _option = widget.option;
  bool _running = true;
  int _generation = 0;
  int _commandEpoch = 0;
  bool _flushScheduled = false;
  final List<Map<String, Object?>> _pendingAdds = [];

  Map<String, Object?> get _baseArguments => {
    'handle': widget.handle.toString(),
  };

  @override
  void initState() {
    super.initState();
    widget.createdController(
      DanmakuController<T>(
        addDanmaku: _addDanmaku,
        updateOption: _updateOption,
        pause: _pause,
        resume: _resume,
        clear: _clear,
        getOption: () => _option,
        isRunning: () => _running,
        findDanmaku: (_) => const [],
        findSingleDanmaku: (_) => null,
        getTrackCount: () => _trackCount,
        scrollDanmaku: const [],
        staticDanmaku: const [],
        specialDanmaku: const [],
      ),
    );
    _configure();
  }

  @override
  void didUpdateWidget(covariant AppleNativeDanmaku<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.handle != widget.handle ||
        oldWidget.size != widget.size ||
        oldWidget.option != widget.option) {
      if (oldWidget.handle != widget.handle) {
        _generation++;
        _commandEpoch++;
        _pendingAdds.clear();
      }
      _option = widget.option;
      _configure();
    }
    if (oldWidget.opacity != widget.opacity) {
      if (widget.opacity <= 0) {
        _generation++;
        _commandEpoch++;
        _pendingAdds.clear();
        unawaited(_invoke('Danmaku.Clear', {'epoch': _commandEpoch}));
      }
      unawaited(
        _invoke('Danmaku.SetOpacity', {'opacity': widget.opacity}),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    DmUtils.devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  }

  int get _trackCount {
    final height = _option.fontSize * _option.lineHeight;
    return height <= 0
        ? 0
        : (widget.size.height * _option.area / height).floor();
  }

  Future<void> _invoke(String method, [Map<String, Object?>? values]) async {
    try {
      await _channel.invokeMethod<void>(method, {
        ..._baseArguments,
        ...?values,
      });
    } on PlatformException {
      // The video output may already have been disposed during route changes.
    }
  }

  void _configure() {
    DmUtils.updateSelfSendPaint(_option.strokeWidth);
    unawaited(
      _invoke('Danmaku.Configure', {
        'width': widget.size.width,
        'height': widget.size.height,
        'fontSize': _option.fontSize,
        'fontWeight': _option.fontWeight,
        'lineHeight': _option.lineHeight,
        'strokeWidth': _option.strokeWidth,
        'area': _option.area,
        'duration': _option.duration,
        'staticDuration': _option.staticDuration,
        'scrollFixedVelocity': _option.scrollFixedVelocity,
        'massiveMode': _option.massiveMode,
        'safeArea': _option.safeArea,
        'hideScroll': _option.hideScroll,
        'hideTop': _option.hideTop,
        'hideBottom': _option.hideBottom,
        'hideSpecial': _option.hideSpecial,
        'opacity': widget.opacity,
      }),
    );
  }

  bool _addDanmaku(DanmakuContentItem<T> content) {
    if (!_running || widget.opacity <= 0 || _option.hideWhat(content.type)) {
      return false;
    }

    if (_useFlutterRaster) {
      unawaited(_renderAndAddDanmaku(content, _generation));
    } else {
      _enqueueAdd(_valuesForContent(content));
    }
    return true;
  }

  void _enqueueAdd(Map<String, Object?> values) {
    _pendingAdds.add(values);
    if (_flushScheduled) return;
    _flushScheduled = true;
    scheduleMicrotask(_flushPendingAdds);
  }

  void _flushPendingAdds() {
    _flushScheduled = false;
    if (!_running || _pendingAdds.isEmpty) {
      _pendingAdds.clear();
      return;
    }
    final items = List<Map<String, Object?>>.of(_pendingAdds);
    _pendingAdds.clear();
    unawaited(
      _invoke('Danmaku.AddBatch', {
        'epoch': _commandEpoch,
        'items': items,
      }),
    );
  }

  Map<String, Object?> _valuesForContent(DanmakuContentItem<T> content) {
    final values = <String, Object?>{
      'text': content.text,
      'color': content.color.toARGB32(),
      'type': content.type.name,
      'count': content.count,
      'selfSend': content.selfSend,
      'isColorful': content.isColorful,
    };
    if (content case final SpecialDanmakuContentItem<T> special) {
      final matrix = special.matrix;
      final double transformA;
      final double transformB;
      final double transformC;
      final double transformD;
      if (matrix == null) {
        final cosZ = math.cos(special.rotateZ);
        final sinZ = math.sin(special.rotateZ);
        transformA = cosZ;
        transformB = sinZ;
        transformC = -sinZ;
        transformD = cosZ;
      } else {
        final cosZ = matrix[5];
        final sinZ = matrix[1];
        final cosY = matrix[10];
        transformA = cosZ * cosY;
        transformB = sinZ;
        transformC = -sinZ * cosY;
        transformD = cosZ;
      }
      values.addAll({
        'fontSize': special.fontSize,
        'durationMs': special.duration,
        'translationDurationMs': special.translationDuration,
        'translationDelayMs': special.translationStartDelay,
        'startX': special.translateXTween.begin,
        'endX': special.translateXTween.end,
        'startY': special.translateYTween.begin,
        'endY': special.translateYTween.end,
        'startAlpha': special.alphaTween?.begin,
        'endAlpha': special.alphaTween?.end,
        'transformA': transformA,
        'transformB': transformB,
        'transformC': transformC,
        'transformD': transformD,
        'easeInCubic': special.easingType == Curves.easeInCubic,
        'hasStroke': special.hasStroke,
      });
    }
    return values;
  }

  Future<void> _renderAndAddDanmaku(
    DanmakuContentItem<T> content,
    int generation,
  ) async {
    final values = _valuesForContent(content);
    late final ui.Image image;
    late final double logicalWidth;
    late final double logicalHeight;
    if (content case final SpecialDanmakuContentItem<T> special) {
      image = DmUtils.recordSpecialDanmakuImg(
        content: special,
        fontWeight: _option.fontWeight,
        strokeWidth: _option.strokeWidth,
      );
      logicalWidth = special.rect.width;
      logicalHeight = special.rect.height;
      values['rasterOffsetX'] = special.rect.left;
      values['rasterOffsetY'] = special.rect.top;
    } else {
      final paragraph = DmUtils.generateParagraph(
        content: content,
        fontSize: _option.fontSize,
        fontWeight: _option.fontWeight,
      );
      logicalWidth =
          (content.selfSend
              ? paragraph.maxIntrinsicWidth + 4
              : paragraph.maxIntrinsicWidth) +
          _option.strokeWidth;
      logicalHeight = paragraph.height + _option.strokeWidth;
      image = DmUtils.recordDanmakuImage(
        contentParagraph: paragraph,
        content: content,
        fontSize: _option.fontSize,
        fontWeight: _option.fontWeight,
        strokeWidth: _option.strokeWidth,
      );
      paragraph.dispose();
    }
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final pixelWidth = image.width;
    final pixelHeight = image.height;
    image.dispose();
    if (byteData == null ||
        !mounted ||
        !_running ||
        generation != _generation) {
      return;
    }
    values.addAll({
      'raster': byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
      'pixelWidth': pixelWidth,
      'pixelHeight': pixelHeight,
      'logicalWidth': logicalWidth,
      'logicalHeight': logicalHeight,
    });
    _enqueueAdd(values);
  }

  void _updateOption(DanmakuOption option) {
    _option = option;
    _configure();
  }

  void _pause() {
    if (!_running) return;
    _running = false;
    _generation++;
    _commandEpoch++;
    _pendingAdds.clear();
    unawaited(_invoke('Danmaku.Pause', {'epoch': _commandEpoch}));
  }

  void _resume() {
    if (_running) return;
    _running = true;
    _commandEpoch++;
    unawaited(_invoke('Danmaku.Resume', {'epoch': _commandEpoch}));
  }

  void _clear() {
    _generation++;
    _commandEpoch++;
    _pendingAdds.clear();
    unawaited(_invoke('Danmaku.Clear', {'epoch': _commandEpoch}));
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
