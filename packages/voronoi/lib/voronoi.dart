import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'voronoi_bindings_generated.dart' as bindings;

/// [color] — 32-битное значение в формате ARGB, как [Color.value] во Flutter.
class Point {
  final double x;
  final double y;
  final int color;

  Point({required this.x, required this.y, this.color = 0xFFFFFFFF});

  @override
  String toString() => 'Point(x: $x, y: $y, color: 0x${color.toRadixString(16)})';
}

class Voronoi {
  List<int> calculateVoronoiFortune(List<Point> points, int width, int height) {
    if (points.isEmpty) {
      return [];
    }

    return using((Arena arena) {
      final px = arena.allocate<Double>(sizeOf<Double>() * points.length);
      final py = arena.allocate<Double>(sizeOf<Double>() * points.length);
      final pc = arena.allocate<Uint32>(sizeOf<Uint32>() * points.length);
      for (var i = 0; i < points.length; i++) {
        px[i] = points[i].x;
        py[i] = points[i].y;
        pc[i] = points[i].color;
      }

      final result = bindings.calculate_voronoi_fortune(width, height, px, py, pc, points.length);

      if (result == nullptr) {
        return <int>[];
      }

      try {
        final ref = result.ref;
        if (ref.colors != nullptr && ref.size > 0) {
          return ref.colors.asTypedList(ref.size).toList();
        }
      } finally {
        bindings.free_pixels(result);
      }

      return <int>[];
    });
  }
}
