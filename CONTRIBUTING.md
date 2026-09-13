# Contributing to lua-mutation-test-action

This repo is trunk-based: everything lands on `main` in small,
single-purpose commits using
[Conventional Commits](https://www.conventionalcommits.org/)
(`feat:`, `fix:`, `test:`, `chore:`, `docs:`).

## Workflow

- Work is tracked in GitHub issues (#1–#15). Reference them in commits
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

## Releasing (SemVer, #10)

Tags are `vMAJOR.MINOR.PATCH` with an optional `-prerelease` suffix
(`v0.1.0`, `v1.0.0-rc.1`), validated by `scripts/release.sh`
(`./lib/bashunit tests/release_test.sh`). Build metadata (`+build`)
is rejected (`+` is URL-hostile in git tags and carries no
precedence). Stable releases move floating `vMAJOR` / `vMAJOR.MINOR`
tags, so users can pin `uses: ...@v0` (while `0.x`) or `@v1`.

Two ways to release; both run `.github/workflows/release.yml`, which
creates the GitHub Release (generated notes) and moves the floats:

1. `git tag -a v0.1.0 -m "Release v0.1.0" && git push origin v0.1.0`
   (the tag must be on green `main` — enforced in-workflow).
2. `gh workflow run release --ref main -f tag=v0.1.0` (tags the
   current `main` HEAD; refuses unless the latest `test` run on
   `main` is green).

Prereleases are marked prerelease and never move floating tags.
Publishing the action to the GitHub Marketplace is a manual one-click
step on the release page ("Publish this Action").

## Smoke test

The `smoke` job in `.github/workflows/test.yml` runs the local action
(`uses: ./`) against `fixtures/sample` with a stubbed `lmut` on `PATH`
(deterministic, offline) and asserts the step outputs plus the job-summary
content. To reproduce the fixture setup locally, inspect
`fixtures/sample/` (`lua/add.lua`, `spec/add_spec.lua`,
`.lua-mutation-test.toml` with `test_command = "busted"`).
