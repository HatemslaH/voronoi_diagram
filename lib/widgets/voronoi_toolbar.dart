import 'package:flutter/material.dart';

class VoronoiToolbar extends StatelessWidget {
  const VoronoiToolbar({
    super.key,
    required this.lastBuildTime,
    required this.pointsCount,
    required this.sliderValue,
    required this.minPointsCount,
    required this.maxPointsCount,
    required this.isBusy,
    required this.onRefreshPressed,
    required this.onImportPressed,
    required this.onExportPressed,
    required this.onSliderChanged,
    required this.onSliderChangeEnd,
  });

  final String lastBuildTime;
  final int pointsCount;
  final double sliderValue;
  final int minPointsCount;
  final int maxPointsCount;
  final bool isBusy;
  final VoidCallback onRefreshPressed;
  final VoidCallback onImportPressed;
  final VoidCallback onExportPressed;
  final ValueChanged<double> onSliderChanged;
  final ValueChanged<double> onSliderChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (lastBuildTime.isNotEmpty)
            Chip(avatar: const Icon(Icons.timer_outlined, size: 18), label: Text(lastBuildTime)),
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
    );
  }
}
