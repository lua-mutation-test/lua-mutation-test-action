#!/usr/bin/env bash
# Shared bashunit helpers (Track 1; Refs #1).
# Other tracks: APPEND helpers only, never modify existing ones.
# Everything lives inside the guard below so sourcing twice is a no-op.
# NOTE: CI runs `./lib/bashunit tests` without `-e`, so test files that
# need these helpers must `source` this file explicitly.

if [[ -z "${_LMUT_BOOTSTRAP_LOADED:-}" ]]; then
  _LMUT_BOOTSTRAP_LOADED=1

  # fresh_dir: print a new empty temp directory path.
  fresh_dir() {
    mktemp -d
  }

  # fresh_github_output: create an empty $GITHUB_OUTPUT file and export it.
  # Prints the file path.
  fresh_github_output() {
    local tmp
    tmp="$(mktemp)"
    : >"$tmp"
    export GITHUB_OUTPUT="$tmp"
    echo "$tmp"
  }

  # fresh_github_step_summary: create an empty $GITHUB_STEP_SUMMARY file
  # and export it. Prints the file path.
  fresh_github_step_summary() {
    local tmp
    tmp="$(mktemp)"
    : >"$tmp"
    export GITHUB_STEP_SUMMARY="$tmp"
    echo "$tmp"
  }

  # stub_lmut <dir>: install a fake `lmut` on PATH.
  # The stub records each argv on its own line in $LMUT_ARGV_FILE/argv,
  # prints a canned summary, and exits ${LMUT_EXIT:-0}.
  # Prints the fakebin dir. Requires: LMUT_ARGV_FILE exported by caller.
  stub_lmut() {
    local dir="${1:?Usage: stub_lmut <dir>}"
    local fakebin="$dir/fakebin"
    mkdir -p "$fakebin"
    cat >"$fakebin/lmut" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "${LMUT_ARGV_FILE:?}/argv"
echo "Mutation score: 87.5% (42 killed, 6 survived, 0 timed out)"
exit "${LMUT_EXIT:-0}"
STUB
    chmod +x "$fakebin/lmut"
    export PATH="$fakebin:$PATH"
    echo "$fakebin"
  }

  # stub_gh <dir>: install a fake `gh` that appends "$@" to $GH_ARGS_FILE/args.
  # Prints the fakebin dir. Requires: GH_ARGS_FILE exported by caller.
  stub_gh() {
    local dir="${1:?Usage: stub_gh <dir>}"
    local fakebin="$dir/fakebin"
    mkdir -p "$fakebin"
    cat >"$fakebin/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "${GH_ARGS_FILE:?}/args"
STUB
    chmod +x "$fakebin/gh"
    export PATH="$fakebin:$PATH"
    echo "$fakebin"
  }
fi
