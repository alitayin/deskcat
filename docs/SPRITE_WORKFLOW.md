# Sprite Workflow

Use `4x4` sprite sheets for AI-generated animation imports. The sheet has exactly 16 equal cells. Unused cells are allowed, but the input image must still be a real `4x4` grid with evenly sized cells.

## Required Actions

- `walk-right`: 10 frames
- `walk-left`: 10 frames
- `sleep`: 4 frames
- `idle`: 6 frames
- `tail`: 6 frames
- `groom`: 6 frames

## Import

```bash
./import_action_4x4.sh assets/source-sheets/ai-generated/walk-right.png walk-right
```

The importer writes the action frames into `assets/pet` only after slicing succeeds. It replaces only the selected action, so importing `sleep` does not delete accepted `walk-right` frames.

For each import, inspect both files before committing:

- `build/frame-checks/<action>/contact-sheet.png`
- `build/frame-checks/<action>/anchor-report.txt`

## Rejection Rules

Reject the sheet if any frame has cropped body parts, visible green-screen leftovers, ghosting, wrong direction, inconsistent body/head size, inconsistent baseline, off-center placement, or illogical motion order.

Rejected source sheets or frames go under `assets/rejected-pet-frames/`, not under `assets/pet`.
