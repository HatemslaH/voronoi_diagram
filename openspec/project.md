# Project Context

## Overview

This project is a Flutter application for generating, rendering, and manipulating Voronoi diagrams.
Users can regenerate point sets, adjust point count, import/export diagram files (`.vjson`), and apply a real-time hue shift to the rendered output.

## Tech Stack

- Dart `^3.10.1`
- Flutter (Material 3 UI)
- Dart FFI via local package `packages/voronoi`
- `file_selector` for import/export file dialogs
- JSON serialization with `dart:convert`
- `flutter_test` for unit testing
- `flutter_lints` for static analysis

## Architecture Pattern

The app uses a layered, controller-driven architecture (lightweight MV* style):

- **Presentation layer** (`lib/screens`, `lib/widgets`)
  - Flutter UI widgets and `CustomPainter` rendering.
  - No heavy business logic in widgets.
- **Controller layer** (`lib/controllers/voronoi_controller.dart`)
  - Main state orchestration via `ChangeNotifier`.
  - Handles rendering pipeline, animation state, import/export commands, and UI-facing state.
- **Domain/model layer** (`lib/models`)
  - Typed document model (`VoronoiDocument`) and point model (`DiagramPoint`).
  - Validation and JSON shape enforcement.
- **Service layer** (`lib/services`)
  - `VoronoiRenderer`: bridge from domain model to native Voronoi engine.
  - `VoronoiFileCodec`: `.vjson` encoding/decoding and file extension rules.
- **Utility layer** (`lib/utils`)
  - Pure helper functions (for example hue rotation matrix and hue normalization).

## Repository Conventions

## Language and Style

- Prefer Russian for code, comments, and documentation.
- Keep comments concise and only for non-obvious logic.
- Use Flutter lint defaults from `flutter_lints`.
- Prefer immutable data structures and explicit validation in models.

## UI and State

- Use Flutter Material components with `useMaterial3: true`.
- Keep state in the controller (`ChangeNotifier`) and notify UI with `notifyListeners()`.
- Keep widgets mostly declarative and focused on presentation.
- Follow unidirectional flow: UI event -> controller -> services/models -> UI update.

## Rendering and Performance

- Native Voronoi calculation is done through the FFI package, not in Flutter UI code.
- Reuse/animate raster transitions where possible to avoid abrupt redraws.
- Apply hue shift as a paint-time color filter instead of full diagram recomputation.

## Data and File Format

- Diagram files use `.vjson` extension.
- Serialized documents include:
  - format signature (`voronoi-diagram`)
  - version (`1`)
  - canvas size and points list
- Validate imported data strictly (shape, version, coordinate bounds, color range).

## Testing and Quality

- Add or update tests for domain logic and pure utilities.
- Keep renderer and codec behavior deterministic where practical.
- Ensure new changes pass:
  - `flutter analyze`
  - `flutter test`
