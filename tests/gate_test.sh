#!/usr/bin/env bash
# Tests for scripts/gate.sh (Track 2, Refs #9).
# Helpers are local to this file: tests/bootstrap.sh (Track 1) must not
# be created here.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE_SH="$REPO_ROOT/scripts/gate.sh"

function test_gate_disabled_when_empty() {
  INPUT_FAIL_UNDER="" bash "$GATE_SH" "10" >/dev/null 2>&1
  assert_exit_code "0"
}

function test_gate_disabled_when_unset() {
  env -u INPUT_FAIL_UNDER bash "$GATE_SH" "10" >/dev/null 2>&1
  assert_exit_code "0"
}

function test_gate_disabled_when_zero() {
  INPUT_FAIL_UNDER="0" bash "$GATE_SH" "0" >/dev/null 2>&1
  assert_exit_code "0"
}

function test_gate_passes_above_threshold() {
  INPUT_FAIL_UNDER="80" bash "$GATE_SH" "87.5" >/dev/null 2>&1
  assert_exit_code "0"
}

function test_gate_passes_on_equal_score() {
  INPUT_FAIL_UNDER="80" bash "$GATE_SH" "80" >/dev/null 2>&1
  assert_exit_code "0"
}

function test_gate_fails_below_threshold_with_message() {
  tmp="$(mktemp)"
  INPUT_FAIL_UNDER="80" bash "$GATE_SH" "79.9" >"$tmp" 2>&1
  code="$?"
  assert_not_same "0" "$code"
  assert_contains "below fail-under" "$(cat "$tmp")"
  rm -f "$tmp"
}

function test_gate_float_compare() {
  INPUT_FAIL_UNDER="80.5" bash "$GATE_SH" "80.4" >/dev/null 2>&1
  assert_not_same "0" "$?"
  INPUT_FAIL_UNDER="80.5" bash "$GATE_SH" "80.6" >/dev/null 2>&1
  assert_exit_code "0"
}

function test_gate_boundary_100() {
  INPUT_FAIL_UNDER="100" bash "$GATE_SH" "100" >/dev/null 2>&1
  assert_exit_code "0"
  INPUT_FAIL_UNDER="100" bash "$GATE_SH" "99.9" >/dev/null 2>&1
  assert_not_same "0" "$?"
}

function test_gate_rejects_non_numeric() {
  INPUT_FAIL_UNDER="high" bash "$GATE_SH" "90" >/dev/null 2>&1
  assert_not_same "0" "$?"
}

function test_gate_rejects_negative() {
  INPUT_FAIL_UNDER="-5" bash "$GATE_SH" "90" >/dev/null 2>&1
  assert_not_same "0" "$?"
}

function test_gate_rejects_over_100() {
  INPUT_FAIL_UNDER="101" bash "$GATE_SH" "100" >/dev/null 2>&1
  assert_not_same "0" "$?"
}

function test_gate_rejects_non_numeric_score() {
  INPUT_FAIL_UNDER="80" bash "$GATE_SH" "abc" >/dev/null 2>&1
  assert_not_same "0" "$?"
}
