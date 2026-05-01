import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Wraps [degrees] to the range \[0, 360).
double normalizeHueShiftDegrees(double degrees) {
  var wrapped = degrees % 360.0;
  if (wrapped < 0) {
    wrapped += 360.0;
  }
  return wrapped;
}

/// Shifts a color's hue in HSL space while preserving saturation and lightness.
Color shiftColorHueHsl(Color color, double deltaDegrees) {
  final hsl = HSLColor.fromColor(color);
  final wrappedDelta = normalizeHueShiftDegrees(deltaDegrees);
  if (wrappedDelta == 0) {
    return color;
  }

  final nextHue = normalizeHueShiftDegrees(hsl.hue + wrappedDelta);
  return hsl.withHue(nextHue).toColor();
}

/// 4×5 color matrix (row-major) for [ColorFilter.matrix], approximating a hue
/// rotation by [degrees]. Used when drawing the Voronoi raster so the full
/// image shifts uniformly without recomputing the diagram.
List<double> hueRotationColorMatrix(double degrees) {
  final normalized = normalizeHueShiftDegrees(degrees);
  if (normalized == 0) {
    return const <double>[
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
    ];
  }

  final angle = normalized * math.pi / 180.0;
  final cosA = math.cos(angle);
  final sinA = math.sin(angle);
  const lumR = 0.213;
  const lumG = 0.715;
  const lumB = 0.072;

  return <double>[
    lumR + cosA * (1 - lumR) + sinA * (-lumR),
    lumG + cosA * (-lumG) + sinA * (-lumG),
    lumB + cosA * (-lumB) + sinA * (1 - lumB),
    0,
    0,
    lumR + cosA * (-lumR) + sinA * 0.143,
    lumG + cosA * (1 - lumG) + sinA * 0.140,
    lumB + cosA * (-lumB) + sinA * (-0.283),
    0,
    0,
    lumR + cosA * (-lumR) + sinA * (-(1 - lumR)),
    lumG + cosA * (-lumG) + sinA * lumG,
    lumB + cosA * (1 - lumB) + sinA * lumB,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}
