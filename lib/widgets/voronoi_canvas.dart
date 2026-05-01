import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/diagram_point.dart';
import '../utils/hue_shift.dart';
import '../utils/point_visual_scale.dart';

class VoronoiCanvas extends StatelessWidget {
  const VoronoiCanvas({
    super.key,
    required this.canvasSize,
    required this.voronoiImage,
    required this.points,
    required this.morphProgress,
    required this.hueShiftDegrees,
    this.pointVisualScale = PointVisualScale.defaultValue,
  });

  final Size canvasSize;
  final ui.Image voronoiImage;
  final List<DiagramPoint> points;
  final double morphProgress;
  final double hueShiftDegrees;
  final double pointVisualScale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: canvasSize.width,
      height: canvasSize.height,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _VoronoiPainter(
            points: points,
            voronoiImage: voronoiImage,
            morphProgress: morphProgress,
            hueShiftDegrees: hueShiftDegrees,
            pointVisualScale: pointVisualScale,
          ),
        ),
      ),
    );
  }
}

class _VoronoiPainter extends CustomPainter {
  _VoronoiPainter({
    required this.points,
    required this.voronoiImage,
    required this.morphProgress,
    required this.hueShiftDegrees,
    required this.pointVisualScale,
  });

  final List<DiagramPoint> points;
  final ui.Image voronoiImage;
  final double morphProgress;
  final double hueShiftDegrees;
  final double pointVisualScale;

  @override
  void paint(Canvas canvas, Size size) {
    final imagePaint = Paint();
    final normalizedHue = normalizeHueShiftDegrees(hueShiftDegrees);
    if (normalizedHue != 0) {
      imagePaint.colorFilter = ColorFilter.matrix(
        hueRotationColorMatrix(normalizedHue),
      );
    }
    canvas.drawImage(voronoiImage, Offset.zero, imagePaint);

    final pointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final scale = PointVisualScale.clamp(pointVisualScale);
    for (final point in points) {
      final center = Offset(point.x, point.y);
      canvas.drawCircle(center, 6 * scale, borderPaint);
      canvas.drawCircle(center, 4 * scale, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VoronoiPainter oldDelegate) {
    return oldDelegate.voronoiImage != voronoiImage ||
        oldDelegate.morphProgress != morphProgress ||
        oldDelegate.hueShiftDegrees != hueShiftDegrees ||
        oldDelegate.pointVisualScale != pointVisualScale ||
        oldDelegate.points.length != points.length;
  }
}
