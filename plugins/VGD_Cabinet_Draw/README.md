# VGD_Cabinet Draw 1.0.0-beta.1

Baseline source độc lập 1.0.0-beta.1: có RBZ local trong worktree nguồn, 15 entry khớp source. Chưa xác minh phát hành công khai hoặc native SketchUp. Không kèm artifact; dev/native_smoke.rb có thao tác hình học và không được chạy trong đợt này. Đợt chuyển repository chỉ đối chiếu source/checksum; chưa chạy lại test tự động hoặc kiểm thử native SketchUp. Các kết quả PASS bên dưới thuộc lịch sử workspace nguồn.

VGD_Cabinet Draw is a standalone SketchUp extension for a semi-automatic cabinet workflow. It keeps the user in control of face orientation, panel positions, door splits, openings, handles, drawers and finishing operations. Preview lives in the viewport; a tool commits model geometry only when the user presses Enter.

The extension is registered independently from VGD_Cabinet. It uses its own `VGD_Cabinet_Draw` model dictionary and `%APPDATA%/VGD/SketchUp/VGD_Cabinet_Draw` data folder. It does not import old cabinet model dictionaries or preset files. The old extension sources remain untouched beside this project.

## Workflow

1. Select a rough box and use **Box → Cabinet**. Click its front face to confirm local orientation.
2. Add shelves/partitions with the viewport tool. Enter a distance or `/n` in SketchUp's Measurements box to place or divide evenly.
3. Draw door splits on the cabinet face, set the opening direction, and place drawer fronts and boxes.
4. Add handles and blockers, then use cut, round and notch tools for manual finishing.
5. Save settings to a grouped preset for the next model.

## Development and validation

- Runtime entry point: `main.rb` → `runtime/VGD_Cabinet_Draw/main.rb`.
- Native target: SketchUp 2022, Ruby 2.7.
- Package builder: `dev/build_release.py`.
- Native acceptance script: `dev/native_smoke.rb`.

This beta has not been verified in a live SketchUp model. Test geometry, Undo, selection context, transformed boxes and preview lifecycle in SketchUp 2022 before production use.
