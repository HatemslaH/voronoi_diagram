import 'package:flutter_test/flutter_test.dart';
import 'package:voronoi_diagram/utils/point_visual_scale.dart';

void main() {
  group('PointVisualScale.clamp', () {
    test('leaves in-range values unchanged', () {
      expect(PointVisualScale.clamp(1.0), 1.0);
      expect(PointVisualScale.clamp(0.25), 0.25);
      expect(PointVisualScale.clamp(1.5), 1.5);
    });

    test('clamps below minimum', () {
      expect(PointVisualScale.clamp(0.0), PointVisualScale.min);
      expect(PointVisualScale.clamp(-1.0), PointVisualScale.min);
    });

    test('clamps above maximum', () {
      expect(PointVisualScale.clamp(2.0), PointVisualScale.max);
      expect(PointVisualScale.clamp(10.0), PointVisualScale.max);
    });
  });
}
