# SketchUp verification checklist

Use a blank disposable model in SketchUp 2024 first. Do not use a production model. Run each step after installing the RBZ and restarting SketchUp.

## Spike 01 — overlay texture

- Add one JPG, then one PNG; confirm the full photo appears above the viewport (not a flat sampled-color rectangle) without creating a model entity.
- Orbit, pan, zoom the camera; confirm image frame stays at the same screen position and size.
- Disable and re-enable **VGD Reference** in the Overlays panel; confirm the images disappear and return.
- Keep five images visible and leave SketchUp idle to check for repeated texture loading or visible lag.

## Spike 02 — opacity

- Open the manager, select an image, and move opacity through 100%, 50%, and 10% over model geometry.
- Confirm alpha preview and the cached texture after releasing the slider both blend correctly.
- Compare preview and committed opacity at 50%; the image should have the same opacity before and after releasing the slider.
- Test transparent PNG pixels at all three values.
- Delete the image and verify redraw does not retain the previous texture.

## Spike 03 — edit tool

- Add an image; move it, resize from each corner, and confirm the aspect ratio remains fixed.
- Place the pointer over a detail and use the wheel; confirm the detail stays under the pointer.
- Hold Space and drag to pan image contents without moving the frame.
- Double-click to reset zoom. Press Escape and confirm passive image no longer intercepts clicks.
- Press Undo during a move or crop drag; confirm the tool leaves the pointer operation in a clean state.
- With the pointer outside the selected image, scroll and confirm SketchUp camera zoom still works.
- Move the pointer across the body, four resize corners, and crop edges; confirm the matching cursor appears.

## Spike 04 — RMB quick move

- Prototype is disabled. Only enable `QuickMovePrototype::ENABLED` for a separate local experiment.
- Drag a locked image with the right button, then release over the viewport and over empty UI space.
- Reject the feature if a context menu appears, SketchUp camera navigation changes, or the pointer gets stuck.

## Spike 05 — clipboard and drop

- Copy a PNG from Chrome and Edge, then paste from the VGD Reference menu.
- Repeat with Snipping Tool, Photos, and Photoshop; verify PNG, CF_DIBV5, and CF_DIB cases.
- Drop JPG and PNG files from Explorer onto the manager. Confirm unsupported file types are ignored.
- Confirm a dropped image above 20 MiB is rejected with a clear message.
- Confirm the manager buttons, image actions, status messages, and Extensions menu are in Vietnamese.
- Delete pasted/dropped images and close SketchUp; confirm temp files are removed.

## Spike 06 — DPI

- In SketchUp 2024, check 100%, 125%, 150%, 175%, and 200% Windows display scaling.
- Repeat after moving SketchUp to a second monitor with a different scale.
- In SketchUp 2025+, repeat and verify event hit targets match draw positions after changing monitors.
- Confirm resize handles and crop edges remain reachable.

## Beta.6 — icon and manager themes

- Install beta.6 and restart; confirm the pinned-photo glyph appears in the SketchUp 2024 light toolbar at small and large icon sizes.
- Open the Vietnamese manager; check add, paste, hide/show, select, visibility, lock, delete, edit, crop and opacity after the icon change.
- Check both system color schemes: header glyph, panel backgrounds, names, messages, selected rows and buttons must use the corresponding light/dark palette. CEF versions may differ in how they report the system color scheme.
- Resize to the minimum dialog size; confirm buttons and footer remain reachable.
- Open the header's toolbar-icon settings. Switch light/dark; check the actual native Command icon, close/reopen the manager and restart SketchUp to confirm persistence. Restore light for the standard SU 2024 toolbar. This preference affects the native icon only; the manager follows the system scheme.
