import 'dart:typed_data';

import 'package:voronoi/voronoi.dart';

import '../models/voronoi_document.dart';

class VoronoiRenderer {
  VoronoiRenderer({Voronoi? voronoi}) : _voronoi = voronoi ?? Voronoi();

  final Voronoi _voronoi;

  Uint32List render(VoronoiDocument document) {
    final pixels = _voronoi.calculateVoronoiFortune(
      document.points
          .map(
            (point) => Point(x: point.x, y: point.y, color: point.colorValue),
          )
          .toList(growable: false),
      document.canvasWidth,
      document.canvasHeight,
    );

    if (pixels.length != document.canvasWidth * document.canvasHeight) {
      throw StateError('Unexpected Voronoi pixel buffer size.');
    }

    return Uint32List.fromList(pixels);
  }
}
