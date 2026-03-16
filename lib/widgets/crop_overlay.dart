import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A draggable, resizable crop rectangle overlay.
///
/// Renders a semi-transparent scrim outside the crop region, with drag handles
/// on corners and edges. Reports the crop rect in image-pixel coordinates.
class CropOverlay extends StatefulWidget {
  /// Size of the underlying image in pixels.
  final Size imageSize;

  /// Size of the displayed image widget on screen.
  final Size displaySize;

  /// Initial crop rectangle in image-pixel coordinates (null = full image).
  final Rect? initialCrop;

  /// Called whenever the crop rectangle changes (in image-pixel coordinates).
  final ValueChanged<Rect> onCropChanged;

  /// If non-null, constrain the crop rectangle to this aspect ratio (width/height).
  final double? aspectRatio;

  const CropOverlay({
    super.key,
    required this.imageSize,
    required this.displaySize,
    required this.onCropChanged,
    this.initialCrop,
    this.aspectRatio,
  });

  @override
  State<CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<CropOverlay> {
  late Rect _cropRect; // in display coordinates
  _HandleType? _activeHandle;
  Offset? _panStart;
  Rect? _cropStart;

  static const double _handleSize = 20;
  static const double _handleHitArea = 30;
  static const double _minCropSize = 20;

  double get _scaleX => widget.displaySize.width / widget.imageSize.width;
  double get _scaleY => widget.displaySize.height / widget.imageSize.height;

  @override
  void initState() {
    super.initState();
    if (widget.initialCrop != null) {
      _cropRect = Rect.fromLTWH(
        widget.initialCrop!.left * _scaleX,
        widget.initialCrop!.top * _scaleY,
        widget.initialCrop!.width * _scaleX,
        widget.initialCrop!.height * _scaleY,
      );
    } else {
      _cropRect = Offset.zero & widget.displaySize;
    }
  }

  @override
  void didUpdateWidget(CropOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.displaySize != widget.displaySize) {
      final oldScaleX =
          oldWidget.displaySize.width / oldWidget.imageSize.width;
      final oldScaleY =
          oldWidget.displaySize.height / oldWidget.imageSize.height;
      // Re-map crop rect to new display size
      final imgRect = Rect.fromLTWH(
        _cropRect.left / oldScaleX,
        _cropRect.top / oldScaleY,
        _cropRect.width / oldScaleX,
        _cropRect.height / oldScaleY,
      );
      _cropRect = Rect.fromLTWH(
        imgRect.left * _scaleX,
        imgRect.top * _scaleY,
        imgRect.width * _scaleX,
        imgRect.height * _scaleY,
      );
    }
    // When aspect ratio changes, adjust crop to match
    if (oldWidget.aspectRatio != widget.aspectRatio &&
        widget.aspectRatio != null) {
      _applyCropAspectRatio(widget.aspectRatio!);
      _notifyCropChanged();
    }
  }

  /// Resize the current crop rect to match [ratio] (width/height),
  /// keeping the center and fitting within bounds.
  void _applyCropAspectRatio(double ratio) {
    final center = _cropRect.center;
    final bounds = widget.displaySize;

    double w = _cropRect.width;
    double h = w / ratio;
    if (h > bounds.height) {
      h = bounds.height;
      w = h * ratio;
    }
    if (w > bounds.width) {
      w = bounds.width;
      h = w / ratio;
    }

    double l = (center.dx - w / 2).clamp(0.0, bounds.width - w);
    double t = (center.dy - h / 2).clamp(0.0, bounds.height - h);
    _cropRect = Rect.fromLTWH(l, t, w, h);
  }

  Rect get _imagePixelCrop => Rect.fromLTWH(
        (_cropRect.left / _scaleX).roundToDouble(),
        (_cropRect.top / _scaleY).roundToDouble(),
        (_cropRect.width / _scaleX).roundToDouble(),
        (_cropRect.height / _scaleY).roundToDouble(),
      );

  void _notifyCropChanged() {
    widget.onCropChanged(_imagePixelCrop);
  }

  Rect _clampRect(Rect r) {
    double l = r.left.clamp(0.0, widget.displaySize.width - _minCropSize);
    double t = r.top.clamp(0.0, widget.displaySize.height - _minCropSize);
    double w = r.width.clamp(_minCropSize, widget.displaySize.width - l);
    double h = r.height.clamp(_minCropSize, widget.displaySize.height - t);

    // Enforce aspect ratio constraint
    if (widget.aspectRatio != null) {
      final ratio = widget.aspectRatio!;
      final newH = w / ratio;
      if (newH <= widget.displaySize.height - t && newH >= _minCropSize) {
        h = newH;
      } else {
        h = math.min(widget.displaySize.height - t, h);
        w = h * ratio;
      }
      w = w.clamp(_minCropSize, widget.displaySize.width - l);
      h = h.clamp(_minCropSize, widget.displaySize.height - t);
    }

    return Rect.fromLTWH(l, t, w, h);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.displaySize.width,
      height: widget.displaySize.height,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: (_) {
          _activeHandle = null;
          _panStart = null;
          _cropStart = null;
        },
        child: CustomPaint(
          painter: _CropPainter(
            cropRect: _cropRect,
            handleSize: _handleSize,
          ),
          size: widget.displaySize,
        ),
      ),
    );
  }

  _HandleType _hitTest(Offset pos) {
    final r = _cropRect;
    final hs = _handleHitArea;

    // Corners (check first, highest priority)
    if ((pos - r.topLeft).distance < hs) return _HandleType.topLeft;
    if ((pos - r.topRight).distance < hs) return _HandleType.topRight;
    if ((pos - r.bottomLeft).distance < hs) return _HandleType.bottomLeft;
    if ((pos - r.bottomRight).distance < hs) return _HandleType.bottomRight;

    // Edges
    if ((pos.dy - r.top).abs() < hs && pos.dx > r.left && pos.dx < r.right) {
      return _HandleType.top;
    }
    if ((pos.dy - r.bottom).abs() < hs &&
        pos.dx > r.left &&
        pos.dx < r.right) {
      return _HandleType.bottom;
    }
    if ((pos.dx - r.left).abs() < hs && pos.dy > r.top && pos.dy < r.bottom) {
      return _HandleType.left;
    }
    if ((pos.dx - r.right).abs() < hs &&
        pos.dy > r.top &&
        pos.dy < r.bottom) {
      return _HandleType.right;
    }

    // Inside = move
    if (r.contains(pos)) return _HandleType.move;

    return _HandleType.none;
  }

  void _onPanStart(DragStartDetails details) {
    _panStart = details.localPosition;
    _cropStart = _cropRect;
    _activeHandle = _hitTest(details.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_activeHandle == null ||
        _activeHandle == _HandleType.none ||
        _panStart == null ||
        _cropStart == null) {
      return;
    }

    final delta = details.localPosition - _panStart!;
    final cs = _cropStart!;
    final bounds = widget.displaySize;

    setState(() {
      switch (_activeHandle!) {
        case _HandleType.move:
          double nl = (cs.left + delta.dx)
              .clamp(0.0, bounds.width - cs.width);
          double nt = (cs.top + delta.dy)
              .clamp(0.0, bounds.height - cs.height);
          _cropRect = Rect.fromLTWH(nl, nt, cs.width, cs.height);
          break;
        case _HandleType.topLeft:
          _cropRect = _clampRect(Rect.fromLTRB(
            cs.left + delta.dx,
            cs.top + delta.dy,
            cs.right,
            cs.bottom,
          ));
          break;
        case _HandleType.topRight:
          _cropRect = _clampRect(Rect.fromLTRB(
            cs.left,
            cs.top + delta.dy,
            cs.right + delta.dx,
            cs.bottom,
          ));
          break;
        case _HandleType.bottomLeft:
          _cropRect = _clampRect(Rect.fromLTRB(
            cs.left + delta.dx,
            cs.top,
            cs.right,
            cs.bottom + delta.dy,
          ));
          break;
        case _HandleType.bottomRight:
          _cropRect = _clampRect(Rect.fromLTRB(
            cs.left,
            cs.top,
            cs.right + delta.dx,
            cs.bottom + delta.dy,
          ));
          break;
        case _HandleType.top:
          if (widget.aspectRatio != null) {
            final newH = cs.bottom - (cs.top + delta.dy);
            final newW = newH * widget.aspectRatio!;
            final cx = cs.center.dx;
            _cropRect = _clampRect(Rect.fromLTWH(
              cx - newW / 2, cs.bottom - newH, newW, newH));
          } else {
            _cropRect = _clampRect(Rect.fromLTRB(
              cs.left, cs.top + delta.dy, cs.right, cs.bottom));
          }
          break;
        case _HandleType.bottom:
          if (widget.aspectRatio != null) {
            final newH = (cs.bottom + delta.dy) - cs.top;
            final newW = newH * widget.aspectRatio!;
            final cx = cs.center.dx;
            _cropRect = _clampRect(Rect.fromLTWH(
              cx - newW / 2, cs.top, newW, newH));
          } else {
            _cropRect = _clampRect(Rect.fromLTRB(
              cs.left, cs.top, cs.right, cs.bottom + delta.dy));
          }
          break;
        case _HandleType.left:
          if (widget.aspectRatio != null) {
            final newW = cs.right - (cs.left + delta.dx);
            final newH = newW / widget.aspectRatio!;
            final cy = cs.center.dy;
            _cropRect = _clampRect(Rect.fromLTWH(
              cs.right - newW, cy - newH / 2, newW, newH));
          } else {
            _cropRect = _clampRect(Rect.fromLTRB(
              cs.left + delta.dx, cs.top, cs.right, cs.bottom));
          }
          break;
        case _HandleType.right:
          if (widget.aspectRatio != null) {
            final newW = (cs.right + delta.dx) - cs.left;
            final newH = newW / widget.aspectRatio!;
            final cy = cs.center.dy;
            _cropRect = _clampRect(Rect.fromLTWH(
              cs.left, cy - newH / 2, newW, newH));
          } else {
            _cropRect = _clampRect(Rect.fromLTRB(
              cs.left, cs.top, cs.right + delta.dx, cs.bottom));
          }
          break;
        case _HandleType.none:
          break;
      }
    });
    _notifyCropChanged();
  }
}

enum _HandleType {
  none,
  move,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  top,
  bottom,
  left,
  right,
}

class _CropPainter extends CustomPainter {
  final Rect cropRect;
  final double handleSize;

  _CropPainter({required this.cropRect, required this.handleSize});

  @override
  void paint(Canvas canvas, Size size) {
    // Semi-transparent scrim outside crop
    final scrimPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    final fullRect = Offset.zero & size;

    // Draw scrim by painting 4 rects around the crop area
    // Top
    canvas.drawRect(
      Rect.fromLTRB(fullRect.left, fullRect.top, fullRect.right, cropRect.top),
      scrimPaint,
    );
    // Bottom
    canvas.drawRect(
      Rect.fromLTRB(
          fullRect.left, cropRect.bottom, fullRect.right, fullRect.bottom),
      scrimPaint,
    );
    // Left
    canvas.drawRect(
      Rect.fromLTRB(
          fullRect.left, cropRect.top, cropRect.left, cropRect.bottom),
      scrimPaint,
    );
    // Right
    canvas.drawRect(
      Rect.fromLTRB(
          cropRect.right, cropRect.top, fullRect.right, cropRect.bottom),
      scrimPaint,
    );

    // Crop border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(cropRect, borderPaint);

    // Rule of thirds grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (int i = 1; i < 3; i++) {
      final x = cropRect.left + cropRect.width * i / 3;
      final y = cropRect.top + cropRect.height * i / 3;
      canvas.drawLine(
          Offset(x, cropRect.top), Offset(x, cropRect.bottom), gridPaint);
      canvas.drawLine(
          Offset(cropRect.left, y), Offset(cropRect.right, y), gridPaint);
    }

    // Corner handles — L-shaped brackets with dark outline for visibility
    final hs = handleSize;

    // Draw dark shadow first, then white on top
    for (final isOutline in [true, false]) {
      final paint = Paint()
        ..color = isOutline ? Colors.black.withValues(alpha: 0.6) : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = isOutline ? 6 : 4
        ..strokeCap = StrokeCap.square;

      // Top-left
      canvas.drawLine(
          cropRect.topLeft, cropRect.topLeft + Offset(hs, 0), paint);
      canvas.drawLine(
          cropRect.topLeft, cropRect.topLeft + Offset(0, hs), paint);
      // Top-right
      canvas.drawLine(
          cropRect.topRight, cropRect.topRight + Offset(-hs, 0), paint);
      canvas.drawLine(
          cropRect.topRight, cropRect.topRight + Offset(0, hs), paint);
      // Bottom-left
      canvas.drawLine(cropRect.bottomLeft,
          cropRect.bottomLeft + Offset(hs, 0), paint);
      canvas.drawLine(cropRect.bottomLeft,
          cropRect.bottomLeft + Offset(0, -hs), paint);
      // Bottom-right
      canvas.drawLine(cropRect.bottomRight,
          cropRect.bottomRight + Offset(-hs, 0), paint);
      canvas.drawLine(cropRect.bottomRight,
          cropRect.bottomRight + Offset(0, -hs), paint);
    }

    // Edge midpoint handles — short bars with dark outline
    final edgeLen = hs * 0.6;
    final edgePoints = [
      (Offset(cropRect.center.dx, cropRect.top), Offset(edgeLen, 0)),
      (Offset(cropRect.center.dx, cropRect.bottom), Offset(edgeLen, 0)),
      (Offset(cropRect.left, cropRect.center.dy), Offset(0, edgeLen)),
      (Offset(cropRect.right, cropRect.center.dy), Offset(0, edgeLen)),
    ];

    for (final isOutline in [true, false]) {
      final paint = Paint()
        ..color = isOutline
            ? Colors.black.withValues(alpha: 0.5)
            : Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isOutline ? 5 : 3
        ..strokeCap = StrokeCap.round;

      for (final (center, delta) in edgePoints) {
        canvas.drawLine(center - delta, center + delta, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) =>
      cropRect != oldDelegate.cropRect;
}
