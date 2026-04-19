import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/diagram_point.dart';
import '../models/voronoi_document.dart';
import '../services/voronoi_file_codec.dart';
import '../services/voronoi_renderer.dart';

class VoronoiController extends ChangeNotifier {
  VoronoiController({
    required TickerProvider vsync,
    VoronoiRenderer? renderer,
    VoronoiFileCodec? fileCodec,
  }) : _renderer = renderer ?? VoronoiRenderer(),
       _fileCodec = fileCodec ?? const VoronoiFileCodec(),
       _animationController = AnimationController(
         vsync: vsync,
         duration: diagramAnimationDuration,
       ) {
    _animationController
      ..addListener(_onAnimationTick)
      ..addStatusListener(_onAnimationStatus);
  }

  static const int minPointsCount = 100;
  static const int maxPointsCount = 10000;
  static const Duration diagramAnimationDuration = Duration(milliseconds: 250);

  final VoronoiRenderer _renderer;
  final VoronoiFileCodec _fileCodec;
  final AnimationController _animationController;

  VoronoiDocument _document = VoronoiDocument.random(
    pointsCount: VoronoiDocument.defaultPointsCount,
  );
  int _pointsCountSelection = VoronoiDocument.defaultPointsCount;
  ui.Image? _voronoiImage;
  String _lastBuildTime = '';
  bool _isRendering = false;
  bool _isDisposed = false;

  Uint32List? _rasterSnapshot;
  VoronoiDocument? _documentAnimFrom;
  Uint32List? _pixelAnimFrom;
  Uint32List? _pixelAnimTo;
  Uint32List? _blendScratch;
  double _displayMorphT = 1.0;
  int _decodeSeq = 0;
  int _renderSeq = 0;

  VoronoiDocument get document => _document;
  int get pointsCountSelection => _pointsCountSelection;
  ui.Image? get voronoiImage => _voronoiImage;
  String get lastBuildTime => _lastBuildTime;
  bool get isRendering => _isRendering;
  Size get canvasSize => _document.canvasSize;
  double get morphProgress => _displayMorphT;

  List<DiagramPoint> get displayedPoints {
    final from = _documentAnimFrom;
    if (from != null &&
        from.points.length == _document.points.length &&
        from.points.isNotEmpty) {
      return List<DiagramPoint>.generate(
        _document.points.length,
        (index) => DiagramPoint.lerp(
          from.points[index],
          _document.points[index],
          _displayMorphT,
        ),
        growable: false,
      );
    }

    return _document.points;
  }

  Future<void> initialize() async {
    await _rebuildDiagram();
  }

  void updatePointsCountSelection(int value) {
    final nextValue = value.clamp(minPointsCount, maxPointsCount);
    if (_pointsCountSelection == nextValue) {
      return;
    }

    _pointsCountSelection = nextValue;
    notifyListeners();
  }

  Future<void> regeneratePoints() async {
    final previousDocument = _document;
    _document = VoronoiDocument.random(
      pointsCount: _pointsCountSelection,
      canvasWidth: previousDocument.canvasWidth,
      canvasHeight: previousDocument.canvasHeight,
    );

    await _rebuildDiagram(previousDocument: previousDocument);
  }

  Future<void> commitPointsCount(int value) async {
    final nextValue = value.clamp(minPointsCount, maxPointsCount);
    _pointsCountSelection = nextValue;

    if (nextValue == _document.pointsCount) {
      notifyListeners();
      return;
    }

    final previousDocument = _document;
    _document = VoronoiDocument.random(
      pointsCount: nextValue,
      canvasWidth: previousDocument.canvasWidth,
      canvasHeight: previousDocument.canvasHeight,
    );

    await _rebuildDiagram(previousDocument: previousDocument);
  }

  Future<void> importFromPath(String path) async {
    final source = await File(path).readAsString();
    final importedDocument = _fileCodec.decode(source, filePath: path);
    final previousDocument = _document;

    _document = importedDocument;
    _pointsCountSelection = importedDocument.pointsCount;

    await _rebuildDiagram(previousDocument: previousDocument);
  }

  Future<String> exportToPath(String path) async {
    final exportPath = _fileCodec.normalizeExportPath(path);
    final payload = _fileCodec.encode(_document);
    await File(exportPath).writeAsString(payload);
    return exportPath;
  }

  Future<void> _rebuildDiagram({VoronoiDocument? previousDocument}) async {
    final activeRenderSeq = ++_renderSeq;
    final targetDocument = _document;
    final hasMatchingRasterSize =
        _rasterSnapshot != null &&
        _rasterSnapshot!.length ==
            targetDocument.canvasWidth * targetDocument.canvasHeight;

    if (_animationController.isAnimating &&
        _pixelAnimFrom != null &&
        _pixelAnimTo != null) {
      _blendScratch ??= Uint32List(_pixelAnimFrom!.length);
      _blendRaster(
        _pixelAnimFrom!,
        _pixelAnimTo!,
        _displayMorphT,
        _blendScratch!,
      );
      _rasterSnapshot = Uint32List.fromList(_blendScratch!);
    }

    _animationController
      ..stop()
      ..reset();
    _decodeSeq++;
    _pixelAnimFrom = null;
    _pixelAnimTo = null;
    _displayMorphT = hasMatchingRasterSize ? 0.0 : 1.0;
    _documentAnimFrom = _canAnimatePoints(previousDocument, targetDocument)
        ? previousDocument
        : null;

    if (!hasMatchingRasterSize) {
      _rasterSnapshot = null;
      _documentAnimFrom = null;
      _replaceImage(null);
    }

    _isRendering = true;
    notifyListeners();

    try {
      final timer = Stopwatch()..start();
      final pixelData = _renderer.render(targetDocument);
      timer.stop();

      if (activeRenderSeq != _renderSeq) {
        return;
      }

      final expectedLength =
          targetDocument.canvasWidth * targetDocument.canvasHeight;
      if (pixelData.length != expectedLength) {
        throw StateError('Unexpected Voronoi pixel buffer size.');
      }

      _lastBuildTime = '${timer.elapsedMilliseconds}ms';

      if (_rasterSnapshot == null) {
        final image = await _decodePixels(
          pixelData,
          targetDocument.canvasWidth,
          targetDocument.canvasHeight,
        );

        if (activeRenderSeq != _renderSeq) {
          image.dispose();
          return;
        }

        _replaceImage(image);
        _rasterSnapshot = Uint32List.fromList(pixelData);
        _documentAnimFrom = null;
        _displayMorphT = 1.0;
        _isRendering = false;
        notifyListeners();
        return;
      }

      _pixelAnimFrom = Uint32List.fromList(_rasterSnapshot!);
      _pixelAnimTo = pixelData;
      _displayMorphT = 0.0;
      _isRendering = false;
      notifyListeners();
      unawaited(_animationController.forward(from: 0));
    } catch (_) {
      if (activeRenderSeq == _renderSeq) {
        _isRendering = false;
        notifyListeners();
      }
      rethrow;
    }
  }

  void _onAnimationTick() {
    final from = _pixelAnimFrom;
    final to = _pixelAnimTo;
    if (from == null || to == null || from.length != to.length) {
      return;
    }

    _blendScratch ??= Uint32List(from.length);
    final t = Curves.easeInOutCubic.transform(_animationController.value);
    _blendRaster(from, to, t, _blendScratch!);

    final targetDocument = _document;
    final width = targetDocument.canvasWidth;
    final height = targetDocument.canvasHeight;
    final seq = ++_decodeSeq;
    final bytes = _blendScratch!.buffer.asUint8List(0, width * height * 4);
    final completer = Completer<ui.Image>();

    ui.decodeImageFromPixels(
      bytes,
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );

    completer.future.then((image) {
      if (_isDisposed || seq != _decodeSeq) {
        image.dispose();
        return;
      }

      _displayMorphT = t;
      _replaceImage(image);
      notifyListeners();
    });
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }

    final to = _pixelAnimTo;
    if (to != null) {
      _rasterSnapshot = Uint32List.fromList(to);
    }

    _pixelAnimFrom = null;
    _pixelAnimTo = null;
    _documentAnimFrom = null;
    _displayMorphT = 1.0;
    notifyListeners();
  }

  static bool _canAnimatePoints(
    VoronoiDocument? previousDocument,
    VoronoiDocument nextDocument,
  ) {
    return previousDocument != null &&
        previousDocument.points.length == nextDocument.points.length;
  }

  static Uint32List _blendRaster(
    Uint32List a,
    Uint32List b,
    double t,
    Uint32List out,
  ) {
    final length = a.length;
    for (var index = 0; index < length; index++) {
      final valueA = a[index];
      final valueB = b[index];

      final a0 = valueA & 0xFF;
      final a1 = (valueA >> 8) & 0xFF;
      final a2 = (valueA >> 16) & 0xFF;
      final a3 = (valueA >> 24) & 0xFF;

      final b0 = valueB & 0xFF;
      final b1 = (valueB >> 8) & 0xFF;
      final b2 = (valueB >> 16) & 0xFF;
      final b3 = (valueB >> 24) & 0xFF;

      final c0 = (a0 + (b0 - a0) * t).round().clamp(0, 255);
      final c1 = (a1 + (b1 - a1) * t).round().clamp(0, 255);
      final c2 = (a2 + (b2 - a2) * t).round().clamp(0, 255);
      final c3 = (a3 + (b3 - a3) * t).round().clamp(0, 255);

      out[index] = c0 | (c1 << 8) | (c2 << 16) | (c3 << 24);
    }

    return out;
  }

  Future<ui.Image> _decodePixels(Uint32List pixels, int width, int height) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels.buffer.asUint8List(0, width * height * 4),
      width,
      height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  void _replaceImage(ui.Image? nextImage) {
    if (identical(_voronoiImage, nextImage)) {
      return;
    }

    _voronoiImage?.dispose();
    _voronoiImage = nextImage;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _decodeSeq++;
    _animationController
      ..removeListener(_onAnimationTick)
      ..removeStatusListener(_onAnimationStatus)
      ..dispose();
    _replaceImage(null);
    super.dispose();
  }
}
