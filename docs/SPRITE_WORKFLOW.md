# Sprite Workflow

Use `4x4` sprite sheets for AI-generated animation imports. The sheet has exactly 16 equal cells. Unused cells are allowed, but the input image must still be a real `4x4` grid with evenly sized cells.

The 16 cells are candidates. An action does not need to use the first N cells. After visual review, choose the best cells in playback order and pass their 1-based indexes to the importer.

Use [Billy Reference](/Users/gongdongjie/learn1/native-swift/assets/references/BILLY_REFERENCE.md) for every generation prompt.

## Required Actions

- `walk-left`: 6 frames
- `walk-right`: optional; the app mirrors `walk-left` at runtime when no right-facing frames exist
- `run`: 14 frames currently loaded from `run-*`; shown as sprinting and mirrored at runtime when moving right
- `sleep`: 4 frames, 500ms per frame
- `daze`: 10 frames, 800ms per frame
- `look`: 11 frames, 800ms per frame; shown as `观察` in the app
- `lazy`: 8 frames, 500ms per frame; shown as `伸懒腰` in the app
- `groom`: 5 frames, 500ms per frame

Runtime display size and mouse hit area are `200 x 200` for walking and sprinting, and `160 x 160` for every other action. Walking plays at 300ms per frame. Sprinting eases from 500ms at the first/last frames to 200ms near the middle frames. `daze` and `look` play at 800ms per frame; every other action plays at 500ms per frame.

## Import

```bash
./import_action_4x4.sh assets/source-sheets/ai-generated/daze.png daze
```

To select specific cells from the 16 candidates:

```bash
./import_action_4x4.sh assets/source-sheets/ai-generated/groom.png groom 1,2,5,6,9
```

The importer writes the action frames into `assets/pet` only after slicing succeeds. It replaces only the selected action, so importing `sleep` does not delete accepted `walk-left` frames.

If a manual source sheet already has a transparent background, keep it as the original master and use it directly for slicing.

For each import, inspect the generated contact sheet and individual PNGs before committing:

- `build/frame-checks/<action>/contact-sheet.png`

## Rejection Rules

Reject only after visual review if the cut frames have cropped body parts, visible green-screen leftovers, ghosting, wrong direction, inconsistent body/head size, obvious placement jumps, or illogical motion order.

Rejected source sheets or frames go under `assets/rejected-pet-frames/`, not under `assets/pet`.
