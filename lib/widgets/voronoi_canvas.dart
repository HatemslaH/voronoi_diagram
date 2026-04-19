import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/diagram_point.dart';

class VoronoiCanvas extends StatelessWidget {
  const VoronoiCanvas({
    super.key,
    required this.canvasSize,
    required this.voronoiImage,
    required this.points,
    required this.morphProgress,
  });

  final Size canvasSize;
  final ui.Image voronoiImage;
  final List<DiagramPoint> points;
  final double morphProgress;

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
  });

  final List<DiagramPoint> points;
  final ui.Image voronoiImage;
  final double morphProgress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImage(voronoiImage, Offset.zero, Paint());

    final pointPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    for (final point in points) {
      final center = Offset(point.x, point.y);
      canvas.drawCircle(center, 6, borderPaint);
      canvas.drawCircle(center, 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VoronoiPainter oldDelegate) {
    return oldDelegate.voronoiImage != voronoiImage ||
        oldDelegate.morphProgress != morphProgress ||
        oldDelegate.points.length != points.length;
  }
}
