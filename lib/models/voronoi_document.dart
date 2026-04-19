import 'dart:math';
import 'dart:ui';

import 'diagram_point.dart';

class VoronoiDocument {
  VoronoiDocument({
    required this.canvasWidth,
    required this.canvasHeight,
    required List<DiagramPoint> points,
  }) : points = List<DiagramPoint>.unmodifiable(points) {
    if (canvasWidth <= 0 || canvasHeight <= 0) {
      throw ArgumentError('Canvas size must be positive.');
    }
    if (this.points.isEmpty) {
      throw ArgumentError(
        'A Voronoi document must contain at least one point.',
      );
    }
  }

  static const String format = 'voronoi-diagram';
  static const int version = 1;
  static const int defaultCanvasWidth = 1000;
  static const int defaultCanvasHeight = 1000;
  static const int defaultPointsCount = 1000;
  static const int maxRandomColorValue = 0x62FFFFFF;

  final int canvasWidth;
  final int canvasHeight;
  final List<DiagramPoint> points;

  int get pointsCount => points.length;
  Size get canvasSize => Size(canvasWidth.toDouble(), canvasHeight.toDouble());

  VoronoiDocument copyWith({
    int? canvasWidth,
    int? canvasHeight,
    List<DiagramPoint>? points,
  }) {
    return VoronoiDocument(
      canvasWidth: canvasWidth ?? this.canvasWidth,
      canvasHeight: canvasHeight ?? this.canvasHeight,
      points: points ?? this.points,
    );
  }

  factory VoronoiDocument.random({
    required int pointsCount,
    int canvasWidth = defaultCanvasWidth,
    int canvasHeight = defaultCanvasHeight,
    Random? random,
  }) {
    final rng = random ?? Random();
    return VoronoiDocument(
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      points: List<DiagramPoint>.generate(
        pointsCount,
        (_) => DiagramPoint(
          x: rng.nextDouble() * canvasWidth,
          y: rng.nextDouble() * canvasHeight,
          colorValue: rng.nextInt(maxRandomColorValue),
        ),
      ),
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'format': format,
      'version': version,
      'canvas': <String, Object>{'width': canvasWidth, 'height': canvasHeight},
      'points': points.map((point) => point.toJson()).toList(),
    };
  }

  factory VoronoiDocument.fromJson(Map<String, dynamic> json) {
    if (json['format'] != format) {
      throw const FormatException('Unsupported Voronoi file signature.');
    }

    final versionValue = json['version'];
    if (versionValue is! num || versionValue.toInt() != version) {
      throw const FormatException('Unsupported Voronoi file version.');
    }

    final canvasJson = json['canvas'];
    if (canvasJson is! Map) {
      throw const FormatException('Field "canvas" must be an object.');
    }

    final canvas = canvasJson.cast<String, dynamic>();
    final width = _readPositiveInt(canvas['width'], 'canvas.width');
    final height = _readPositiveInt(canvas['height'], 'canvas.height');

    final pointsJson = json['points'];
    if (pointsJson is! List) {
      throw const FormatException('Field "points" must be an array.');
    }
    if (pointsJson.isEmpty) {
      throw const FormatException('Field "points" must not be empty.');
    }

    final points = pointsJson
        .map<DiagramPoint>((item) {
          if (item is! Map) {
            throw const FormatException('Each point must be an object.');
          }
          return DiagramPoint.fromJson(item.cast<String, dynamic>());
        })
        .toList(growable: false);

    for (final point in points) {
      if (point.x < 0 || point.x > width || point.y < 0 || point.y > height) {
        throw const FormatException(
          'Point coordinates must be inside the canvas.',
        );
      }
    }

    return VoronoiDocument(
      canvasWidth: width,
      canvasHeight: height,
      points: points,
    );
  }

  static int _readPositiveInt(Object? value, String fieldName) {
    if (value is! num) {
      throw FormatException('Field "$fieldName" must be a number.');
    }

    final result = value.toInt();
    if (result <= 0) {
      throw FormatException('Field "$fieldName" must be positive.');
    }

    return result;
  }
}
