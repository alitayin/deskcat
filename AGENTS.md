# Agent Rules

- At session start, read this file, run `git status --short --untracked-files=all`, and check the latest commits with `git log --oneline --decorate --max-count=5`. Do not rely on chat memory for repo state.
- In multi-agent work, treat any existing uncommitted change as someone else's unless you made it in the current turn. Do not overwrite, format, restore, or delete those files without explicit user direction.
- After every completed change set, run verification, check `git status`, and create a git commit before starting the next change set.
- Do not leave completed work only as uncommitted changes. This keeps rollback scoped to one change set instead of losing hours of work.
- Before reverting or deleting work, inspect `git status` and the relevant diff. Never revert unrelated completed work unless the user explicitly asks for it.
- Use `./build.sh` as the normal verification command after Swift app changes.
- Use `./package-dmg.sh` only when changing packaging behavior or when the user asks for a DMG. It rebuilds `build/Billy.app`, deletes the existing `build/Billy.dmg`, and writes a new DMG.
- Do not commit generated build outputs: `build/`, `*.dmg`, or `.DS_Store`.
- For sprite assets, never overwrite runtime PNGs until generated frames have been inspected in a temporary output directory.
- Sprite import scripts are only deterministic guards: frame count, grid divisibility, green-screen removal, and non-polluting staging. They are not the final visual judge.
- Prefer `./import_action_4x4.sh <sheet.png> <action>` for new pet animations. It fixes the project workflow to `4x4` sheets while leaving the lower-level slicer configurable for debugging.
- Do not hand-write frame names for normal imports. Use the action importer so unused `4x4` cells are consistently named `_skip-*` and only the selected action is replaced.
- Before committing sprite assets, an agent must inspect the generated contact sheet and the individual PNG frames. Reject the set if the cat drifts away from center, changes size, changes baseline unexpectedly, faces the wrong direction, has cropped body parts, has ghosting, or has illogical/non-continuous motion.
- If a sprite set is rejected, move the source sheet or frames into `assets/rejected-pet-frames/` with a short reason in the filename or commit message. Do not keep rejected frames under `assets/pet`.
