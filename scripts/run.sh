#!/usr/bin/env bash
# Run `lmut run` with action inputs and tee output to $RUNNER_TEMP/lmut.log.
# Env (action.yml convention): INPUT_PATH, INPUT_TEST_COMMAND, INPUT_CONFIG,
# INPUT_TIMEOUT, INPUT_ARGS. Optional flags are appended ONLY when non-empty.
set -euo pipefail

path="${INPUT_PATH:-.}"
test_command="${INPUT_TEST_COMMAND:-}"
config="${INPUT_CONFIG:-}"
timeout="${INPUT_TIMEOUT:-}"
extra_args="${INPUT_ARGS:-}"
log_file="${RUNNER_TEMP:-/tmp}/lmut.log"

if ! command -v lmut >/dev/null 2>&1; then
  echo "error: lmut not found on PATH. Did the install step run?" >&2
  exit 127
fi

args=("run" "$path")
if [[ -n "$test_command" ]]; then
  args+=("--test-command" "$test_command")
fi
if [[ -n "$config" ]]; then
  args+=("--config" "$config")
fi
if [[ -n "$timeout" ]]; then
  args+=("--timeout" "$timeout")
fi
if [[ -n "$extra_args" ]]; then
  # Deliberate word-splitting: INPUT_ARGS is a free-form flag string.
  # shellcheck disable=SC2206
  split=($extra_args)
  args+=("${split[@]}")
fi

lmut "${args[@]}" 2>&1 | tee "$log_file"
