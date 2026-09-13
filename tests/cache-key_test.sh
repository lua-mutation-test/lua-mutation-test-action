#!/usr/bin/env bash
# Tests for scripts/cache-key.sh: deterministic cache key over all lmut inputs.
# Helpers are local to this file: tests/bootstrap.sh must not be created here.
# Offline only: pinned INPUT_VERSION values or stubbed lmut/curl (never the
# live `resolve_version latest` network path).

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_KEY_SH="$REPO_ROOT/scripts/cache-key.sh"
_ORIG_PATH="$PATH"

function set_up() {
  TEST_TMP="$(mktemp -d)"
  mkdir -p "$TEST_TMP/emptybin" "$TEST_TMP/work/src"
  export PATH="$_ORIG_PATH"
  export INPUT_PATH="."
  export INPUT_TEST_COMMAND=""
  export INPUT_CONFIG=""
  export INPUT_TIMEOUT=""
  export INPUT_ARGS=""
  export INPUT_VERSION="0.0.3"
  export RUNNER_OS="Linux"
  export RUNNER_ARCH="X64"
  _SAVED_PWD="$PWD"
  cd "$TEST_TMP/work" || return 1
  printf '%s\n' 'local M = {}' 'function M.add(a, b) return a + b end' 'return M' >src/add.lua
}

function tear_down() {
  cd "$_SAVED_PWD" || return 1
  export PATH="$_ORIG_PATH"
  rm -rf "${TEST_TMP:?}"
}

# path_without_lmut: restrict PATH so `command -v lmut` finds nothing.
function path_without_lmut() {
  export PATH="$TEST_TMP/emptybin:/usr/bin:/bin"
}

# stub_lmut_version <version>: fake lmut answering `--version`.
function stub_lmut_version() {
  local version="${1:?Usage: stub_lmut_version <version>}"
  local fakebin="$TEST_TMP/fakebin"
  mkdir -p "$fakebin"
  cat >"$fakebin/lmut" <<STUB
#!/usr/bin/env bash
if [[ "\${1:-}" == "--version" ]]; then
  echo "lmut ${version}"
  exit 0
fi
echo "Mutation score: 87.5% (42 killed, 6 survived, 0 timed out)"
STUB
  chmod +x "$fakebin/lmut"
  export PATH="$fakebin:/usr/bin:/bin"
}

function test_stable_key_for_identical_inputs() {
  path_without_lmut
  key1="$(bash "$CACHE_KEY_SH" 2>"$TEST_TMP/err.txt")"
  assert_same "0" "$?"
  key2="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  assert_same "$key1" "$key2"
}

function test_key_is_single_line_without_spaces() {
  path_without_lmut
  key="$(bash "$CACHE_KEY_SH" 2>"$TEST_TMP/err.txt")"
  assert_same "0" "$?"
  lines="$(printf '%s\n' "$key" | wc -l | tr -d ' ')"
  assert_same "1" "$lines"
  assert_not_contains " " "$key"
}

function test_key_changes_when_source_content_changes() {
  path_without_lmut
  key1="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  printf '%s\n' 'local M = {}' 'function M.add(a, b) return a - b end' 'return M' >src/add.lua
  key2="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  assert_not_same "$key1" "$key2"
}

function test_key_changes_when_test_file_changes() {
  path_without_lmut
  key1="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  mkdir -p spec
  printf '%s\n' 'describe("add", function() it("adds", function() end) end)' >spec/add_spec.lua
  key2="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  assert_not_same "$key1" "$key2"
  printf '%s\n' '-- touched' >>spec/add_spec.lua
  key3="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  assert_not_same "$key2" "$key3"
}

function test_key_changes_when_config_content_changes() {
  path_without_lmut
  printf '%s\n' 'timeout = 10' >.lua-mutation-test.toml
  export INPUT_CONFIG=".lua-mutation-test.toml"
  key1="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  printf '%s\n' 'timeout = 20' >.lua-mutation-test.toml
  key2="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  assert_not_same "$key1" "$key2"
}

function test_key_changes_when_test_command_changes() {
  path_without_lmut
  key1="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  export INPUT_TEST_COMMAND="busted"
  key2="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  assert_not_same "$key1" "$key2"
}

function test_key_changes_when_timeout_changes() {
  path_without_lmut
  key1="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  export INPUT_TIMEOUT="60"
  key2="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  assert_not_same "$key1" "$key2"
}

function test_key_changes_when_args_change() {
  path_without_lmut
  key1="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  export INPUT_ARGS="--verbose"
  key2="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  assert_not_same "$key1" "$key2"
}

function test_key_changes_when_version_changes() {
  path_without_lmut
  key1="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  export INPUT_VERSION="0.0.4"
  key2="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  assert_not_same "$key1" "$key2"
}

function test_key_changes_when_runner_os_or_arch_changes() {
  path_without_lmut
  key1="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  export RUNNER_OS="macOS"
  key2="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  assert_not_same "$key1" "$key2"
  export RUNNER_OS="Linux"
  export RUNNER_ARCH="ARM64"
  key3="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  assert_not_same "$key1" "$key3"
}

function test_key_ignores_mtime_only_changes() {
  path_without_lmut
  key1="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  touch -t 203001010000 src/add.lua
  key2="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  assert_same "$key1" "$key2"
}

function test_pinned_version_used_verbatim_when_lmut_absent() {
  path_without_lmut
  export INPUT_VERSION="v0.0.3"
  key1="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  assert_contains "0.0.3" "$key1"
  assert_not_contains "latest" "$key1"
  export INPUT_VERSION="0.0.3"
  key2="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  assert_same "$key1" "$key2"
}

function test_lmut_version_preferred_when_on_path() {
  stub_lmut_version "1.2.3"
  export INPUT_VERSION="0.0.3"
  key="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  assert_contains "1.2.3" "$key"
  assert_not_contains "0.0.3" "$key"
  assert_not_contains "latest" "$key"
}

function test_latest_never_emitted_with_lmut_on_path() {
  stub_lmut_version "0.0.3"
  export INPUT_VERSION="latest"
  key="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  assert_contains "0.0.3" "$key"
  assert_not_contains "latest" "$key"
}

function test_latest_resolved_via_api_when_lmut_absent() {
  path_without_lmut
  mkdir -p "$TEST_TMP/curlbin"
  cat >"$TEST_TMP/curlbin/curl" <<'STUB'
#!/usr/bin/env bash
echo '{"tag_name": "v9.9.9"}'
STUB
  chmod +x "$TEST_TMP/curlbin/curl"
  export PATH="$TEST_TMP/curlbin:$PATH"
  export INPUT_VERSION="latest"
  key="$(bash "$CACHE_KEY_SH" 2>"$TEST_TMP/err.txt")"
  assert_same "0" "$?"
  assert_contains "9.9.9" "$key"
  assert_not_contains "latest" "$key"
}

function test_missing_target_path_fails() {
  path_without_lmut
  export INPUT_PATH="does-not-exist"
  key="$(bash "$CACHE_KEY_SH" 2>"$TEST_TMP/err.txt")"
  code="$?"
  assert_not_same "0" "$code"
  assert_same "" "$key"
  assert_contains "does not exist" "$(cat "$TEST_TMP/err.txt")"
}

function test_missing_config_file_fails() {
  path_without_lmut
  export INPUT_CONFIG=".lua-mutation-test.toml"
  key="$(bash "$CACHE_KEY_SH" 2>"$TEST_TMP/err.txt")"
  code="$?"
  assert_not_same "0" "$code"
  assert_same "" "$key"
  assert_contains "not found" "$(cat "$TEST_TMP/err.txt")"
}

function test_invalid_version_fails() {
  path_without_lmut
  export INPUT_VERSION="bogus"
  bash "$CACHE_KEY_SH" >"$TEST_TMP/out.txt" 2>&1
  code="$?"
  assert_not_same "0" "$code"
  assert_contains "invalid version" "$(cat "$TEST_TMP/out.txt")"
}

function test_empty_inputs_produce_key() {
  path_without_lmut
  unset INPUT_PATH INPUT_TEST_COMMAND INPUT_CONFIG INPUT_TIMEOUT INPUT_ARGS
  unset RUNNER_OS RUNNER_ARCH
  key="$(bash "$CACHE_KEY_SH" 2>"$TEST_TMP/err.txt")"
  assert_same "0" "$?"
  lines="$(printf '%s\n' "$key" | wc -l | tr -d ' ')"
  assert_same "1" "$lines"
}

function test_file_target_path_supported() {
  path_without_lmut
  export INPUT_PATH="src/add.lua"
  key="$(bash "$CACHE_KEY_SH" 2>/dev/null)"
  assert_same "0" "$?"
  lines="$(printf '%s\n' "$key" | wc -l | tr -d ' ')"
  assert_same "1" "$lines"
}

function test_all_action_scripts_are_executable() {
  local script
  for script in "$REPO_ROOT"/scripts/*.sh; do
    if [[ ! -x "$script" ]]; then
      echo "not executable: $script" >&2
      exit 1
    fi
  done
  assert_exit_code "0"
}
