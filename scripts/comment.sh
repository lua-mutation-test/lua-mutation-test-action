#!/usr/bin/env bash
# Post (or update) a sticky PR comment with the mutation score via `gh api`.
# Sticky marker: <!-- lua-mutation-test-action -->
# Env: INPUT_COMMENT ('true' to enable), INPUT_SCORE, INPUT_KILLED,
#   INPUT_SURVIVED, GH_TOKEN, GITHUB_EVENT_NAME, GITHUB_REPOSITORY,
#   PR number via INPUT_PR_NUMBER or GITHUB_REF (refs/pull/<n>/merge).
set -euo pipefail

marker="<!-- lua-mutation-test-action -->"

if [[ "${INPUT_COMMENT:-false}" != "true" ]]; then
  exit 0
fi

if [[ "${GITHUB_EVENT_NAME:-}" != "pull_request" ]]; then
  echo "::warning::lua-mutation-test-action: PR comment skipped (not a pull_request event)"
  exit 0
fi

if [[ -z "${GH_TOKEN:-}" ]]; then
  echo "error: GH_TOKEN is not set (required for PR comments)" >&2
  exit 1
fi

: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is not set}"
score="${INPUT_SCORE:-unknown}"
killed="${INPUT_KILLED:-0}"
survived="${INPUT_SURVIVED:-0}"

pr="${INPUT_PR_NUMBER:-}"
if [[ -z "$pr" ]]; then
  ref="${GITHUB_REF:-}"
  if [[ "$ref" =~ ^refs/pull/([0-9]+)/merge$ ]]; then
    pr="${BASH_REMATCH[1]}"
  else
    echo "error: could not determine PR number (set INPUT_PR_NUMBER or run on a pull_request event)" >&2
    exit 1
  fi
fi

body="$(printf '%s\n## Mutation testing results\n\nMutation score: %s%% (%s killed, %s survived)\n' "$marker" "$score" "$killed" "$survived")"

existing_id="$(gh api "repos/${GITHUB_REPOSITORY}/issues/${pr}/comments" --paginate \
  --jq "[.[] | select(.body | contains(\"${marker}\")) | .id] | first // empty")"

if [[ -n "$existing_id" ]]; then
  gh api --method PATCH "repos/${GITHUB_REPOSITORY}/issues/comments/${existing_id}" \
    -f body="$body" >/dev/null
else
  gh api --method POST "repos/${GITHUB_REPOSITORY}/issues/${pr}/comments" \
    -f body="$body" >/dev/null
fi
