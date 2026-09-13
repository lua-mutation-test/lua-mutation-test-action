#!/usr/bin/env bash
# Compute a deterministic cache key for `lmut run`.
#
# Prints a single cache-key line to stdout. Config via env (action.yml
# convention): INPUT_PATH, INPUT_TEST_COMMAND, INPUT_CONFIG, INPUT_TIMEOUT,
# INPUT_ARGS, INPUT_VERSION, RUNNER_OS, RUNNER_ARCH.
#
# Key components: resolved lmut version (never the literal `latest`),
# runner OS/arch, contents of every `*.lua` file in the workspace
# (sources AND specs — over-hashing errs toward a safe cache miss),
# config file contents, and the scalar run inputs. Post-processing inputs
# (fail-under, comment, job-summary, annotations) do not affect `lmut.log`
# and are deliberately excluded.
#
# Hashing is portable: sha256sum on Linux, shasum -a 256 on macOS.
# File *contents* are hashed, never mtimes. Only scripts/install.sh may use
# the network: `resolve_version` is sourced from it for the `latest` case.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# install.sh never runs main() when sourced (it guards on BASH_SOURCE).
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/install.sh"

# sha256_stdin: print the hex digest of stdin.
sha256_stdin() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    echo "error: no sha256 tool found (need sha256sum or shasum)" >&2
    return 1
  fi
}

# sha256_file <file>: print the hex digest of a file's contents.
sha256_file() {
  local file="${1:?Usage: sha256_file <file>}"
  sha256_stdin <"$file"
}

# lmut_version: resolved X.Y.Z for the key. Prefers the installed binary
# (`lmut --version`); otherwise a pinned INPUT_VERSION verbatim (leading
# `v` stripped); otherwise resolves `latest` via the API (network).
lmut_version() {
  local requested="${INPUT_VERSION:-latest}"
  if command -v lmut >/dev/null 2>&1; then
    local out ver
    if out="$(lmut --version 2>/dev/null)"; then
      ver="$(echo "$out" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)"
      if [[ -n "${ver:-}" ]]; then
        echo "$ver"
        return 0
      fi
      out="$(printf '%s' "$out" | tr -d '[:space:]')"
      if [[ -n "$out" ]]; then
        echo "$out"
        return 0
      fi
    fi
  fi
  resolve_version "$requested"
}

# sanitize <s>: lowercase token safe for cache keys.
sanitize() {
  printf '%s' "${1:?Usage: sanitize <s>}" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9._-' '-'
}

target="${INPUT_PATH:-.}"
test_command="${INPUT_TEST_COMMAND:-}"
config="${INPUT_CONFIG:-}"
timeout="${INPUT_TIMEOUT:-}"
extra_args="${INPUT_ARGS:-}"
runner_os="${RUNNER_OS:-$(uname -s)}"
runner_arch="${RUNNER_ARCH:-$(uname -m)}"

if [[ ! -e "$target" ]]; then
  echo "error: target path does not exist: $target" >&2
  exit 1
fi

# Sorted per-file digests, then one digest over the list: deterministic and
# mtime-independent. The cache dir and .git are excluded so restores do not
# perturb the key.
files_hash="$(find . -type f -name '*.lua' -not -path './.git/*' -not -path './.lmut-cache/*' | LC_ALL=C sort | while IFS= read -r lua_file; do sha256_file "$lua_file"; done | sha256_stdin)"

config_hash="none"
if [[ -n "$config" ]]; then
  if [[ ! -f "$config" ]]; then
    echo "error: config file not found: $config" >&2
    exit 1
  fi
  config_hash="$(sha256_file "$config")"
fi

version="$(lmut_version)"

manifest="$(printf 'version=%s\nos=%s\narch=%s\npath=%s\ntest-command=%s\ntimeout=%s\nargs=%s\nconfig=%s\nfiles=%s\n' \
  "$version" "$runner_os" "$runner_arch" "$target" "$test_command" "$timeout" "$extra_args" "$config_hash" "$files_hash")"
digest="$(printf '%s\n' "$manifest" | sha256_stdin)"

echo "lmut-$(sanitize "$version")-$(sanitize "$runner_os")-$(sanitize "$runner_arch")-${digest}"
