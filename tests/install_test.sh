#!/usr/bin/env bash
# Tests for scripts/install.sh (Track 1, Refs #1,#5).
# Pure functions (resolve_version, asset_name) run in an isolated
# `bash -c` subprocess so sourcing never leaks `set -euo pipefail`
# into the bashunit process. Network is faked with a PATH `curl` stub.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_SH="$REPO_ROOT/scripts/install.sh"

# run_fn <fn> [args...]: source install.sh in a clean subprocess and
# call a pure function. Prints stdout; propagates the exit code.
run_fn() {
  bash -c 'source "$1"; shift; "$@"' _ "$INSTALL_SH" "$@"
}

# make_fakebin: build a fakebin dir with a `curl` stub.
# - API calls (no `-o` flag) print {"tag_name": "$CURL_RELEASE_TAG"}.
# - Download calls (`-o <file>`) build a REAL tarball of $CURL_PAYLOAD_DIR
#   at <file> so `tar -xzf` in install.sh is exercised for real.
#   $CURL_PAYLOAD_FILE selects the file name packed (default `lmut`);
#   upstream ships `lua-mutation-test`. When CURL_PAYLOAD_EMPTY is set,
#   an empty tarball is built instead.
# - When CURL_FAIL is set, curl exits with that code instead.
# Requires: TEST_TMP exported. Prints the fakebin dir.
make_fakebin() {
  local fakebin="$TEST_TMP/fakebin"
  mkdir -p "$fakebin"
  cat >"$fakebin/curl" <<'STUB'
#!/usr/bin/env bash
out=""
prev=""
for a in "$@"; do
  if [[ "$prev" == "-o" ]]; then
    out="$a"
  fi
  prev="$a"
done
if [[ -n "${CURL_FAIL:-}" ]]; then
  echo "curl: (22) HTTP error" >&2
  exit "$CURL_FAIL"
fi
if [[ -z "$out" ]]; then
  printf '{"tag_name": "%s"}\n' "${CURL_RELEASE_TAG:-v9.9.9}"
elif [[ -n "${CURL_PAYLOAD_EMPTY:-}" ]]; then
  tar -czf "$out" --files-from /dev/null
else
  tar -czf "$out" -C "${CURL_PAYLOAD_DIR:?}" "${CURL_PAYLOAD_FILE:-lmut}"
fi
STUB
  chmod +x "$fakebin/curl"
  echo "$fakebin"
}

function set_up() {
  TEST_TMP="$(mktemp -d)"
  export TEST_TMP
  unset CURL_FAIL CURL_RELEASE_TAG CURL_PAYLOAD_DIR
}

function tear_down() {
  rm -rf "${TEST_TMP:?}"
}

function test_resolve_version_pinned_used_verbatim() {
  assert_same "0.1.0" "$(run_fn resolve_version "0.1.0")"
  assert_exit_code "0"
}

function test_resolve_version_strips_leading_v() {
  assert_same "0.1.0" "$(run_fn resolve_version "v0.1.0")"
  assert_exit_code "0"
}

function test_resolve_version_rejects_invalid() {
  run_fn resolve_version "banana" >/dev/null 2>&1
  assert_not_same "0" "$?"
  run_fn resolve_version "1.2" >/dev/null 2>&1
  assert_not_same "0" "$?"
  run_fn resolve_version "" >/dev/null 2>&1
  assert_not_same "0" "$?"
}

function test_resolve_version_invalid_message() {
  out="$(run_fn resolve_version "banana" 2>&1)"
  assert_contains "invalid version" "$out"
}

function test_resolve_version_latest_uses_api() {
  export CURL_RELEASE_TAG="v0.2.0"
  PATH="$(make_fakebin):$PATH" run_fn resolve_version "latest" >"$TEST_TMP/out.txt" 2>&1
  assert_exit_code "0"
  assert_same "0.2.0" "$(cat "$TEST_TMP/out.txt")"
}

function test_resolve_version_latest_api_failure() {
  export CURL_FAIL="22"
  PATH="$(make_fakebin):$PATH" run_fn resolve_version "latest" >"$TEST_TMP/out.txt" 2>&1
  assert_not_same "0" "$?"
  assert_contains "could not resolve" "$(cat "$TEST_TMP/out.txt")"
}

function test_asset_name_linux_x64() {
  assert_same "lua-mutation-test-x86_64-unknown-linux-gnu.tar.gz" "$(run_fn asset_name "Linux" "X64")"
  assert_exit_code "0"
}

function test_asset_name_linux_arm64() {
  assert_same "lua-mutation-test-aarch64-unknown-linux-gnu.tar.gz" "$(run_fn asset_name "Linux" "ARM64")"
  assert_exit_code "0"
}

function test_asset_name_macos_x64() {
  assert_same "lua-mutation-test-x86_64-apple-darwin.tar.gz" "$(run_fn asset_name "macOS" "X64")"
  assert_exit_code "0"
}

function test_asset_name_macos_arm64() {
  assert_same "lua-mutation-test-aarch64-apple-darwin.tar.gz" "$(run_fn asset_name "macOS" "ARM64")"
  assert_exit_code "0"
}

function test_asset_name_windows_errors() {
  out="$(run_fn asset_name "Windows" "X64" 2>&1)"
  code="$?"
  assert_not_same "0" "$code"
  assert_contains "Windows" "$out"
}

function test_asset_name_unknown_platform_errors() {
  run_fn asset_name "FreeBSD" "X64" >/dev/null 2>&1
  assert_not_same "0" "$?"
  run_fn asset_name "Linux" "MIPS" >/dev/null 2>&1
  assert_not_same "0" "$?"
}

function test_install_missing_runner_temp_errors() {
  out="$(env -u RUNNER_TEMP INPUT_VERSION="0.1.0" RUNNER_OS="Linux" RUNNER_ARCH="X64" GITHUB_PATH="$TEST_TMP/ghpath" bash "$INSTALL_SH" 2>&1)"
  code="$?"
  assert_not_same "0" "$code"
  assert_contains "RUNNER_TEMP" "$out"
}

function test_install_missing_github_path_errors() {
  out="$(env -u GITHUB_PATH INPUT_VERSION="0.1.0" RUNNER_OS="Linux" RUNNER_ARCH="X64" RUNNER_TEMP="$TEST_TMP" bash "$INSTALL_SH" 2>&1)"
  code="$?"
  assert_not_same "0" "$code"
  assert_contains "GITHUB_PATH" "$out"
}

function test_install_invalid_version_errors() {
  out="$(INPUT_VERSION="nope" RUNNER_OS="Linux" RUNNER_ARCH="X64" RUNNER_TEMP="$TEST_TMP" GITHUB_PATH="$TEST_TMP/ghpath" bash "$INSTALL_SH" 2>&1)"
  code="$?"
  assert_not_same "0" "$code"
  assert_contains "invalid version" "$out"
}

function test_install_unsupported_platform_errors() {
  out="$(INPUT_VERSION="0.1.0" RUNNER_OS="Windows" RUNNER_ARCH="X64" RUNNER_TEMP="$TEST_TMP" GITHUB_PATH="$TEST_TMP/ghpath" bash "$INSTALL_SH" 2>&1)"
  code="$?"
  assert_not_same "0" "$code"
  assert_contains "Windows" "$out"
}

function test_install_download_failure_propagates() {
  export CURL_FAIL="22"
  out="$(INPUT_VERSION="0.1.0" RUNNER_OS="Linux" RUNNER_ARCH="X64" RUNNER_TEMP="$TEST_TMP" GITHUB_PATH="$TEST_TMP/ghpath" PATH="$(make_fakebin):$PATH" bash "$INSTALL_SH" 2>&1)"
  code="$?"
  assert_not_same "0" "$code"
  assert_contains "ownload" "$out"
}

function test_install_success_end_to_end() {
  mkdir -p "$TEST_TMP/payload"
  printf '#!/usr/bin/env bash\necho lmut-stub\n' >"$TEST_TMP/payload/lmut"
  chmod +x "$TEST_TMP/payload/lmut"
  export CURL_PAYLOAD_DIR="$TEST_TMP/payload"
  : >"$TEST_TMP/ghpath"
  out="$(INPUT_VERSION="0.1.0" RUNNER_OS="Linux" RUNNER_ARCH="X64" RUNNER_TEMP="$TEST_TMP" GITHUB_PATH="$TEST_TMP/ghpath" PATH="$(make_fakebin):$PATH" bash "$INSTALL_SH" 2>&1)"
  code="$?"
  assert_same "0" "$code"
  assert_contains "0.1.0" "$out"
  bindir="$(cat "$TEST_TMP/ghpath")"
  assert_is_file "$bindir/lmut"
}

function test_install_latest_resolves_then_installs() {
  mkdir -p "$TEST_TMP/payload"
  printf '#!/usr/bin/env bash\necho lmut-stub\n' >"$TEST_TMP/payload/lmut"
  chmod +x "$TEST_TMP/payload/lmut"
  export CURL_PAYLOAD_DIR="$TEST_TMP/payload"
  export CURL_RELEASE_TAG="v0.2.0"
  : >"$TEST_TMP/ghpath"
  out="$(INPUT_VERSION="latest" RUNNER_OS="macOS" RUNNER_ARCH="ARM64" RUNNER_TEMP="$TEST_TMP" GITHUB_PATH="$TEST_TMP/ghpath" PATH="$(make_fakebin):$PATH" bash "$INSTALL_SH" 2>&1)"
  code="$?"
  assert_same "0" "$code"
  assert_contains "0.2.0" "$out"
  bindir="$(cat "$TEST_TMP/ghpath")"
  assert_is_file "$bindir/lmut"
}

function test_install_accepts_upstream_binary_name() {
  mkdir -p "$TEST_TMP/payload"
  printf '#!/usr/bin/env bash\necho lmut-stub\n' >"$TEST_TMP/payload/lua-mutation-test"
  chmod +x "$TEST_TMP/payload/lua-mutation-test"
  export CURL_PAYLOAD_DIR="$TEST_TMP/payload"
  export CURL_PAYLOAD_FILE="lua-mutation-test"
  : >"$TEST_TMP/ghpath"
  out="$(INPUT_VERSION="0.0.3" RUNNER_OS="Linux" RUNNER_ARCH="X64" RUNNER_TEMP="$TEST_TMP" GITHUB_PATH="$TEST_TMP/ghpath" PATH="$(make_fakebin):$PATH" bash "$INSTALL_SH" 2>&1)"
  code="$?"
  assert_same "0" "$code"
  bindir="$(cat "$TEST_TMP/ghpath")"
  assert_is_file "$bindir/lmut"
}

function test_install_empty_tarball_errors_clearly() {
  export CURL_PAYLOAD_EMPTY="1"
  : >"$TEST_TMP/ghpath"
  out="$(INPUT_VERSION="0.0.3" RUNNER_OS="Linux" RUNNER_ARCH="X64" RUNNER_TEMP="$TEST_TMP" GITHUB_PATH="$TEST_TMP/ghpath" PATH="$(make_fakebin):$PATH" bash "$INSTALL_SH" 2>&1)"
  code="$?"
  assert_not_same "0" "$code"
  assert_contains "lmut binary not found" "$out"
}
