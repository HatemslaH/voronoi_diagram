import 'package:flutter/material.dart';

import '../utils/point_visual_scale.dart';

class VoronoiToolbar extends StatelessWidget {
  const VoronoiToolbar({
    super.key,
    required this.lastBuildTime,
    required this.pointsCount,
    required this.sliderValue,
    required this.minPointsCount,
    required this.maxPointsCount,
    required this.isBusy,
    required this.hueShiftDegrees,
    required this.pointVisualScale,
    required this.onRefreshPressed,
    required this.onImportPressed,
    required this.onExportPressed,
    required this.onSliderChanged,
    required this.onSliderChangeEnd,
    required this.onHueShiftChanged,
    required this.onPointVisualScaleChanged,
  });

  final String lastBuildTime;
  final int pointsCount;
  final double sliderValue;
  final int minPointsCount;
  final int maxPointsCount;
  final bool isBusy;
  final double hueShiftDegrees;
  final double pointVisualScale;
  final VoidCallback onRefreshPressed;
  final VoidCallback onImportPressed;
  final VoidCallback onExportPressed;
  final ValueChanged<double> onSliderChanged;
  final ValueChanged<double> onSliderChangeEnd;
  final ValueChanged<double>? onHueShiftChanged;
  final ValueChanged<double>? onPointVisualScaleChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (lastBuildTime.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.timer_outlined, size: 18),
                  label: Text(lastBuildTime),
                ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: isBusy ? null : onRefreshPressed,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: isBusy ? null : onImportPressed,
                icon: const Icon(Icons.file_open),
                label: const Text('Import'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: isBusy ? null : onExportPressed,
                icon: const Icon(Icons.save_alt),
                label: const Text('Export'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: sliderValue,
                  min: minPointsCount.toDouble(),
                  max: maxPointsCount.toDouble(),
                  divisions: maxPointsCount - minPointsCount,
                  onChanged: isBusy ? null : onSliderChanged,
                  onChangeEnd: isBusy ? null : onSliderChangeEnd,
                ),
              ),
              const SizedBox(width: 8),
              Text('Points: $pointsCount'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.palette_outlined, size: 20),
              const SizedBox(width: 8),
              const Text('Оттенок'),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: hueShiftDegrees.clamp(0, 360),
                  min: 0,
                  max: 360,
                  divisions: 360,
                  label: '${hueShiftDegrees.round()}°',
                  onChanged: onHueShiftChanged,
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '${hueShiftDegrees.round()}°',
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.blur_circular_outlined, size: 20),
              const SizedBox(width: 8),
              const Text('Размер точек'),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: PointVisualScale.clamp(pointVisualScale),
                  min: PointVisualScale.min,
                  max: PointVisualScale.max,
                  divisions: 50,
                  label: '${PointVisualScale.clamp(pointVisualScale).toStringAsFixed(2)}×',
                  onChanged: onPointVisualScaleChanged,
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  '${PointVisualScale.clamp(pointVisualScale).toStringAsFixed(2)}×',
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
