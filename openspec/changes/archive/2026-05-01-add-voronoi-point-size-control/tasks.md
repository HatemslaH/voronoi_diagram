## 1. Canvas and painting

- [x] 1.1 Add a `pointVisualScale` (or equivalent) parameter to `VoronoiCanvas` / `_VoronoiPainter`, defaulting to `1.0`, and multiply the existing base radii (6 and 4) by the clamped scale when drawing circles.
- [x] 1.2 Extend `shouldRepaint` so a scale change triggers a repaint.

## 2. Screen state and UI

- [x] 2.1 Add session state on `VoronoiScreen` for point visual scale (default `1.0`), clamp to `[0.25, 1.5]` on updates, and pass the value into `VoronoiCanvas`.
- [x] 2.2 Add a Material control (e.g. `Slider`) with min `0.25`, max `1.5`, plus a label showing the current scale, placed alongside existing diagram controls per current layout conventions.

## 3. Verification

- [x] 3.1 Run `flutter analyze` and `flutter test`; add or adjust a small widget/unit test if needed to assert clamping or radius scaling logic.
