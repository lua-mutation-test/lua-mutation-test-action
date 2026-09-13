#!/usr/bin/env bash
# Tests for scripts/parse.sh (Track 2, Refs #8).
# Helpers are local to this file: tests/bootstrap.sh (Track 1) must not
# be created here.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PARSE_SH="$REPO_ROOT/scripts/parse.sh"

function set_up() {
  TEST_TMP="$(mktemp -d)"
  export GITHUB_OUTPUT="$TEST_TMP/github_output"
  : >"$GITHUB_OUTPUT"
}

function tear_down() {
  rm -rf "${TEST_TMP:?}"
}

function test_parse_extracts_score_killed_survived() {
  printf '%s\n' "running..." "Mutation score: 87.5% (42 killed, 6 survived, 0 timed out)" >"$TEST_TMP/lmut.log"
  bash "$PARSE_SH" "$TEST_TMP/lmut.log" >/dev/null 2>&1
  assert_exit_code "0"
  out="$(cat "$GITHUB_OUTPUT")"
  assert_contains "mutation-score=87.5" "$out"
  assert_contains "killed=42" "$out"
  assert_contains "survived=6" "$out"
}

function test_parse_100_percent_boundary() {
  printf '%s\n' "Mutation score: 100% (10 killed, 0 survived, 0 timed out)" >"$TEST_TMP/lmut.log"
  bash "$PARSE_SH" "$TEST_TMP/lmut.log" >/dev/null 2>&1
  assert_exit_code "0"
  out="$(cat "$GITHUB_OUTPUT")"
  assert_contains "mutation-score=100" "$out"
  assert_contains "killed=10" "$out"
  assert_contains "survived=0" "$out"
}

function test_parse_zero_percent_boundary() {
  printf '%s\n' "Mutation score: 0% (0 killed, 9 survived, 1 timed out)" >"$TEST_TMP/lmut.log"
  bash "$PARSE_SH" "$TEST_TMP/lmut.log" >/dev/null 2>&1
  assert_exit_code "0"
  out="$(cat "$GITHUB_OUTPUT")"
  assert_contains "mutation-score=0" "$out"
  assert_contains "survived=9" "$out"
}

function test_parse_missing_file_fails() {
  bash "$PARSE_SH" "$TEST_TMP/does-not-exist.log" >"$TEST_TMP/out.txt" 2>&1
  code="$?"
  assert_not_same "0" "$code"
  assert_contains "not found" "$(cat "$TEST_TMP/out.txt")"
}

function test_parse_malformed_log_fails() {
  printf '%s\n' "some output" "no summary here" >"$TEST_TMP/lmut.log"
  bash "$PARSE_SH" "$TEST_TMP/lmut.log" >"$TEST_TMP/out.txt" 2>&1
  code="$?"
  assert_not_same "0" "$code"
  assert_contains "could not parse" "$(cat "$TEST_TMP/out.txt")"
}

function test_parse_missing_arg_fails() {
  bash "$PARSE_SH" >"$TEST_TMP/out.txt" 2>&1
  code="$?"
  assert_not_same "0" "$code"
}
