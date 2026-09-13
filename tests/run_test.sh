#!/usr/bin/env bash
# Tests for scripts/run.sh (Track 2, Refs #2,#3,#4,#6,#7).
# Helpers are local to this file: tests/bootstrap.sh (Track 1) must not
# be created here.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_SH="$REPO_ROOT/scripts/run.sh"

function set_up() {
  TEST_TMP="$(mktemp -d)"
  FAKEBIN="$TEST_TMP/fakebin"
  mkdir -p "$FAKEBIN"
  # Stub lmut: records each argv on its own line (spaces preserved),
  # prints a canned summary, exits 0 unless LMUT_EXIT is set.
  cat >"$FAKEBIN/lmut" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${LMUT_ARGV_FILE:?}/argv"
echo "Mutation score: 87.5% (42 killed, 6 survived, 0 timed out)"
exit "${LMUT_EXIT:-0}"
STUB
  chmod +x "$FAKEBIN/lmut"
  export LMUT_ARGV_FILE="$TEST_TMP"
  export PATH="$FAKEBIN:$PATH"
  export RUNNER_TEMP="$TEST_TMP"
  export GITHUB_OUTPUT="$TEST_TMP/github_output"
  : >"$GITHUB_OUTPUT"
  export INPUT_PATH="lua"
  export INPUT_TEST_COMMAND=""
  export INPUT_CONFIG=""
  export INPUT_TIMEOUT=""
  export INPUT_ARGS=""
  unset LMUT_EXIT
}

function tear_down() {
  rm -rf "${TEST_TMP:?}"
}

function test_run_passes_path_and_writes_log() {
  bash "$RUN_SH" >"$TEST_TMP/stdout.txt" 2>&1
  assert_exit_code "0"
  assert_same "run" "$(sed -n '1p' "$TEST_TMP/argv")"
  assert_same "lua" "$(sed -n '2p' "$TEST_TMP/argv")"
  assert_is_file "$TEST_TMP/lmut.log"
  assert_contains "Mutation score:" "$(cat "$TEST_TMP/lmut.log")"
}

function test_run_appends_optional_flags_when_nonempty() {
  export INPUT_TEST_COMMAND="busted"
  export INPUT_CONFIG=".lua-mutation-test.toml"
  export INPUT_TIMEOUT="60"
  bash "$RUN_SH" >/dev/null 2>&1
  assert_exit_code "0"
  argv="$(cat "$TEST_TMP/argv")"
  assert_contains "--test-command" "$argv"
  assert_contains "busted" "$argv"
  assert_contains "--config" "$argv"
  assert_contains ".lua-mutation-test.toml" "$argv"
  assert_contains "--timeout" "$argv"
  assert_contains "60" "$argv"
}

function test_run_omits_empty_optional_flags() {
  bash "$RUN_SH" >/dev/null 2>&1
  assert_exit_code "0"
  argv="$(cat "$TEST_TMP/argv")"
  assert_not_contains "--test-command" "$argv"
  assert_not_contains "--config" "$argv"
  assert_not_contains "--timeout" "$argv"
}

function test_run_path_with_spaces_is_single_arg() {
  export INPUT_PATH="my dir/lua"
  bash "$RUN_SH" >/dev/null 2>&1
  assert_exit_code "0"
  assert_same "my dir/lua" "$(sed -n '2p' "$TEST_TMP/argv")"
}

function test_run_splits_extra_args() {
  export INPUT_ARGS="--report-format json --verbose"
  bash "$RUN_SH" >/dev/null 2>&1
  assert_exit_code "0"
  argv="$(cat "$TEST_TMP/argv")"
  assert_contains "--report-format" "$argv"
  assert_contains "json" "$argv"
  assert_contains "--verbose" "$argv"
}

function test_run_propagates_lmut_failure() {
  export LMUT_EXIT="3"
  bash "$RUN_SH" >/dev/null 2>&1
  assert_exit_code "3"
}

function test_run_missing_lmut_errors_clearly() {
  # PATH with no lmut anywhere: empty dir only.
  mkdir -p "$TEST_TMP/emptybin"
  PATH="$TEST_TMP/emptybin:/usr/bin:/bin" bash "$RUN_SH" >"$TEST_TMP/out.txt" 2>&1
  code="$?"
  assert_not_same "0" "$code"
  assert_contains "lmut" "$(cat "$TEST_TMP/out.txt")"
}
