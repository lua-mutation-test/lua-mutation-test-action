# Contributing to lua-mutation-test-action

This repo is trunk-based: everything lands on `main` in small,
single-purpose commits using
[Conventional Commits](https://www.conventionalcommits.org/)
(`feat:`, `fix:`, `test:`, `chore:`, `docs:`).

## Workflow

- Work is tracked in GitHub issues (#1–#16). Reference them in commits
  (`Refs #N`) and close them when done.
- `git pull --rebase` before starting; CI must be green before and after
  every change.
- File ownership is split across 4 parallel tracks — see `AGENTS.md`.
  Never edit another track's files unilaterally.

## Tests (bashunit, TDD mandatory)

1. Write `tests/<area>_test.sh` FIRST — it must FAIL (script missing).
2. Implement `scripts/<area>.sh` minimally until green.
3. Refactor, keep green. Cover happy path + error cases + boundaries
   (empty inputs, out-of-range numbers, non-numeric, missing files).

```sh
./lib/bashunit tests                  # full suite
./lib/bashunit tests/<area>_test.sh   # one file
```

## Quality gates

- `shellcheck` clean over `scripts/` and `tests/`.
- `actionlint` clean over `.github/workflows/`.
- Shell formatted with `shfmt`.

## Releasing (semantic-release, #10)

Releases are fully automated with
[semantic-release](https://semantic-release.gitbook.io), mirroring
`rcasia/neotest-java`. `.github/workflows/release.yml` runs daily at
08:00 UTC (or on demand via `gh workflow run release`): it runs the
test suite (`test.yml` via `workflow_call`), then derives the next
version from Conventional Commits on `main` (`.releaserc.json`):

- `feat:` -> minor, `fix:` / `refactor:` / `perf:` -> patch,
  `BREAKING CHANGE:` -> major.
- Tags are `vMAJOR.MINOR.PATCH`; stable releases move floating
  `vMAJOR` / `vMAJOR.MINOR` tags (computed by `scripts/release.sh`),
  so users can pin `uses: ...@v0` (while `0.x`) or `@v1`.

Just merge conventional commits to `main` — never cut tags by hand.
(The single `v0.1.0` bootstrap tag was cut manually so automation
starts on the `0.x` line; everything after it is automated.)
Publishing the action to the GitHub Marketplace is a manual one-click
step on the release page ("Publish this Action").

## Smoke test

The `smoke` job in `.github/workflows/test.yml` runs the local action
(`uses: ./`) against `fixtures/sample` with a stubbed `lmut` on `PATH`
(deterministic, offline) and asserts the step outputs plus the job-summary
content. To reproduce the fixture setup locally, inspect
`fixtures/sample/` (`lua/add.lua`, `spec/add_spec.lua`,
`.lua-mutation-test.toml` with `test_command = "busted"`).
