# VGD Cabinet 4.5.1

Stable release of the 4.5 cabinet modeling workflow.

- Adds industrial wood door styles: recessed panel doors, four-edge beveled doors, and rounded-corner wood-frame glass doors.
- Separates frame corner/joinery style (vertical, horizontal, or 45-degree miters) from classic horizontal/vertical subdivision of glass panels. Glass subdivisions apply only to glass doors; Pano and Shaker retain their own panel controls.
- Keeps the dialog compact and shows geometry preview in the SketchUp model viewport.
- Improves frame-member construction by modeling members as separate parts to reduce overlapping and non-manifold geometry.
- Preserves shared component behavior, rail joinery, cabinet library persistence, and existing preset data.

Validation: automated Ruby/WASM, DOM, payload, and package checks are recorded in VALIDATION.json. Native SketchUp 2022 manifold and save/reopen checks were not rerun for this release candidate and remain unverified.