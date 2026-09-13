# AGENTS.md — lua-mutation-test-action

Composite GitHub Action (YAML + bash) wrapping the `lmut` binary from
[lua-mutation-test](https://github.com/lua-mutation-test/lua-mutation-test).
Pre-`1.0` (ZeroVer `0.x`): inputs, flags, and behavior may change.

## Workflow (trunk-based development)

- Everything on `main`. Small, single-purpose commits, Conventional Commits
  (`feat:`, `fix:`, `test:`, `chore:`, `docs:`).
- **gh issues (#1–#16) are the trackers**: reference them in commits
  (`Refs #N`), post progress comments, close when done.
- Only the main agent commits and pushes. Subagents write files only —
  never `git commit`, `git push`, or `gh` mutations.
- CI must be green before and after every change (`git pull --rebase`
  before starting work).

## Test runner: bashunit (mandatory)

- Tests live in `tests/*_test.sh` as `function test_*()` using bashunit
  assertions (`assert_same`, `assert_equals`, `assert_contains`, ...).
  See https://bashunit.com/quickstart and `/assertions`.
- The runner is vendored at `lib/bashunit` (0.50.1, committed). Run the
  suite with `./lib/bashunit tests` (or `--filter <name>` for one test).
- `tests/bootstrap.sh` is sourced before tests — put shared helpers
  (temp `GITHUB_OUTPUT`/`GITHUB_STEP_SUMMARY`, stub `lmut`/`gh` on PATH)
  there. Track 1 creates it; other tracks may APPEND helpers only.
- Mocks/spies: prefer fakes on `PATH` (see bashunit test-doubles docs),
  e.g. a stub `lmut` printing canned output, a stub `gh` recording args.

## TDD (mandatory per track)

1. Write `tests/<area>_test.sh` FIRST (bashunit syntax).
2. Run `./lib/bashunit tests/<area>_test.sh` — it must FAIL
   (script/function missing).
3. Implement `scripts/<area>.sh` minimally until green.
4. Refactor, keep green. Cover happy path + error cases + boundaries
   (empty inputs, out-of-range numbers, non-numeric, missing files).

State exactly what you ran (`./lib/bashunit ...`, `shellcheck ...`) in
your final report.

Quality gates: `shellcheck` clean, `shfmt -i 2`-formatted (repo uses
2-space indent, not shfmt's tab default), `actionlint` clean
for all YAML.

## Script contracts (stable — do not change unilaterally)

All scripts use `set -euo pipefail`, take config via `INPUT_*` env vars
(the `action.yml` convention), and use no network except `install.sh`.

| Script                | Inputs (env)                                                                 | Outputs                                                  |
| --------------------- | ---------------------------------------------------------------------------- | -------------------------------------------------------- |
| `scripts/install.sh`  | `INPUT_VERSION`, `RUNNER_OS`, `RUNNER_ARCH`, `RUNNER_TEMP`, `GITHUB_PATH`     | `lmut` on PATH via `$GITHUB_PATH`; echoes resolved ver.  |
| `scripts/run.sh`      | `INPUT_PATH`, `INPUT_TEST_COMMAND`, `INPUT_CONFIG`, `INPUT_TIMEOUT`, `INPUT_ARGS` | runs `lmut run …`; raw log at `$RUNNER_TEMP/lmut.log` |
| `scripts/parse.sh`    | log file as `$1`                                                             | appends `mutation-score`, `killed`, `survived` to `$GITHUB_OUTPUT` |
| `scripts/gate.sh`     | `INPUT_FAIL_UNDER`, score as `$1`                                            | exit 0 pass / exit 1 with message; `0` disables gate     |
| `scripts/report.sh`   | survivor lines on stdin, `INPUT_JOB_SUMMARY`, `INPUT_ANNOTATIONS`, `GITHUB_STEP_SUMMARY` | job summary + `::warning file=…,line=…::` annotations |
| `scripts/comment.sh`  | `INPUT_COMMENT`, `GH_TOKEN`, `GITHUB_EVENT_NAME`, PR context                 | sticky PR comment; warning no-op when not on a PR event  |

## File ownership (4 parallel tracks — never touch another track's files)

- **Track 1**: `action.yml`, `scripts/install.sh`, `tests/install_test.sh`,
  `tests/bootstrap.sh` (creator), `lib/bashunit` (vendored runner, committed)
- **Track 2**: `scripts/run.sh`, `scripts/parse.sh`, `scripts/gate.sh`,
  `tests/run_test.sh`, `tests/parse_test.sh`, `tests/gate_test.sh`
- **Track 3**: `scripts/report.sh`, `scripts/comment.sh`,
  `tests/report_test.sh`, `tests/comment_test.sh`
- **Track 4**: `.github/workflows/`, `fixtures/`, `LICENSE`,
  `CONTRIBUTING.md`, plus README sections for its areas

`action.yml` is owned by Track 1. Other tracks consume the declared
`INPUT_*` / `GITHUB_*` contracts but never edit `action.yml`. README edits
are owned by Track 4; other tracks hand README snippets to the main agent
in their final report instead of editing README directly.
