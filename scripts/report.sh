#!/usr/bin/env bash
# Render job summary + check annotations from survivor lines on stdin.
# Usage: lmut ... | report.sh
# Survivor line format: path:line:col — desc
#   e.g. lua/init.lua:42:5 — changed == to ~=
# Env: INPUT_JOB_SUMMARY, INPUT_ANNOTATIONS ('true'/'false'),
#   INPUT_SCORE, INPUT_KILLED, INPUT_SURVIVED (headline),
#   GITHUB_STEP_SUMMARY, GITHUB_SHA, GITHUB_SERVER_URL, GITHUB_REPOSITORY.
set -euo pipefail

job_summary="${INPUT_JOB_SUMMARY:-false}"
annotations="${INPUT_ANNOTATIONS:-false}"
score="${INPUT_SCORE:-unknown}"
killed="${INPUT_KILLED:-0}"
survived_total="${INPUT_SURVIVED:-0}"

if [[ "$job_summary" == "true" ]]; then
  : "${GITHUB_STEP_SUMMARY:?GITHUB_STEP_SUMMARY is not set}"
fi

# Format: path:line:col, separator em-dash/en-dash/hyphen, description.
# An optional leading "Survived: " prefix is tolerated.
line_re='^([^:]+):([0-9]+):([0-9]+)[[:space:]]*(—|–|-)[[:space:]]*(.+)$'
max_annotations=10

paths=()
lines=()
descs=()
malformed=0

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ -z "$line" ]] && continue
  line="${line#Survived: }"
  if [[ "$line" =~ $line_re ]]; then
    path="${BASH_REMATCH[1]}"
    path="${path#./}"
    paths+=("$path")
    lines+=("${BASH_REMATCH[2]}")
    descs+=("${BASH_REMATCH[5]}")
  else
    malformed=$((malformed + 1))
    if [[ "$annotations" == "true" ]]; then
      echo "::warning::skipping malformed survivor line: $line"
    fi
  fi
done

count="${#paths[@]}"

blob_base=""
if [[ -n "${GITHUB_SERVER_URL:-}" && -n "${GITHUB_REPOSITORY:-}" && -n "${GITHUB_SHA:-}" ]]; then
  blob_base="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/blob/${GITHUB_SHA}"
fi

if [[ "$job_summary" == "true" ]]; then
  {
    echo "## Mutation testing results"
    echo ""
    echo "Mutation score: ${score}% (${killed} killed, ${survived_total} survived)"
    echo ""
    if [[ "$count" -eq 0 ]]; then
      echo "No surviving mutants — all mutants were killed."
    else
      echo "| File | Line | Mutation |"
      echo "| ---- | ---- | -------- |"
      for i in "${!paths[@]}"; do
        desc_escaped="${descs[$i]//|/\\|}"
        if [[ -n "$blob_base" ]]; then
          echo "| [${paths[$i]}](${blob_base}/${paths[$i]}#L${lines[$i]}) | ${lines[$i]} | ${desc_escaped} |"
        else
          echo "| ${paths[$i]} | ${lines[$i]} | ${desc_escaped} |"
        fi
      done
    fi
  } >>"$GITHUB_STEP_SUMMARY"
fi

if [[ "$annotations" == "true" ]]; then
  shown=0
  for i in "${!paths[@]}"; do
    if [[ "$shown" -ge "$max_annotations" ]]; then
      break
    fi
    echo "::warning file=${paths[$i]},line=${lines[$i]}::${descs[$i]}"
    shown=$((shown + 1))
  done
  if [[ "$count" -gt "$max_annotations" ]]; then
    rest=$((count - max_annotations))
    echo "::notice::... and ${rest} more surviving mutants (showing first ${max_annotations} of ${count})"
  fi
fi
