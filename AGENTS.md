# Agent Rules

- After every completed change set, run verification, check `git status`, and create a git commit before starting the next change set.
- Do not leave completed work only as uncommitted changes. This keeps rollback scoped to one change set instead of losing hours of work.
- Before reverting or deleting work, inspect `git status` and the relevant diff. Never revert unrelated completed work unless the user explicitly asks for it.
- For sprite assets, never overwrite runtime PNGs until generated frames have been inspected in a temporary output directory.
