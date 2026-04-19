import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:voronoi/voronoi.dart' as native;
import 'package:voronoi_diagram/models/diagram_point.dart';
import 'package:voronoi_diagram/models/voronoi_document.dart';
import 'package:voronoi_diagram/services/voronoi_renderer.dart';

void main() {
  group('Voronoi.calculateVoronoiFortune', () {
    final voronoi = native.Voronoi();

    test('returns an empty list for empty input', () {
      final pixels = voronoi.calculateVoronoiFortune(const [], 4, 3);

      expect(pixels, isEmpty);
    });

    test('fills the whole canvas for a single point', () {
      const color = 0xFF336699;

      final pixels = voronoi.calculateVoronoiFortune(
        [native.Point(x: 1, y: 1, color: color)],
        3,
        2,
      );

      expect(pixels, everyElement(_argbToAbgr(color)));
    });

    test('splits two horizontal sites by nearest column', () {
      const left = 0xFFFF0000;
      const right = 0xFF00FF00;

      final pixels = voronoi.calculateVoronoiFortune(
        [
          native.Point(x: 0, y: 1, color: left),
          native.Point(x: 4, y: 1, color: right),
        ],
        5,
        3,
      );

      for (var y = 0; y < 3; y++) {
        expect(_pixelAt(pixels, 5, 0, y), _argbToAbgr(left));
        expect(_pixelAt(pixels, 5, 1, y), _argbToAbgr(left));
        expect(_pixelAt(pixels, 5, 2, y), _argbToAbgr(left));
        expect(_pixelAt(pixels, 5, 3, y), _argbToAbgr(right));
        expect(_pixelAt(pixels, 5, 4, y), _argbToAbgr(right));
      }
    });

    test('splits two vertical sites by nearest row', () {
      const top = 0xFF123456;
      const bottom = 0xFFABCDEF;

      final pixels = voronoi.calculateVoronoiFortune(
        [
          native.Point(x: 1, y: 0, color: top),
          native.Point(x: 1, y: 4, color: bottom),
        ],
        3,
        5,
      );

      for (var x = 0; x < 3; x++) {
        expect(_pixelAt(pixels, 3, x, 0), _argbToAbgr(top));
        expect(_pixelAt(pixels, 3, x, 1), _argbToAbgr(top));
        expect(_pixelAt(pixels, 3, x, 2), _argbToAbgr(top));
        expect(_pixelAt(pixels, 3, x, 3), _argbToAbgr(bottom));
        expect(_pixelAt(pixels, 3, x, 4), _argbToAbgr(bottom));
      }
    });

    test('resolves equidistant pixels in favor of the first point', () {
      const first = 0xFF010203;
      const second = 0xFFAABBCC;

      final pixels = voronoi.calculateVoronoiFortune(
        [
          native.Point(x: 0, y: 0, color: first),
          native.Point(x: 2, y: 0, color: second),
        ],
        3,
        1,
      );

      expect(_pixelAt(pixels, 3, 1, 0), _argbToAbgr(first));
    });

    test('returns pixels in row-major order', () {
      const left = 0xFFFF0000;
      const right = 0xFF0000FF;

      final pixels = voronoi.calculateVoronoiFortune(
        [
          native.Point(x: 0, y: 0, color: left),
          native.Point(x: 2, y: 0, color: right),
        ],
        3,
        2,
      );

      expect(pixels, <int>[
        _argbToAbgr(left),
        _argbToAbgr(left),
        _argbToAbgr(right),
        _argbToAbgr(left),
        _argbToAbgr(left),
        _argbToAbgr(right),
      ]);
    });

    test('uses only source colors in a multi-site diagram', () {
      const colors = <int>[0xFFFF0000, 0xFF00FF00, 0xFF0000FF, 0xFFFFFF00];

      final pixels = voronoi.calculateVoronoiFortune(
        [
          native.Point(x: 0, y: 0, color: colors[0]),
          native.Point(x: 5, y: 0, color: colors[1]),
          native.Point(x: 0, y: 5, color: colors[2]),
          native.Point(x: 5, y: 5, color: colors[3]),
        ],
        6,
        6,
      );

      expect(pixels, hasLength(36));
      expect(
        pixels.toSet(),
        everyElement(isIn(colors.map(_argbToAbgr).toSet())),
      );
    });

    test('preserves alpha when converting ARGB to pixel bytes', () {
      const color = 0x8040A0F0;

      final pixels = voronoi.calculateVoronoiFortune(
        [native.Point(x: 0, y: 0, color: color)],
        1,
        1,
      );

      expect(pixels.single, _argbToAbgr(color));
    });
  });

  group('VoronoiRenderer.render', () {
    test('forwards points and canvas size to the native calculator', () {
      final fakeVoronoi = _CapturingVoronoi(result: const [1, 2, 3, 4]);
      final renderer = VoronoiRenderer(voronoi: fakeVoronoi);
      final document = VoronoiDocument(
        canvasWidth: 2,
        canvasHeight: 2,
        points: const [
          DiagramPoint(x: 1.5, y: 2.5, colorValue: 0xFF112233),
          DiagramPoint(x: 3.5, y: 4.5, colorValue: 0xFF445566),
        ],
      );

      renderer.render(document);

      expect(fakeVoronoi.capturedWidth, 2);
      expect(fakeVoronoi.capturedHeight, 2);
      expect(fakeVoronoi.capturedPoints, hasLength(2));
      expect(fakeVoronoi.capturedPoints[0].x, 1.5);
      expect(fakeVoronoi.capturedPoints[0].y, 2.5);
      expect(fakeVoronoi.capturedPoints[0].color, 0xFF112233);
      expect(fakeVoronoi.capturedPoints[1].x, 3.5);
      expect(fakeVoronoi.capturedPoints[1].y, 4.5);
      expect(fakeVoronoi.capturedPoints[1].color, 0xFF445566);
    });

    test('wraps native pixels in a Uint32List', () {
      final renderer = VoronoiRenderer(
        voronoi: _CapturingVoronoi(result: const [10, 20, 30, 40]),
      );
      final document = VoronoiDocument(
        canvasWidth: 2,
        canvasHeight: 2,
        points: const [DiagramPoint(x: 0, y: 0, colorValue: 0xFFFFFFFF)],
      );

      final pixels = renderer.render(document);

      expect(pixels, isA<Uint32List>());
      expect(pixels, Uint32List.fromList(const [10, 20, 30, 40]));
    });

    test('throws when the native layer returns an unexpected buffer size', () {
      final renderer = VoronoiRenderer(
        voronoi: _CapturingVoronoi(result: const [1, 2, 3]),
      );
      final document = VoronoiDocument(
        canvasWidth: 2,
        canvasHeight: 2,
        points: const [DiagramPoint(x: 0, y: 0, colorValue: 0xFFFFFFFF)],
      );

      expect(
        () => renderer.render(document),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Unexpected Voronoi pixel buffer size.',
          ),
        ),
      );
    });
  });
}

int _argbToAbgr(int argb) {
  final a = (argb >> 24) & 0xFF;
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  return (r << 24) | (g << 16) | (b << 8) | a;
}

int _pixelAt(List<int> pixels, int width, int x, int y) {
  return pixels[(y * width) + x];
}

class _CapturingVoronoi extends native.Voronoi {
  _CapturingVoronoi({required this.result});

  final List<int> result;
  List<native.Point> capturedPoints = const [];
  int? capturedWidth;
  int? capturedHeight;

  @override
  List<int> calculateVoronoiFortune(
    List<native.Point> points,
    int width,
    int height,
  ) {
    capturedPoints = List<native.Point>.from(points);
    capturedWidth = width;
    capturedHeight = height;
    return result;
  }
}
