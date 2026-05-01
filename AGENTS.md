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
