#!/usr/bin/env bash
# Tests for scripts/release.sh (Refs #10).
# Validates SemVer tag parsing: vMAJOR.MINOR.PATCH with optional
# -prerelease; computes floating vMAJOR / vMAJOR.MINOR tags for stable
# releases. Build metadata (+build) is rejected (git-tag unfriendly).
# Helpers are local to this file (see tests/parse_test.sh convention).

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_SH="$REPO_ROOT/scripts/release.sh"

function set_up() {
  TEST_TMP="$(mktemp -d)"
  export GITHUB_OUTPUT="$TEST_TMP/github_output"
  : >"$GITHUB_OUTPUT"
}

function tear_down() {
  rm -rf "${TEST_TMP:?}"
}

function test_release_accepts_stable_zerover_tag() {
  bash "$RELEASE_SH" "v0.2.3" >/dev/null 2>&1
  assert_exit_code "0"
  out="$(cat "$GITHUB_OUTPUT")"
  assert_contains "tag=v0.2.3" "$out"
  assert_contains "version=0.2.3" "$out"
  assert_contains "prerelease=false" "$out"
  assert_contains "float-tags=v0 v0.2" "$out"
}

function test_release_accepts_stable_major_tag() {
  bash "$RELEASE_SH" "v10.20.30" >/dev/null 2>&1
  assert_exit_code "0"
  out="$(cat "$GITHUB_OUTPUT")"
  assert_contains "float-tags=v10 v10.20" "$out"
  assert_contains "prerelease=false" "$out"
}

function test_release_accepts_v1_boundary() {
  bash "$RELEASE_SH" "v1.0.0" >/dev/null 2>&1
  assert_exit_code "0"
  out="$(cat "$GITHUB_OUTPUT")"
  assert_contains "tag=v1.0.0" "$out"
  assert_contains "float-tags=v1 v1.0" "$out"
}

function test_release_prerelease_sets_flag_and_skips_float() {
  bash "$RELEASE_SH" "v1.0.0-rc.1" >/dev/null 2>&1
  assert_exit_code "0"
  out="$(cat "$GITHUB_OUTPUT")"
  assert_contains "tag=v1.0.0-rc.1" "$out"
  assert_contains "version=1.0.0-rc.1" "$out"
  assert_contains "prerelease=true" "$out"
  assert_contains "float-tags=" "$out"
}

function test_release_rejects_missing_v_prefix() {
  bash "$RELEASE_SH" "1.2.3" >/dev/null 2>&1
  assert_exit_code "1"
}

function test_release_rejects_missing_patch() {
  bash "$RELEASE_SH" "v1.2" >/dev/null 2>&1
  assert_exit_code "1"
}

function test_release_rejects_extra_component() {
  bash "$RELEASE_SH" "v1.2.3.4" >/dev/null 2>&1
  assert_exit_code "1"
}

function test_release_rejects_leading_zeros() {
  bash "$RELEASE_SH" "v01.2.3" >/dev/null 2>&1
  assert_exit_code "1"
}

function test_release_rejects_build_metadata() {
  bash "$RELEASE_SH" "v1.2.3+build.1" >/dev/null 2>&1
  assert_exit_code "1"
}

function test_release_rejects_empty_tag() {
  bash "$RELEASE_SH" "" >/dev/null 2>&1
  assert_exit_code "1"
}

function test_release_rejects_missing_arg() {
  bash "$RELEASE_SH" >/dev/null 2>&1
  assert_exit_code "1"
}

function test_release_requires_github_output() {
  unset GITHUB_OUTPUT
  bash "$RELEASE_SH" "v1.2.3" >/dev/null 2>&1
  assert_exit_code "1"
}
