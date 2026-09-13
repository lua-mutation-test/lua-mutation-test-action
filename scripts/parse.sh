#!/usr/bin/env bash
# Parse the lmut summary line and export step outputs.
# Usage: parse.sh <log-file>
# Appends mutation-score=, killed=, survived= to $GITHUB_OUTPUT.
set -euo pipefail

log_file="${1:?Usage: parse.sh <log-file>}"

if [[ ! -f "$log_file" ]]; then
  echo "error: log file not found: $log_file" >&2
  exit 1
fi

: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is not set}"

# README summary line, e.g.:
#   Mutation score: 87.5% (42 killed, 6 survived, 0 timed out)
# Last match wins so re-runs / retries parse the final summary.
line="$(grep -Eo 'Mutation score: [0-9]+(\.[0-9]+)?% \([0-9]+ killed, [0-9]+ survived' "$log_file" | tail -n 1 || true)"

if [[ -z "$line" ]]; then
  echo "error: could not parse mutation score from $log_file" >&2
  exit 1
fi

if [[ "$line" =~ Mutation\ score:\ ([0-9]+(\.[0-9]+)?)%\ \(([0-9]+)\ killed,\ ([0-9]+)\ survived ]]; then
  score="${BASH_REMATCH[1]}"
  killed="${BASH_REMATCH[3]}"
  survived="${BASH_REMATCH[4]}"
else
  echo "error: could not parse mutation score from $log_file" >&2
  exit 1
fi

{
  echo "mutation-score=$score"
  echo "killed=$killed"
  echo "survived=$survived"
} >>"$GITHUB_OUTPUT"
