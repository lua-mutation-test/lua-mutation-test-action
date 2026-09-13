#!/usr/bin/env bash
# Tests for scripts/report.sh (Track 3, Refs #12,#15).
# Helpers are local to this file: tests/bootstrap.sh (Track 1) must not
# be created here.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_SH="$REPO_ROOT/scripts/report.sh"

function set_up() {
  TEST_TMP="$(mktemp -d)"
  export GITHUB_STEP_SUMMARY="$TEST_TMP/step_summary.md"
  : >"$GITHUB_STEP_SUMMARY"
  export INPUT_JOB_SUMMARY="true"
  export INPUT_ANNOTATIONS="true"
  export INPUT_SCORE="87.5"
  export INPUT_KILLED="42"
  export INPUT_SURVIVED="6"
  export GITHUB_SHA="abc123def456"
  export GITHUB_SERVER_URL="https://github.com"
  export GITHUB_REPOSITORY="octo/example"
}

function tear_down() {
  rm -rf "${TEST_TMP:?}"
}

function test_report_summary_headline_and_table() {
  printf '%s\n' \
    "lua/init.lua:42:5 — changed == to ~=" \
    "lua/util.lua:7:3 — removed call to sort" |
    bash "$REPORT_SH" >"$TEST_TMP/stdout.txt" 2>&1
  assert_exit_code "0"
  summary="$(cat "$GITHUB_STEP_SUMMARY")"
  assert_contains "87.5" "$summary"
  assert_contains "42 killed" "$summary"
  assert_contains "6 survived" "$summary"
  assert_contains "lua/init.lua" "$summary"
  assert_contains "lua/util.lua" "$summary"
}

function test_report_summary_disabled_writes_nothing() {
  export INPUT_JOB_SUMMARY="false"
  export INPUT_ANNOTATIONS="false"
  printf '%s\n' "lua/init.lua:42:5 — changed == to ~=" |
    bash "$REPORT_SH" >"$TEST_TMP/stdout.txt" 2>&1
  assert_exit_code "0"
  assert_same "" "$(cat "$GITHUB_STEP_SUMMARY")"
  assert_same "" "$(cat "$TEST_TMP/stdout.txt")"
}

function test_report_zero_survivors_success_state() {
  printf '' | bash "$REPORT_SH" >"$TEST_TMP/stdout.txt" 2>&1
  assert_exit_code "0"
  summary="$(cat "$GITHUB_STEP_SUMMARY")"
  assert_contains "No surviving mutants" "$summary"
  assert_not_contains "::warning" "$(cat "$TEST_TMP/stdout.txt")"
}

function test_report_annotations_emitted() {
  printf '%s\n' "lua/init.lua:42:5 — changed == to ~=" |
    bash "$REPORT_SH" >"$TEST_TMP/stdout.txt" 2>&1
  assert_exit_code "0"
  assert_contains "::warning file=lua/init.lua,line=42::changed == to ~=" "$(cat "$TEST_TMP/stdout.txt")"
}

function test_report_annotations_disabled() {
  export INPUT_ANNOTATIONS="false"
  printf '%s\n' "lua/init.lua:42:5 — changed == to ~=" |
    bash "$REPORT_SH" >"$TEST_TMP/stdout.txt" 2>&1
  assert_exit_code "0"
  assert_not_contains "::warning" "$(cat "$TEST_TMP/stdout.txt")"
}

function test_report_annotations_cap_at_10() {
  for i in $(seq 1 12); do
    echo "lua/file${i}.lua:${i}:1 — mutant ${i} survived"
  done | bash "$REPORT_SH" >"$TEST_TMP/stdout.txt" 2>&1
  assert_exit_code "0"
  out="$(cat "$TEST_TMP/stdout.txt")"
  assert_same "10" "$(printf '%s\n' "$out" | grep -c '^::warning file=')"
  assert_contains "::notice::" "$out"
  assert_contains "2 more" "$out"
}

function test_report_malformed_lines_skipped_with_warning() {
  printf '%s\n' \
    "this is not a survivor line" \
    "lua/init.lua:42:5 — changed == to ~=" |
    bash "$REPORT_SH" >"$TEST_TMP/stdout.txt" 2>&1
  assert_exit_code "0"
  out="$(cat "$TEST_TMP/stdout.txt")"
  assert_contains "::warning::" "$out"
  assert_contains "malformed" "$out"
  assert_contains "::warning file=lua/init.lua,line=42::" "$out"
  assert_same "1" "$(printf '%s\n' "$out" | grep -c '^::warning file=')"
}

function test_report_strips_dot_slash_prefix() {
  printf '%s\n' "./lua/init.lua:42:5 — changed == to ~=" |
    bash "$REPORT_SH" >"$TEST_TMP/stdout.txt" 2>&1
  assert_exit_code "0"
  assert_contains "::warning file=lua/init.lua,line=42::" "$(cat "$TEST_TMP/stdout.txt")"
}
