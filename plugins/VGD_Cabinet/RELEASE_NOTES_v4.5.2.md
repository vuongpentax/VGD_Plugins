# VGD Cabinet 4.5.2

Verification release for the Cabinet v2 development branch.

- Updates the SketchUp extension, dialog, and package version to 4.5.2 so this build is distinct from 4.5.1.
- Carries forward native SketchUp 2022.0.316 / Ruby 2.7.2 checks from the 4.5.1 model runtime, including batch settings preserving each cabinet's dimensions and independent module layout. The clean package should be rerun through `native_upgrade.rb` after installation.
- Confirms shared components/manual edits, rotated Box → Cabinet axes, drawer overlays, solid-part geometry, preview without model mutation, and library persistence/locking.
- Fixes the native regression check to compare module widths numerically after parameter normalization.
- Removes the unrelated VGD_EXPLODE/VGD_UNTAG commands and their unused assets from the shipped Cabinet runtime. For legacy cleanup, the SU2022 sync script backs up and retires only `tplus_cabinet.rb`; any existing `utilities.rb`, `combine.svg`, `untag.svg`, and `logo.svg` files are left untouched.

Native working-model Undo and closing/reopening the active model remain unverified.
