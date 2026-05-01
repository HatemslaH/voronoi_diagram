import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voronoi_diagram/utils/hue_shift.dart';

void main() {
  group('normalizeHueShiftDegrees', () {
    test('wraps negative values into [0, 360)', () {
      expect(normalizeHueShiftDegrees(-90), closeTo(270, 1e-9));
    });

    test('wraps values above 360', () {
      expect(normalizeHueShiftDegrees(450), closeTo(90, 1e-9));
    });

    test('maps full turn to zero', () {
      expect(normalizeHueShiftDegrees(360), closeTo(0, 1e-9));
    });
  });

  group('shiftColorHueHsl', () {
    test('applies delta to hue in HSL space', () {
      const red = Color(0xFFFF0000);
      final shifted = shiftColorHueHsl(red, 120);
      final hsl = HSLColor.fromColor(shifted);

      expect(hsl.hue, closeTo(120.0, 1.0));
    });

    test('full rotation leaves color unchanged', () {
      const red = Color(0xFFFF0000);
      final shifted = shiftColorHueHsl(red, 360);

      expect(shifted.toARGB32(), red.toARGB32());
    });
  });

  group('hueRotationColorMatrix', () {
    test('identity matrix at zero degrees', () {
      expect(
        hueRotationColorMatrix(0),
        equals(const <double>[
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
      );
    });

    test('full turn matches identity matrix', () {
      expect(hueRotationColorMatrix(360), hueRotationColorMatrix(0));
    });
  });
}
