/// Диапазон масштаба визуальных маркеров сайтов (относительно базового 1×).
final class PointVisualScale {
  PointVisualScale._();

  static const double min = 0.25;
  static const double max = 1.5;
  static const double defaultValue = 1.0;

  static double clamp(double value) =>
      value.clamp(min, max).toDouble();
}
