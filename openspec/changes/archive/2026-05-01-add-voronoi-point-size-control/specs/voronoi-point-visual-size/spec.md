## ADDED Requirements

### Requirement: User can adjust visual scale of diagram site markers

The system SHALL provide a user-facing control to adjust the visual scale of site markers (points) drawn on top of the Voronoi diagram, relative to the current baseline appearance defined as **1×** scale.

#### Scenario: Point size control is visible

- **WHEN** the user opens the diagram screen
- **THEN** the interface MUST show a control for point visual scale together with a visible indication of the current scale value

### Requirement: Point visual scale is applied during overlay rendering only

The system MUST apply the configured point visual scale only when painting the site marker circles. The scale MUST NOT change stored site coordinates, `.vjson` payload semantics, or native Voronoi computation geometry.

#### Scenario: Live update on scale change

- **WHEN** the user changes the point visual scale
- **THEN** the rendered marker sizes MUST update immediately without rebuilding the Voronoi raster from FFI

### Requirement: Point visual scale is constrained to the product range

The system MUST constrain the effective point visual scale to the inclusive range **0.25×** through **1.5×**, with **1×** as the default when the feature is first shown or reset is applied.

#### Scenario: Values below minimum are clamped

- **WHEN** the point visual scale is set or computed below **0.25×**
- **THEN** the system MUST use **0.25×** for rendering

#### Scenario: Values above maximum are clamped

- **WHEN** the point visual scale is set or computed above **1.5×**
- **THEN** the system MUST use **1.5×** for rendering

#### Scenario: Default matches current baseline

- **WHEN** no user adjustment has been applied for the session default
- **THEN** the rendered markers MUST match the pre-change baseline appearance (equivalent to **1×** scale)
