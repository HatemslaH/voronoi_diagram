## ADDED Requirements

### Requirement: User can adjust Voronoi color hue shift
The system SHALL provide a user-facing control to adjust the hue shift applied to Voronoi diagram cell colors.

#### Scenario: Hue control is available
- **WHEN** the user opens the diagram screen
- **THEN** the interface MUST show a hue shift control with a visible current value

### Requirement: Hue shift is applied immediately to rendered colors
The system MUST apply the configured hue shift to all Voronoi cell colors during rendering without requiring diagram regeneration.

#### Scenario: Live preview on hue change
- **WHEN** the user changes the hue shift value
- **THEN** the rendered cell colors MUST update immediately using the new hue shift

### Requirement: Hue shift input is constrained to valid range
The system MUST constrain hue shift to a valid range to prevent invalid color conversion behavior.

#### Scenario: Lower bound normalization
- **WHEN** hue shift value is set below the minimum supported bound
- **THEN** the system MUST clamp or normalize the value to the minimum valid bound before rendering

#### Scenario: Upper bound normalization
- **WHEN** hue shift value is set above the maximum supported bound
- **THEN** the system MUST clamp or normalize the value to the maximum valid bound before rendering
