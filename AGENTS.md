# VGD Plugins — Repository Guidelines

## Project Purpose

This repository contains the VGD ecosystem of SketchUp tools and plugins.

The repository is being rebuilt from a clean workspace. Existing VGD plugins will be migrated into this repository gradually, one module at a time.

Primary target:
- SketchUp 2022 and newer.
- Windows is the primary development and testing environment.
- SketchUp Ruby API is the main plugin platform.
- HTML/CSS/JavaScript may be used for `UI::HtmlDialog` interfaces.

Do not assume that old project structure, scripts, dependencies, or conventions should be preserved unless they are explicitly migrated into this repository.

## Repository Structure

The intended top-level structure is:

```text
VGD_Plugins/
├── AGENTS.md
├── README.md
├── .gitignore
├── docs/
├── plugins/
├── tools/
├── tests/
└── archive/
```

All production SketchUp plugins belong under `plugins/`.

Each plugin must remain reasonably self-contained.

Examples of future modules may include:
- VGD_Cabinet
- VGD_Dim
- VGD_Scenes
- VGD_BIM
- VGD_Library

Do not create these modules until they are actually being migrated or developed.

## Working Rules

Before making a significant change:

1. Read the relevant existing files.
2. Understand the current behavior.
3. State the intended change.
4. Make the smallest reasonable change.
5. Validate the result.
6. Report what changed and what could not be validated.

Do not rewrite working modules unnecessarily.

Do not introduce frameworks, dependencies, build systems, or architectural layers unless they solve a concrete requirement.

Do not create speculative features.

Do not silently change public behavior, naming, file formats, settings, or compatibility requirements.

## SketchUp Compatibility

Unless a module explicitly documents otherwise:

- Minimum supported version: SketchUp 2022.
- Prefer APIs available in SketchUp 2022 when practical.
- Do not use newer SketchUp APIs without checking compatibility.
- Keep SketchUp Ruby API calls separate from generic business logic where practical.
- Avoid relying on undocumented SketchUp behavior.

When compatibility is uncertain, identify the uncertainty instead of guessing.

## Coding Principles

Prefer:
- simple code;
- explicit behavior;
- small focused methods;
- descriptive names;
- clear separation between UI, SketchUp interaction, and core logic;
- backward-compatible changes where practical.

Avoid:
- unnecessary abstractions;
- duplicated logic;
- hidden global state;
- unexplained constants;
- large unrelated refactors during bug fixes.

Follow the style already established inside an existing module unless there is a clear reason to change it.

## UI Guidelines

VGD plugins may use `UI::HtmlDialog`.

When modifying UI:
- preserve existing behavior unless the task explicitly changes it;
- keep interfaces compact and practical;
- do not redesign unrelated UI;
- keep Ruby ↔ JavaScript communication explicit;
- validate user input before applying changes to the SketchUp model.

## Testing & Validation

No single repository-wide automated test framework is assumed yet.

For every change, use the strongest validation available for that module.

This may include:
- Ruby syntax checks;
- automated unit tests;
- static checks;
- focused test scripts;
- manual SketchUp verification.

Never claim a change was tested in SketchUp unless it was actually tested in SketchUp.

Clearly distinguish:
- verified automatically;
- verified manually;
- not yet verified.

Bug fixes should include a regression check when practical.

## Documentation

Keep documentation synchronized with actual behavior.

Important architectural decisions belong under `docs/`.

Do not create documentation merely to increase file count. Prefer a small number of useful documents over many overlapping notes.

## Git Rules

Keep commits focused.

Use concise commit messages describing the actual change.

Do not commit:
- credentials;
- temporary files;
- generated packages unless intentionally tracked;
- local caches;
- test output;
- downloaded dependencies.

Do not commit or push automatically unless explicitly requested.

Do not rewrite Git history unless explicitly requested.

## Safety Rules

Before destructive or broad operations, stop and inspect first.

Do not:
- delete large groups of files without justification;
- overwrite migrated source code blindly;
- mass-rename files during unrelated work;
- modify multiple plugins unnecessarily;
- discard existing changes that were not created by the current task.

If existing changes are discovered, preserve them unless explicitly instructed otherwise.

## Migration Strategy

Existing VGD projects must be migrated one plugin at a time.

For each migrated plugin:

1. Import the source.
2. Audit its structure.
3. Identify dependencies.
4. Establish a baseline.
5. Test existing behavior where possible.
6. Clean up only what is necessary.
7. Commit the stable baseline.
8. Continue development from that baseline.

Do not migrate all legacy VGD code at once.

## Agent Behavior

When a request is ambiguous, inspect the repository and use existing project context before making assumptions.

For large tasks, prefer:

```text
READ → PLAN → MODIFY → TEST → REVIEW
```

For small, well-defined fixes, avoid unnecessary planning overhead.

Always prioritize preserving working behavior and maintaining a clean, understandable repository.