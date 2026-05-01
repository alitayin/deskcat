# Sprite Workflow

Use `4x4` sprite sheets for AI-generated animation imports. The sheet has exactly 16 equal cells. Unused cells are allowed, but the input image must still be a real `4x4` grid with evenly sized cells.

The 16 cells are candidates. An action does not need to use the first N cells. After visual review, choose the best cells in playback order and pass their 1-based indexes to the importer.

Use [Billy Reference](/Users/gongdongjie/learn1/native-swift/assets/references/BILLY_REFERENCE.md) for every generation prompt.

## Required Actions

- `walk-right`: 16 frames
- `walk-left`: 16 frames
- `sleep`: 4 frames
- `idle`: 6 frames
- `tail`: 6 frames
- `groom`: 4 frames

## Import

```bash
./import_action_4x4.sh assets/source-sheets/ai-generated/walk-right.png walk-right
```

To select specific cells from the 16 candidates:

```bash
./import_action_4x4.sh assets/source-sheets/ai-generated/groom.png groom 1,2,5,6,9,10
```

The importer writes the action frames into `assets/pet` only after slicing succeeds. It replaces only the selected action, so importing `sleep` does not delete accepted `walk-right` frames.

If a manual source sheet already has a transparent background, keep it as the original master and use it directly for slicing.

For each import, inspect the generated contact sheet and individual PNGs before committing:

- `build/frame-checks/<action>/contact-sheet.png`

## Rejection Rules

Reject only after visual review if the cut frames have cropped body parts, visible green-screen leftovers, ghosting, wrong direction, inconsistent body/head size, obvious placement jumps, or illogical motion order.

Rejected source sheets or frames go under `assets/rejected-pet-frames/`, not under `assets/pet`.
