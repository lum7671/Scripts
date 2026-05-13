# PLAN_DEV

## Goal
- Keep `update_all.zsh` unchanged as the stable reference.
- Implement a new two-file structure:
  - `upall.zsh`: entry point and orchestration
  - `upall_lib.zsh`: reusable update/cleanup functions
- Preserve behavior first, then improve structure incrementally.

## Non-Goals (Phase 1)
- No behavior-breaking refactor.
- No multi-library split yet.
- No replacement of `update_all.zsh` as default command yet.

## Target Files
- Reference (unchanged): `update_all.zsh`
- New main: `upall.zsh`
- New library: `upall_lib.zsh`

## Phase 1 Steps
1. Create `upall_lib.zsh` and move common/helper/core functions.
2. Create `upall.zsh` and keep bootstrap/config/main option flow.
3. Keep `check.lst` normalization logic unchanged (CRLF trim + whitespace trim).
4. Keep git update path parsing and error diagnostics unchanged.
5. Validate syntax and basic command-line behavior.

## Progress
- [x] Phase 1 completed (new files created and syntax/help checks passed)
- [x] `update_all.zsh` kept unchanged as baseline
- [x] `upall.zsh` + `upall_lib.zsh` created and wired
- [x] `check.lst` normalization logic preserved in `upall.zsh`
- [x] Git path parsing/escaped error diagnostics preserved in `upall_lib.zsh`
- [x] Basic checks done: `zsh -n upall_lib.zsh`, `zsh -n upall.zsh`, `zsh upall.zsh --help`

## Phase 2 (Low-risk refactor) Progress
- [x] Added `run_step` helper in `upall_lib.zsh` to centralize result tracking
- [x] Replaced repeated `_track_result` calls in `run_all_updates()` with `run_step`
- [x] Switched argument parsing in `upall.zsh` to `while (( $# > 0 ))` style
- [x] Updated `UPDATE_ONLY` path to use `run_step` for consistent tracking
- [x] Added `check.lst` per-repo fallback flag:
  - `dir` => `git pull --rebase` only
  - `dir:f` => retry with `git pull --no-rebase` only when rebase fails

## Validation Checklist
1. `zsh -n upall_lib.zsh`
2. `zsh -n upall.zsh`
3. `zsh upall.zsh --help`
4. Confirm option list parity with `update_all.zsh`
5. Run one safe path (`--only-all-clean`) in a controlled environment when ready
6. Check `UPDATE_ONLY="update_git_repos"` with mixed `check.lst` entries (`dir`, `dir:f`)

## Rollback
- If any regression occurs, continue using `update_all.zsh` immediately.
- Compare behavior/log output between `update_all.zsh` and `upall.zsh`.
- Apply minimal fixes to `upall.zsh` / `upall_lib.zsh` only.

## Phase 2 (After parity)
- Standardize argument parsing (`while (( $# > 0 ))` style).
- Introduce `run_step` helper to remove repeated `_track_result` calls.
- Consider additional module split only if functions or change frequency grows.
