#!/usr/bin/env bash
# close-release.sh — Sweep a released milestone's issues to Project Status: Released.
#
# Run once, locally, after a release publishes. The `release.yml` workflow
# already publishes the GitHub Release, closes the milestone, and closes the
# milestone's issues — all repository-owned actions it performs with the
# built-in token. The one thing a workflow token cannot do is write a GitHub
# Project: Projects v2 are account-owned, out of a repo-scoped token's reach.
#
# This script fills that gap. It runs with your local `gh` session, which
# authenticates as you and therefore *can* write your Projects.
#
# Usage:
#   ./scripts/close-release.sh vX.Y.Z
#
# Requires `gh`, authenticated, with the `project` scope:
#   gh auth refresh -s project,read:project --hostname github.com
#
# Run it from inside a clone of the repo (the repo is inferred from the
# directory's git remote).

set -euo pipefail

red()    { printf "\033[31m%s\033[0m\n" "$*"; }
green()  { printf "\033[32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
die()    { red "ERROR: $*" >&2; exit 1; }

TAG="${1:-}"
[[ -n "$TAG" ]] || die "Usage: ./scripts/close-release.sh vX.Y.Z"
[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Version '$TAG' is not in vX.Y.Z form."

command -v gh >/dev/null 2>&1 || die "gh CLI is required. Install: https://cli.github.com"
gh auth status >/dev/null 2>&1 || die "gh is not authenticated. Run: gh auth login"

# Repo / owner, inferred from the current directory's git remote.
REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner) \
  || die "Not inside a GitHub repo clone, or gh cannot resolve the repo."
OWNER="${REPO%/*}"
NAME="${REPO#*/}"

# Resolve the milestone for this tag.
MS_NUMBER=$(gh api "repos/$REPO/milestones?state=all" \
  --jq ".[] | select(.title == \"$TAG\") | .number")
[[ -n "$MS_NUMBER" ]] || die "No milestone named '$TAG' in $REPO."

# Discover the repo's linked Project v2 and its Status field. Assumes one
# project per repo (the convention scripts/setup.sh establishes); takes the first.
PROJECT_JSON=$(gh api graphql -f query='
  query($owner: String!, $name: String!) {
    repository(owner: $owner, name: $name) {
      projectsV2(first: 1) {
        nodes {
          id
          field(name: "Status") {
            ... on ProjectV2SingleSelectField { id options { id name } }
          }
        }
      }
    }
  }' -f owner="$OWNER" -f name="$NAME")

PROJECT_ID=$(echo "$PROJECT_JSON" | jq -r '.data.repository.projectsV2.nodes[0].id // empty')
FIELD_ID=$(echo "$PROJECT_JSON" | jq -r '.data.repository.projectsV2.nodes[0].field.id // empty')
OPTION_ID=$(echo "$PROJECT_JSON" | jq -r '.data.repository.projectsV2.nodes[0].field.options[]? | select(.name == "Released") | .id')

[[ -n "$PROJECT_ID" ]] || die "No GitHub Project v2 linked to $REPO."
[[ -n "$FIELD_ID"   ]] || die "The Project has no 'Status' single-select field."
[[ -n "$OPTION_ID"  ]] || die "The 'Status' field has no 'Released' option."

# Sweep issues in the milestone. By release-close time release.yml has closed
# them, so query state=all.
ISSUES=$(gh api --paginate "repos/$REPO/issues?milestone=$MS_NUMBER&state=all" \
  --jq '.[] | select(.pull_request == null) | .number')
[[ -n "$ISSUES" ]] || { yellow "No issues in milestone '$TAG'. Nothing to sweep."; exit 0; }

swept=0
skipped=0
for N in $ISSUES; do
  ITEM_ID=$(gh api graphql -f query='
    query($owner: String!, $name: String!, $number: Int!) {
      repository(owner: $owner, name: $name) {
        issue(number: $number) {
          projectItems(first: 10) { nodes { id project { id } } }
        }
      }
    }' -f owner="$OWNER" -f name="$NAME" -F number="$N" \
    --jq ".data.repository.issue.projectItems.nodes[]? | select(.project.id == \"$PROJECT_ID\") | .id")

  if [[ -z "$ITEM_ID" ]]; then
    yellow "Issue #$N is not on the Project — skipping."
    skipped=$((skipped + 1))
    continue
  fi

  if gh api graphql -f query='
    mutation($project: ID!, $item: ID!, $field: ID!, $option: String!) {
      updateProjectV2ItemFieldValue(input: {
        projectId: $project, itemId: $item, fieldId: $field,
        value: { singleSelectOptionId: $option }
      }) { projectV2Item { id } }
    }' -f project="$PROJECT_ID" -f item="$ITEM_ID" \
       -f field="$FIELD_ID" -f option="$OPTION_ID" >/dev/null; then
    green "Issue #$N → Status: Released"
    swept=$((swept + 1))
  else
    red "Issue #$N — failed to set Status (continuing)."
    skipped=$((skipped + 1))
  fi
done

echo ""
green "Done — $swept issue(s) swept to Released for $TAG ($skipped skipped)."
