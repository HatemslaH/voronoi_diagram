import 'dart:ui';

class DiagramPoint {
  const DiagramPoint({
    required this.x,
    required this.y,
    required this.colorValue,
  });

  final double x;
  final double y;
  final int colorValue;

  Color get color => Color(colorValue);

  DiagramPoint copyWith({double? x, double? y, int? colorValue}) {
    return DiagramPoint(
      x: x ?? this.x,
      y: y ?? this.y,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{'x': x, 'y': y, 'color': colorValue};
  }

  factory DiagramPoint.fromJson(Map<String, dynamic> json) {
    final x = _readFiniteDouble(json['x'], 'x');
    final y = _readFiniteDouble(json['y'], 'y');
    final colorValue = _readColorValue(json['color']);

    return DiagramPoint(x: x, y: y, colorValue: colorValue);
  }

  static DiagramPoint lerp(DiagramPoint from, DiagramPoint to, double t) {
    return DiagramPoint(
      x: from.x + (to.x - from.x) * t,
      y: from.y + (to.y - from.y) * t,
      colorValue: Color.lerp(from.color, to.color, t)!.toARGB32(),
    );
  }

  static double _readFiniteDouble(Object? value, String fieldName) {
    if (value is! num) {
      throw FormatException('Field "$fieldName" must be a number.');
    }

    final result = value.toDouble();
    if (!result.isFinite) {
      throw FormatException('Field "$fieldName" must be finite.');
    }

    return result;
  }

  static int _readColorValue(Object? value) {
    if (value is! num) {
      throw const FormatException('Field "color" must be a number.');
    }

    final result = value.toInt();
    if (result < 0 || result > 0xFFFFFFFF) {
      throw const FormatException('Field "color" is out of 32-bit ARGB range.');
    }

    return result;
  }

  @override
  String toString() => 'DiagramPoint(x: $x, y: $y, colorValue: $colorValue)';
}
