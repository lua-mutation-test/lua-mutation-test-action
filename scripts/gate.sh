#!/usr/bin/env bash
# Fail the step when the mutation score is below INPUT_FAIL_UNDER.
# Usage: gate.sh <mutation-score>
# Empty/unset threshold (or 0) disables the gate: always pass.
set -euo pipefail

threshold="${INPUT_FAIL_UNDER:-}"
score="${1:?Usage: gate.sh <mutation-score>}"

if [[ -z "$threshold" ]]; then
  echo "mutation gate disabled (fail-under not set)"
  exit 0
fi

number_re='^[0-9]+(\.[0-9]+)?$'

if [[ ! "$threshold" =~ $number_re ]]; then
  echo "error: invalid fail-under threshold: '$threshold' (expected a number 0..100)" >&2
  exit 1
fi

if [[ ! "$score" =~ $number_re ]]; then
  echo "error: invalid mutation score: '$score' (expected a number 0..100)" >&2
  exit 1
fi

if ! awk -v t="$threshold" 'BEGIN { exit (t >= 0 && t <= 100) ? 0 : 1 }'; then
  echo "error: invalid fail-under threshold: '$threshold' (expected a number 0..100)" >&2
  exit 1
fi

if awk -v t="$threshold" 'BEGIN { exit (t == 0) ? 0 : 1 }'; then
  echo "mutation gate disabled (fail-under=0)"
  exit 0
fi

if awk -v s="$score" -v t="$threshold" 'BEGIN { exit (s >= t) ? 0 : 1 }'; then
  echo "mutation score ${score}% meets fail-under ${threshold}%"
  exit 0
else
  echo "mutation score ${score}% is below fail-under ${threshold}%" >&2
  exit 1
fi
