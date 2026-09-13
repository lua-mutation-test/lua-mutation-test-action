#!/usr/bin/env bash
# Tests for scripts/comment.sh (Track 3, Refs #14).
# Helpers are local to this file: tests/bootstrap.sh (Track 1) must not
# be created here. `gh` is stubbed with a PATH fake recording args.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMENT_SH="$REPO_ROOT/scripts/comment.sh"

function set_up() {
  TEST_TMP="$(mktemp -d)"
  FAKEBIN="$TEST_TMP/fakebin"
  mkdir -p "$FAKEBIN"
  # Stub gh: records each invocation's argv (one line per call),
  # answers the --jq lookup with $GH_EXISTING_ID, else prints canned JSON.
  cat >"$FAKEBIN/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${GH_ARGV_FILE:?}/argv"
for a in "$@"; do
  if [[ "$a" == "--jq" ]]; then
    printf '%s' "${GH_EXISTING_ID:-}"
    exit 0
  fi
done
printf '%s' "${GH_LIST_JSON:-[]}"
STUB
  chmod +x "$FAKEBIN/gh"
  export PATH="$FAKEBIN:$PATH"
  export GH_ARGV_FILE="$TEST_TMP"
  : >"$TEST_TMP/argv"
  unset GH_EXISTING_ID
  unset GH_LIST_JSON
  export INPUT_COMMENT="true"
  export INPUT_SCORE="87.5"
  export INPUT_KILLED="42"
  export INPUT_SURVIVED="6"
  export INPUT_PR_NUMBER=""
  export GH_TOKEN="fake-token"
  export GITHUB_EVENT_NAME="pull_request"
  export GITHUB_REPOSITORY="octo/example"
  export GITHUB_REF="refs/pull/42/merge"
}

function tear_down() {
  rm -rf "${TEST_TMP:?}"
}

function test_comment_disabled_exits_silent() {
  export INPUT_COMMENT="false"
  bash "$COMMENT_SH" >"$TEST_TMP/stdout.txt" 2>&1
  assert_exit_code "0"
  assert_same "" "$(cat "$TEST_TMP/stdout.txt")"
  assert_same "" "$(cat "$TEST_TMP/argv")"
}

function test_comment_non_pr_event_warns_noop() {
  export GITHUB_EVENT_NAME="push"
  bash "$COMMENT_SH" >"$TEST_TMP/stdout.txt" 2>&1
  assert_exit_code "0"
  assert_contains "::warning::" "$(cat "$TEST_TMP/stdout.txt")"
  assert_same "" "$(cat "$TEST_TMP/argv")"
}

function test_comment_missing_token_fails_on_pr() {
  unset GH_TOKEN
  export GH_TOKEN=""
  bash "$COMMENT_SH" >"$TEST_TMP/stdout.txt" 2>&1
  code="$?"
  assert_not_same "0" "$code"
  assert_contains "GH_TOKEN" "$(cat "$TEST_TMP/stdout.txt")"
}

function test_comment_posts_new_when_no_marker() {
  export GH_EXISTING_ID=""
  bash "$COMMENT_SH" >/dev/null 2>&1
  assert_exit_code "0"
  argv="$(cat "$TEST_TMP/argv")"
  assert_contains "POST" "$argv"
  assert_contains "issues/42/comments" "$argv"
  assert_not_contains "PATCH" "$argv"
}

function test_comment_patches_existing_when_marker_found() {
  export GH_EXISTING_ID="123456"
  bash "$COMMENT_SH" >/dev/null 2>&1
  assert_exit_code "0"
  argv="$(cat "$TEST_TMP/argv")"
  assert_contains "PATCH" "$argv"
  assert_contains "issues/comments/123456" "$argv"
}

function test_comment_pr_number_from_input() {
  export INPUT_PR_NUMBER="7"
  export GITHUB_REF="refs/heads/main"
  export GH_EXISTING_ID=""
  bash "$COMMENT_SH" >/dev/null 2>&1
  assert_exit_code "0"
  assert_contains "issues/7/comments" "$(cat "$TEST_TMP/argv")"
}

function test_comment_body_contains_marker_and_score() {
  export GH_EXISTING_ID=""
  bash "$COMMENT_SH" >/dev/null 2>&1
  assert_exit_code "0"
  assert_contains "lua-mutation-test-action" "$(cat "$TEST_TMP/argv")"
  assert_contains "87.5" "$(cat "$TEST_TMP/argv")"
}
