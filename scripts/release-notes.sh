#!/usr/bin/env bash
# scripts/release-notes.sh — Build categorized release notes for a tag.
#
# Calls GitHub's POST /releases/generate-notes to find the PR list for the
# range, resolves each PR's linked issue from `Closes #N` in the PR body,
# reads classification labels from the issue (or the PR if no linked
# issue), buckets by fixed precedence, and emits methodology-aligned
# markdown. Used by:
#   - cut-release.yml (initial draft notes)
#   - deploy-beta.yml (refresh notes on each beta push)
#   - release.yml (fallback when the draft was missing at publish)
#
# Categorization (label → section, first match by precedence):
#   bug          → 🐛 Fixes
#   dependencies → 📦 Dependencies
#   chore        → 🔧 Internal
#   feature      → ✨ Features
#   (no label)   → ✨ Features (default)
#
# The label set is curated by scripts/setup.sh. Issue templates pre-apply
# the right label at creation (bug_report.yml → bug; feature_request.yml
# → feature; task.yml → chore); Dependabot pre-applies `dependencies` to
# its PRs. See docs/process/release.md § Release notes.
#
# Header carries the build identifier (`vX.Y.Z+<short-sha>`) and a
# milestone link. Footer keeps GitHub's "Full Changelog" compare link.
#
# Each entry uses the linked issue's title as the primary copy — the
# issue is the unit of work and the title is the durable name (curated
# during refinement). The PR # is included for implementation
# traceability. PRs without a linked issue (Dependabot is the
# methodology's documented exception) fall back to the PR title.
#
# Usage:
#   scripts/release-notes.sh <tag> <target-ref>
#
# Inputs:
#   <tag>         the release tag, e.g. v1.2.3
#   <target-ref>  the ref the release points to, e.g. beta/v1.2.3 or a SHA
#
# Requires: gh authenticated; GH_TOKEN or GITHUB_TOKEN exported; jq.

set -euo pipefail

TAG="${1:?Missing tag (usage: release-notes.sh <tag> <target-ref>)}"
TARGET="${2:?Missing target ref (usage: release-notes.sh <tag> <target-ref>)}"
REPO="${GITHUB_REPOSITORY:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"

# Pull GitHub's auto-notes for the range. We use this only to discover
# the PR list (and the "Full Changelog" link) — categorization comes
# from labels, not from titles. An empty response is degenerate but
# valid (e.g. cutting a release with nothing yet merged into the new
# beta branch); we emit just header + footer in that case rather than
# failing the calling workflow step.
RAW=$(gh api -X POST "repos/$REPO/releases/generate-notes" \
  -f tag_name="$TAG" -f target_commitish="$TARGET" --jq .body 2>/dev/null || true)

if [[ -z "$RAW" ]]; then
  echo "::notice::generate-notes returned empty for $TAG @ $TARGET — emitting minimal body." >&2
fi

# Extract the PR number from each of the API's PR lines.
# API line shape:
#   * <title> by @<author> in https://github.com/<owner>/<repo>/pull/<N>
PR_NUMS=$(printf '%s\n' "$RAW" \
  | grep -oE 'https?://[^ ]+/pull/[0-9]+' \
  | sed -E 's|^.*/pull/||' || true)

# Bucket files: line per entry.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
: > "$TMP/features"
: > "$TMP/fixes"
: > "$TMP/internal"
: > "$TMP/dependencies"

# Resolve Closes/Fixes/Resolves keywords (case-insensitive, optional repo
# qualifier, GitHub-recognized form). Returns the first matched issue # or
# empty if none.
extract_closes_num() {
  local body="$1"
  printf '%s' "$body" \
    | grep -ioE '(close[sd]?|fix(e[sd])?|resolve[sd]?)[[:space:]]+#[0-9]+' \
    | head -1 \
    | grep -oE '[0-9]+' || true
}

# Categorize one PR. Reads labels from the linked issue when present,
# otherwise from the PR itself (Dependabot/no-issue exception).
classify_pr() {
  local pr_num="$1"

  local pr_json
  pr_json=$(gh api "repos/$REPO/pulls/$pr_num" 2>/dev/null) || return 0

  local pr_title pr_body pr_url
  pr_title=$(printf '%s' "$pr_json" | jq -r .title)
  pr_body=$(printf '%s' "$pr_json" | jq -r '.body // ""')
  pr_url=$(printf '%s' "$pr_json" | jq -r .html_url)

  local issue_num display_title display_link labels_json
  issue_num=$(extract_closes_num "$pr_body")

  if [[ -n "$issue_num" ]]; then
    local issue_json
    issue_json=$(gh api "repos/$REPO/issues/$issue_num" 2>/dev/null) || issue_json=""
    if [[ -n "$issue_json" ]]; then
      display_title=$(printf '%s' "$issue_json" | jq -r .title)
      local issue_url
      issue_url=$(printf '%s' "$issue_json" | jq -r .html_url)
      display_link="[#${issue_num}](${issue_url}), [PR #${pr_num}](${pr_url})"
      labels_json=$(printf '%s' "$issue_json" | jq -r '[.labels[].name] | join(",")')
    else
      # Linked-issue lookup failed; fall back to PR-only.
      display_title="$pr_title"
      display_link="[PR #${pr_num}](${pr_url})"
      labels_json=$(printf '%s' "$pr_json" | jq -r '[.labels[].name] | join(",")')
    fi
  else
    # No linked issue (e.g., Dependabot PR).
    display_title="$pr_title"
    display_link="[PR #${pr_num}](${pr_url})"
    labels_json=$(printf '%s' "$pr_json" | jq -r '[.labels[].name] | join(",")')
  fi

  # Precedence: bug > dependencies > chore > feature/(default).
  # First case-arm match wins, so order matters here.
  local bucket="features"
  case ",$labels_json," in
    *,bug,*)          bucket="fixes" ;;
    *,dependencies,*) bucket="dependencies" ;;
    *,chore,*)        bucket="internal" ;;
  esac

  printf '* %s (%s)\n' "$display_title" "$display_link" >> "$TMP/$bucket"
}

if [[ -n "$PR_NUMS" ]]; then
  while IFS= read -r pr_num; do
    [[ -z "$pr_num" ]] && continue
    classify_pr "$pr_num"
  done <<< "$PR_NUMS"
fi

# Trailing "Full Changelog" link the API includes — preserve verbatim
# so the comparison range stays accurate (GitHub computes it from the
# previous published tag).
FULL_CHANGELOG=$(printf '%s\n' "$RAW" | grep -E '^\*\*Full Changelog\*\*:' | tail -1 || true)

# Resolve the target's tip SHA for the build identifier.
SHA=$(gh api "repos/$REPO/commits/$TARGET" --jq .sha 2>/dev/null || true)
SHORT_SHA="${SHA:0:7}"

# Resolve the milestone number for the link.
MS_NUM=$(gh api "repos/$REPO/milestones?state=all" \
  --jq ".[] | select(.title==\"$TAG\") | .number" 2>/dev/null | head -1 || true)
MILESTONE_LINE=""
if [[ -n "$MS_NUM" ]]; then
  MILESTONE_LINE="**Milestone:** [${TAG}](https://github.com/${REPO}/milestone/${MS_NUM})"
fi

emit_section() {
  local heading="$1" file="$2"
  if [[ -s "$file" ]]; then
    printf '## %s\n\n' "$heading"
    cat "$file"
    printf '\n'
  fi
}

# Compose the final notes. Sections are emitted in priority-of-attention
# order (Features first because that's the typical bulk of a release;
# Fixes and Dependencies follow), each suppressed when empty.
{
  if [[ -n "$SHORT_SHA" ]]; then
    printf '**Build:** `%s+%s`\n' "$TAG" "$SHORT_SHA"
  fi
  [[ -n "$MILESTONE_LINE" ]] && printf '%s\n' "$MILESTONE_LINE"
  printf '\n'

  emit_section "✨ Features"     "$TMP/features"
  emit_section "🐛 Fixes"        "$TMP/fixes"
  emit_section "🔧 Internal"     "$TMP/internal"
  emit_section "📦 Dependencies" "$TMP/dependencies"

  [[ -n "$FULL_CHANGELOG" ]] && printf '%s\n' "$FULL_CHANGELOG"
}
