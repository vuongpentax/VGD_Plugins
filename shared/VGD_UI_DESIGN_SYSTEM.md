# VGD Plugin UI Design System

This document defines the shared visual language for the VGD SketchUp plugins: VGD Dim, VGD Cabinet, VGD Image Importer, VGD Library, VGD Scenes, and VGD BIM Lite.

## Design direction

- Use a dark graphite interface by default on first launch.
- Keep a visible light/dark control wherever a plugin has a dialog. Save the user's choice per plugin and respect it on later launches.
- Use the existing VGD warm bronze palette as the brand accent. Reserve accent fills for primary actions, selected navigation, and clear focus states.
- Keep each plugin's information architecture and workflow. Share visual patterns and tokens without forcing identical page layouts.
- Use Vietnamese for user-facing controls and messages, retaining established technical terms where they are clearer.

## Theme tokens

### Dark (default)

| Token | Value | Use |
|---|---|---|
| `--vgd-bg` | `#121212` | Main window background |
| `--vgd-surface` | `#1E1E1E` | Cards, panels, navigation |
| `--vgd-elevated` | `#2B2B2B` | Header, raised controls |
| `--vgd-border` | `#3A3A3A` | Dividers, outlines |
| `--vgd-text` | `#E2E8F0` | Primary text |
| `--vgd-muted` | `#A7B0BD` | Labels, help text, secondary text |
| `--vgd-accent` | `#B48963` | Brand accent, primary action |
| `--vgd-accent-strong` | `#C8A98A` | Accent text and hover emphasis |
| `--vgd-tint` | `#372C24` | Selected and highlighted surfaces |
| `--vgd-danger` | `#E79C91` | Destructive and error feedback |
| `--vgd-success` | `#A8C69D` | Success feedback |

### Light (user selectable)

| Token | Value | Use |
|---|---|---|
| `--vgd-bg` | `#F7F7F5` | Main window background |
| `--vgd-surface` | `#FFFFFF` | Cards, panels, navigation |
| `--vgd-elevated` | `#F0EEE9` | Header, raised controls |
| `--vgd-border` | `#E5E5E5` | Dividers, outlines |
| `--vgd-text` | `#222222` | Primary text |
| `--vgd-muted` | `#6F6F6F` | Labels, help text, secondary text |
| `--vgd-accent` | `#B48963` | Brand accent, primary action |
| `--vgd-accent-strong` | `#8E6B4C` | Accent text and hover emphasis |
| `--vgd-tint` | `#F3ECE5` | Selected and highlighted surfaces |
| `--vgd-danger` | `#A73D36` | Destructive and error feedback |
| `--vgd-success` | `#507247` | Success feedback |

Use `color-scheme: dark` or `color-scheme: light` with the active theme so native HTML controls match the dialog. Theme state must not be shared across plugins; retain each plugin's existing storage key unless a migration is required.

## Layout and components

- Use the same VGD wordmark treatment, product name, and version hierarchy in each header. The header arrangement may differ when a plugin needs a compact toolbar or a two-pane workflow.
- Use the shared spacing rhythm: 4, 8, 12, 16, 24, and 32 px. Keep related controls close and separate major groups with 12–16 px.
- Use 4 px control corners and 6 px panel corners. Keep borders subtle and consistent in both themes.
- Primary buttons use the bronze accent. Secondary actions use a neutral surface and border. Destructive actions use the semantic danger color and must not look like primary actions.
- Keep keyboard focus clearly visible with a 2 px accent outline. Disabled controls remain legible and visibly inactive.
- Use consistent control heights within a dialog (normally 32–36 px) and preserve comfortable click targets.
- Navigation may be a side rail, tab row, or workflow stepper according to the plugin, but selected state, spacing, and accent treatment should match.
- Preserve each plugin's current information hierarchy and model-operation behavior during visual work.

## Icon language

- Use authored SVG icons with a 24 × 24 viewBox, consistent 1.75–2 px strokes, rounded caps and joins, and the same visual weight.
- Use the accent only for active/selected states; default icons use the current text-muted token.
- Prefer simple geometric metaphors that remain recognizable at 16–20 px. Avoid mixing emoji, text glyphs, filled icons, and unrelated stroke families in one toolbar.
- Keep SketchUp toolbar icons legible at small sizes and provide a tooltip for every icon-only action.

## First-launch and preference behavior

- A new user sees dark mode on the first launch.
- A previously saved explicit light preference remains light; a saved dark preference remains dark.
- Toggling the theme updates the whole dialog immediately and persists the choice.
- Theme keys are plugin-specific so changing one dialog does not unexpectedly change another.

## Rollout and review

1. Apply the tokens and theme behavior to each active runtime UI, not archived previews or reference HTML.
2. Keep the Cabinet UI generator and generated runtime source aligned.
3. Review each dialog in both themes at its ordinary SketchUp size. Use the full-screen screenshots as content references, not as target window dimensions.
4. Review toolbar icons at actual SketchUp toolbar size and verify tooltips.
5. Keep interaction, packaging, and native SketchUp behavior outside the scope of purely visual edits.
