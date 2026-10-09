# VGD Reference — handoff

Current source version: `1.0.0-beta.6`. Runtime source is `runtime/`; packaged files are generated with `dev/package.cjs`.

## Architecture

- `core/`: session state, reference items, and store.
- `viewport/`: overlay drawing, cached textures, coordinate adapter, and hit testing.
- `tools/`: edit state machine and crop controller.
- `import/`: image validation, Windows clipboard reader, and session temp files.
- `ui/`: compact HtmlDialog manager; Ruby state remains the source of truth.
- `observers/`: per-model overlay lifecycle.

No model entities or attribute dictionaries are used. Source image paths are read only, except clipboard and dropped image bytes which are written to a private temp directory and removed when their item/model/session ends.

## Spike status

1. Overlay: the live eight-panel probe in SketchUp 24.0.484, new graphics engine, identified the rendering cause. Vector3d UVs render a flat color; numeric Array UVs display all four source colors. Beta.5 changes the production overlay and original spike to numeric Array UVs. After loading `dev/apply_render_fix.rb` and showing the references, the user confirmed that the actual reference images display fully. See `RELEASE_NOTES_v1.0.0-beta.5.md` for the observed matrix.
2. Alpha: viewport color alpha is used for slider preview; a cached RGBA ImageRep is built on slider release. Committed opacity now draws without a second color-alpha multiplier. Verify preview and committed blending in SketchUp 2024.
3. Texture drawing uses numeric arrays for UVs, preserving the existing top-left screen coordinates and flipped V orientation. Real decoded source data, texture IDs, cache View identity, and UV ranges were valid in beta.4. Changing face style to Shaded with Textures did not resolve the bug.
4. Interaction: user reports the plugin controls are working in SketchUp 2024. Beta.5 removes unsupported View#valid? calls from redraw/cancel/lifecycle paths. The Ruby regression suite now uses a view fake with invalidate but no valid? to prevent this error returning.
5. RMB quick move: prototype is disabled by default. Test separately and leave disabled if it triggers a context menu or conflicts with SketchUp.
6. Clipboard: Windows PNG, CF_DIBV5, and CF_DIB readers are implemented; verify against Chrome, Edge, Snipping Tool, Photos, and Photoshop.
7. DPI: adapter handles pre-2025 physical coordinates and 2025+ logical coordinates. Verify 100%, 125%, 150%, 175%, and 200%, including moving SketchUp to another monitor.

## Current limitations

- Beta.6 icon/theme verification uses headless Edge and Ruby fixtures; it has not been reinstalled and checked in the native SketchUp toolbar/HtmlDialog. The native image-rendering confirmation remains the beta.5 evidence above.

- V1 is Windows-first. Clipboard Fiddle integration is Windows-only.
- New images begin locked and passive. Selecting one in the manager temporarily unlocks it for editing; exiting the tool restores its prior locked state.
- Crop controls adjust the four crop edges. The frame is refit to the crop aspect ratio on commit.
- On Escape, Edit returns to SketchUp's native tool; Undo/reselect cancels only an in-progress drag or crop and leaves Edit in a clean idle state.
- The UI's Explorer drop uses the HtmlDialog browser File API and chunks image bytes to Ruby. Verify on the exact Chromium versions shipped with supported SketchUp releases.
- Dropped images are capped at 20 MiB to keep HtmlDialog memory and callback traffic bounded.
- RMB quick move remains disabled until it passes the context-menu prototype in SketchUp.
- The UV representation bug was reproduced in a live native renderer, not established by the mock UI tests. The regression fixture enforces numeric UV arrays and full/cropped UV orientation; it cannot validate GPU rendering on other SketchUp builds or hardware.
- `View#write_image` omits Ruby overlays on the tested setup. The diagnostic exporter checks a magenta marker and reports an omitted overlay as inconclusive. Use a real screenshot for visual evidence.
- Computer Use capture repeatedly returned `FrameArrived timed out`. User-run Ruby Console scripts and supplied screenshots provided the native evidence. `dev/apply_render_fix.rb` reloads only the changed classes/modules in RAM and preserves current references.

## Beta.6 — VGD icon system and theme

- Followed workspace `shared/VGD_ICON_SYSTEM_RULES.md` and `shared/VGD_ICON_SYSTEM_PREVIEW.html`. Reference's own glyph is a pinned photo, with no decorative background, a 24-unit viewBox, 1.8-unit rounded strokes, and identical geometry for both themes.
- Light `assets/toolbar/vgd_reference.svg`: outline `#292B2D`; dark `vgd_reference_dark.svg`: outline `#F1EDE6`; both use accent `#A67C58`. `assets/toolbar/icon_manifest.json` records version, paths, palette, preview sizes, and theme selection policy.
- `dev/build_icons.cjs` is the source for all three paths. `dev/icon_preview.html` loads runtime SVGs directly in gallery, toolbar, and 16/24/32 rows. See `dev/ICON_DESIGN.md` for the design and integration details.
- `ui/icons.rb` selects the native Command icon from the manifest. Default light fits the tested SketchUp 2024 toolbar. The header settings button opens a light/dark native-icon selector; its Ruby callback persists `VGD.Reference / ToolbarTheme`, updates the existing Command's small/large paths, and restores the saved preference at startup. Manager CSS remains independent. Do not infer native toolbar color from Windows/HtmlDialog theme; no undocumented SketchUp theme API is used.
- Manager CSS follows `prefers-color-scheme`, with exact VGD icon colors in both themes. Header uses the same SVG pair through picture sources. Existing Vietnamese copy, callbacks and workflows are preserved; row action symbols became SVGs and remain visible.
- Passed SVG structure, same-geometry, raster transparency and pin visibility checks at 16/24/32. Visually reviewed light/dark renders. Primary outline contrast on the sample toolbar is 9.87:1 / 12.18:1.
- Passed both manager themes at 310×455 and 280×340, empty states, settings open/close/save/restore, all existing action callbacks and opacity. Compiled 21 runtime Ruby files; icon selection, compatibility guards and existing render/core/cache fixtures passed.
- `dev/package.cjs` rebuilds icon assets, verifies loader/constants/manifest version agreement, and compares decompressed RBZ/source contents byte-for-byte with source. SHA-256 sidecars are emitted for both archives.

## SketchUp 2022 assessment

Minimum remains 23. The official API introduces Overlay and Model#overlays in SU2023; SU2020–2022 only allow textures while a Ruby Tool remains on the stack and automatically clean them up when the last one leaves. Production requires a passive overlay while native drawing tools remain active, so an active Tool probe is not a equivalent backend. Loader/main now use a capability guard and do not load the Overlay subclass on SU2022. Fixture enforces that minimum and rejects missing capabilities.

`dev/su2022_tool_probe.rb` defines an isolated four-color Tool experiment, without auto-running on load. It creates no model entities and records activation, draw, suspend/resume, deactivation, texture ID and model invariants. It is source-only development work, not runtime support. `dev/SU2022_COMPATIBILITY.md` lists API evidence and the follow-up work. The SU2022 installation directory exists locally; no native SU2022 or Ruby 2.7 execution is claimed. Packaging beta.6 proceeds with the correct SU2023 minimum as authorized.
