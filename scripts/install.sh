#!/usr/bin/env bash
# Download the pinned `lmut` binary from GitHub Releases and add it to PATH.
# Env (action.yml convention): INPUT_VERSION, RUNNER_OS, RUNNER_ARCH,
# RUNNER_TEMP, GITHUB_PATH. Only this script may use the network.
#
# Pure functions (resolve_version, asset_name) are testable offline:
#   source scripts/install.sh; resolve_version latest; asset_name Linux X64
set -euo pipefail

LMUT_REPO="lua-mutation-test/lua-mutation-test"
LMUT_API_URL="https://api.github.com/repos/${LMUT_REPO}/releases/latest"

# resolve_version <version|latest>: print the bare X.Y.Z version.
# `latest` follows the newest GitHub Release tag (leading `v` stripped);
# a pinned version is used verbatim (leading `v` accepted, then stripped).
resolve_version() {
  local requested="${1:?Usage: resolve_version <version|latest>}"
  if [[ "$requested" == "latest" ]]; then
    local api_json tag
    if ! api_json="$(curl -fsSL "$LMUT_API_URL" 2>/dev/null)"; then
      echo "error: could not resolve 'latest' version from $LMUT_API_URL" >&2
      return 1
    fi
    tag="$(echo "$api_json" | grep -Eo '"tag_name": *"v?[0-9]+\.[0-9]+\.[0-9]+"' | head -n 1 | grep -Eo 'v?[0-9]+\.[0-9]+\.[0-9]+' | head -n 1 || true)"
    if [[ -z "${tag:-}" ]]; then
      echo "error: could not resolve 'latest' version from $LMUT_API_URL" >&2
      return 1
    fi
    echo "${tag#v}"
  elif [[ "$requested" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "${requested#v}"
  else
    echo "error: invalid version: '$requested' (expected 'latest' or 'X.Y.Z')" >&2
    return 1
  fi
}

# asset_name <os> <arch>: print the release tarball name for this runner.
# Linux/macOS x X64/ARM64 map to Rust target triples; Windows (not
# published upstream) and anything unknown fail with a clear error.
asset_name() {
  local os="${1:?Usage: asset_name <os> <arch>}"
  local arch="${2:?Usage: asset_name <os> <arch>}"
  local target=""

  case "$os" in
  Linux | linux)
    case "$arch" in
    X64 | x64 | x86_64 | amd64) target="x86_64-unknown-linux-gnu" ;;
    ARM64 | arm64 | aarch64) target="aarch64-unknown-linux-gnu" ;;
    *)
      echo "error: unsupported architecture: '$arch' (expected X64 or ARM64)" >&2
      return 1
      ;;
    esac
    ;;
  macOS | macos | Darwin | darwin)
    case "$arch" in
    X64 | x64 | x86_64 | amd64) target="x86_64-apple-darwin" ;;
    ARM64 | arm64 | aarch64) target="aarch64-apple-darwin" ;;
    *)
      echo "error: unsupported architecture: '$arch' (expected X64 or ARM64)" >&2
      return 1
      ;;
    esac
    ;;
  Windows | windows)
    echo "error: Windows runners are not supported (no lmut binary published upstream)" >&2
    return 1
    ;;
  *)
    echo "error: unsupported OS: '$os' (expected Linux or macOS)" >&2
    return 1
    ;;
  esac

  echo "lua-mutation-test-${target}.tar.gz"
}

main() {
  local version="${INPUT_VERSION:-latest}"
  : "${RUNNER_TEMP:?RUNNER_TEMP is not set (expected the GitHub runner temp dir)}"
  : "${GITHUB_PATH:?GITHUB_PATH is not set (expected the GitHub PATH file)}"
  local runner_os="${RUNNER_OS:?RUNNER_OS is not set}"
  local runner_arch="${RUNNER_ARCH:?RUNNER_ARCH is not set}"

  local resolved asset tag url archive destdir bindir
  resolved="$(resolve_version "$version")"
  asset="$(asset_name "$runner_os" "$runner_arch")"
  tag="v${resolved}"
  url="https://github.com/${LMUT_REPO}/releases/download/${tag}/${asset}"
  archive="${RUNNER_TEMP}/${asset}"
  destdir="${RUNNER_TEMP}/lmut-${resolved}"

  mkdir -p "$destdir"
  echo "Downloading lmut ${tag} (${asset})..."
  if ! curl -fsSL -o "$archive" "$url"; then
    echo "error: download failed: $url" >&2
    return 1
  fi
  tar -xzf "$archive" -C "$destdir"

  # Upstream tarballs name the binary `lua-mutation-test`, not `lmut`.
  # Accept either and normalize to `$bindir/lmut` on PATH.
  local found_path
  found_path="$(find "$destdir" \( -name 'lmut' -o -name 'lua-mutation-test' \) -type f -print | head -n 1 || true)"
  if [[ -z "${found_path:-}" ]]; then
    echo "error: lmut binary not found in $archive (looked for 'lmut' and 'lua-mutation-test')" >&2
    return 1
  fi
  chmod +x "$found_path"
  bindir="${destdir}/bin"
  mkdir -p "$bindir"
  cp "$found_path" "${bindir}/lmut"
  echo "$bindir" >>"$GITHUB_PATH"
  echo "Installed lmut ${resolved} to ${bindir}/lmut"
}

if [[ "${BASH_SOURCE[0]:-}" == "$0" ]]; then
  main "$@"
fi
