#!/usr/bin/env bash
# Parse and validate a SemVer release tag (Refs #10).
#
# Usage: release.sh <tag>   (e.g. release.sh v1.2.3)
#
# Accepts vMAJOR.MINOR.PATCH with an optional -prerelease suffix
# (numeric components without leading zeros, per semver.org).
# Build metadata (+build) is rejected: '+' is URL-hostile in git tags
# and carries no precedence meaning.
#
# Appends to $GITHUB_OUTPUT:
#   tag         full tag as given (v1.2.3)
#   version     tag without the leading v (1.2.3)
#   prerelease  true when a -prerelease suffix is present, else false
#   float-tags  space-separated floating tags to move ("v1 v1.2");
#               empty for prereleases (they never move floats)
#
# Exits 0 on valid tags, 1 otherwise. No network.
set -euo pipefail

num='(0|[1-9][0-9]*)'
pre='(-[0-9A-Za-z.-]+)?'

tag="${1:-}"
if [[ -z "$tag" ]]; then
  echo "release: missing tag argument (expected e.g. v1.2.3)" >&2
  exit 1
fi
if [[ -z "${GITHUB_OUTPUT:-}" ]]; then
  echo "release: GITHUB_OUTPUT is not set" >&2
  exit 1
fi
if [[ ! "$tag" =~ ^v${num}\.${num}\.${num}${pre}$ ]]; then
  echo "release: invalid SemVer tag '$tag' (expected vMAJOR.MINOR.PATCH[-prerelease])" >&2
  exit 1
fi

version="${tag#v}"
major="${BASH_REMATCH[1]}"
minor="${BASH_REMATCH[2]}"
prerelease="false"
float_tags="v${major} v${major}.${minor}"
if [[ -n "${BASH_REMATCH[4]:-}" ]]; then
  prerelease="true"
  float_tags=""
fi

{
  echo "tag=${tag}"
  echo "version=${version}"
  echo "prerelease=${prerelease}"
  echo "float-tags=${float_tags}"
} >>"$GITHUB_OUTPUT"
