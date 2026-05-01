import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../controllers/voronoi_controller.dart';
import '../services/voronoi_file_codec.dart';
import '../widgets/voronoi_canvas.dart';
import '../widgets/voronoi_toolbar.dart';

class VoronoiScreen extends StatefulWidget {
  const VoronoiScreen({super.key});

  @override
  State<VoronoiScreen> createState() => _VoronoiScreenState();
}

class _VoronoiScreenState extends State<VoronoiScreen>
    with TickerProviderStateMixin {
  late final VoronoiController _controller;
  double _hueShiftDegrees = 0;

  @override
  void initState() {
    super.initState();
    _controller = VoronoiController(vsync: this)
      ..addListener(_onControllerUpdate);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onControllerUpdate)
      ..dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await _controller.initialize();
    } catch (error) {
      _showMessage('Не удалось построить диаграмму: $error');
    }
  }

  void _onControllerUpdate() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _onRefreshPressed() async {
    try {
      await _controller.regeneratePoints();
    } catch (error) {
      _showMessage('Не удалось пересчитать диаграмму: $error');
    }
  }

  Future<void> _onImportPressed() async {
    final file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[_diagramFileTypeGroup],
    );

    if (file == null || file.path.isEmpty || !mounted) {
      return;
    }

    try {
      await _controller.importFromPath(file.path);
      _showMessage('Диаграмма импортирована из ${file.name}.');
    } catch (error) {
      _showMessage('Не удалось импортировать диаграмму: $error');
    }
  }

  Future<void> _onExportPressed() async {
    final saveLocation = await getSaveLocation(
      acceptedTypeGroups: <XTypeGroup>[_diagramFileTypeGroup],
      suggestedName: 'diagram${VoronoiFileCodec.fileSuffix}',
    );

    if (saveLocation == null || !mounted) {
      return;
    }

    try {
      final exportedPath = await _controller.exportToPath(saveLocation.path);
      _showMessage('Диаграмма экспортирована в $exportedPath.');
    } catch (error) {
      _showMessage('Не удалось экспортировать диаграмму: $error');
    }
  }

  Future<void> _onPointsCountChangeEnd(double value) async {
    try {
      await _controller.commitPointsCount(value.toInt());
    } catch (error) {
      _showMessage('Не удалось обновить количество точек: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final image = _controller.voronoiImage;

    return Scaffold(
      body: Column(
        children: [
          VoronoiToolbar(
            lastBuildTime: _controller.lastBuildTime,
            pointsCount: _controller.pointsCountSelection,
            sliderValue: _controller.pointsCountSelection.toDouble(),
            minPointsCount: VoronoiController.minPointsCount,
            maxPointsCount: VoronoiController.maxPointsCount,
            isBusy: _controller.isRendering,
            hueShiftDegrees: _hueShiftDegrees,
            onRefreshPressed: () => unawaited(_onRefreshPressed()),
            onImportPressed: () => unawaited(_onImportPressed()),
            onExportPressed: () => unawaited(_onExportPressed()),
            onSliderChanged: (value) =>
                _controller.updatePointsCountSelection(value.toInt()),
            onSliderChangeEnd: (value) =>
                unawaited(_onPointsCountChangeEnd(value)),
            onHueShiftChanged: image == null
                ? null
                : (value) => setState(() {
                    _hueShiftDegrees = value.clamp(0.0, 360.0);
                  }),
          ),
          Expanded(
            child: image == null
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: VoronoiCanvas(
                        canvasSize: _controller.canvasSize,
                        voronoiImage: image,
                        points: _controller.displayedPoints,
                        morphProgress: _controller.morphProgress,
                        hueShiftDegrees: _hueShiftDegrees,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

const XTypeGroup _diagramFileTypeGroup = XTypeGroup(
  label: 'Voronoi diagram (*.vjson)',
  extensions: <String>[VoronoiFileCodec.fileExtension],
);
