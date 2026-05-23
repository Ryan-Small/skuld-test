# Process: Release

## Purpose

Defines the release ceremony — how a `beta/vX.Y.Z` branch is cut, worked through, promoted to `main`, and published as a tagged GitHub Release. Complements [Issue Lifecycle](./issue-lifecycle.md) and [Environments](./environments.md): the issue lifecycle defines how individual issues flow through the beta branch; environments define how branches map to deployment targets; this document defines the release ceremony itself.

## Versioning

Releases follow **Semantic Versioning** (`X.Y.Z`):

| Bump | Trigger |
|---|---|
| **Major** (`X`) | Breaking change to a consumer contract — removed/renamed public API, incompatible schema change, removed configuration key |
| **Minor** (`Y`) | Additive change — new feature, new optional configuration, new behavior that does not break existing consumers |
| **Patch** (`Z`) | Bug fix only — no behavior change beyond the fix; no new functionality |

The tech lead picks the bump based on the assembled release's content. If a release combines multiple change categories, the highest applicable bump wins (one breaking change in a release of new features = major).

**Naming convention.** All Git artifacts for a release carry the `v` prefix on the version number, for cross-artifact consistency: the branch is `beta/vX.Y.Z`, the milestone is `vX.Y.Z`, and the tag is `vX.Y.Z`. The `v` after `beta/` is intentionally redundant — one mental model maps unambiguously across all three artifacts, and workflows that bridge them (e.g., `release.yml`) don't need prefix munging.

**Build identifier.** The deployed artifact's version string is `vX.Y.Z+<short-sha>` — the release version plus SemVer build metadata identifying the exact commit running. This is the form exposed by `--version`, `/health`, `/version`, log headers, metric labels, and Docker image tags (alongside `:vX.Y.Z` and `:latest`).

- The `+` is SemVer's canonical build-metadata separator; build metadata does not affect version precedence (`v1.2.3+abc` and `v1.2.3+def` compare equal as releases).
- `<short-sha>` is the 7-character abbreviated commit SHA (`git rev-parse --short HEAD`). Projects with collision concerns at scale can use longer SHAs; the format remains `vX.Y.Z+<sha>` regardless of length.
- Stamping happens at build time in the CI pipeline; the implementation lives in the project's IaC, not in this document.

Rationale: tags point to a SHA, but that mapping lives only in Git. When you're looking at a running container, a log line, or a metric, the deployed-artifact version is the only thing in front of you. Embedding the SHA suffix removes the need to trust an external lookup to answer "what's running?" The Git artifacts (branch, milestone, tag) stay clean — they identify scope, not builds.

## Cutting a release

The tech lead decides when to cut a release — on-demand, not on a fixed cadence. Triggers include accumulated `Queued` work reaching a coherent scope, an urgent fix needing to ship (hotfix), or stakeholder readiness for a new feature set.

**Determine the version** first — per [Versioning](#versioning), pick the smallest bump that accommodates the highest change category in scope.

Then run the **`Cut Release`** workflow (`cut-release.yml`): Actions tab → Cut Release → Run workflow → enter the version (`vX.Y.Z`). It performs the mechanical steps:

1. Creates the `beta/vX.Y.Z` branch from `main`. Pushing it creates the version-stamped beta environment (see [Environments § Beta](./environments.md#beta)).
2. Creates the GitHub Milestone `vX.Y.Z` — matches the tag exactly, so cross-artifact lookup (e.g., `release.yml` matching the milestone to the release tag) is a direct string match.
3. Creates a **draft GitHub Release** `vX.Y.Z`. Its notes start sparse and are refreshed by `deploy-beta.yml` as issue PRs merge into the beta branch — the draft is a live "what's in `vX.Y.Z` so far" view throughout the cycle, editable at any time before it publishes.

One step stays manual: **tag candidate issues with the `vX.Y.Z` milestone.** That is a scope decision, not a mechanical one. Issues without an explicit target may be added later as scope settles.

**Milestone tagging is intentionally manual and load-bearing.** It is the tech lead's scope declaration — *which* issues are in this release. The downstream consequences split along that line: release **notes** track what *merged* into the beta branch regardless of milestone (factual record of merged PRs), while release **issue closing** acts only on the *milestone* (your declared scope). A PR that merges into the beta branch without its issue being scoped into the milestone shows in notes but does not auto-close its issue at release; manual milestone tagging overrides any `Closes #N` claim a PR might make. The milestone is the source of truth for what auto-closes.

The beta branch exists from this point until promoted to `main`. Issue branches merging into it pick up the version stamp automatically via the milestone.

## Working through the release

Issue branches merge into `beta/vX.Y.Z` as their PRs are reviewed and approved (per [Issue Lifecycle § Stage 3](./issue-lifecycle.md#stage-3--implementation)). Each merge updates the beta environment and refreshes the draft Release's notes.

Stakeholders perform UAT against the beta environment as the release approaches readiness. Findings during UAT are pre-release defects (see [Issue Lifecycle § Defect handling](./issue-lifecycle.md#defect-handling-pre-release-vs-post-release)) — they return the originating issue to active work rather than spawning new bug tickets. The issue is still open (it does not close until release), so its Project `Status` simply moves back.

The release is ready to promote when:

- All milestone issues are `Merged`.
- UAT outcomes are recorded against the beta environment.
- Smoke checks (if configured per [Environments § Beta](./environments.md#beta)) pass on the latest beta deploy.

## Promoting to main

The tech lead opens a PR titled `Release vX.Y.Z` from `beta/vX.Y.Z` to `main`, filled out with the release PR template ([`PULL_REQUEST_TEMPLATE/release-pr.md`](../../.github/PULL_REQUEST_TEMPLATE/release-pr.md)). The release PR is the deploy-approval artifact — it captures release scope, UAT outcome, aggregated breaking changes, risk assessment, and smoke-check status; see the template for the field structure.

A CODEOWNER reviews and approves the PR. Per [Environments § Prod](./environments.md#prod), this review event *is* the production deploy approval; there is no separate post-merge gate.

The PR merges via squash to `main` (linear history is enforced by branch protection). Production deploy follows automatically.

## Publication

Publication is a two-workflow chain that fires after the `beta/v* → main` merge:

1. **`deploy-prod.yml`** runs on push to `main`. It deploys to production via the consumer-supplied IaC (the template ships a placeholder step; replace with your invocation — terraform, kubectl, aws-cli, serverless, etc.).
2. **`release.yml`** runs on `Deploy` workflow success. It looks up the PR for the merged commit; when the source branch was `beta/v*`, it:
   - **Publishes the draft GitHub Release** for `vX.Y.Z` — the draft created at cut and kept current through the cycle, flipped from draft to published with its tag pointed at the merge commit. Its notes are preserved as-is, not regenerated. If no draft exists (release cut without `cut-release.yml`), it creates the Release fresh with auto-generated notes.
   - **Closes the matching milestone** (`vX.Y.Z`).
   - **Closes the milestone's issues**, commenting `Released in vX.Y.Z` on each (see [Closing the release](#closing-the-release)).

   For non-release commits (direct main push, hotfix from another branch type), `release.yml` no-ops with a notice.

This chain enforces the methodology's definition of `Released` — *merged to `main` AND deployed to production* (see [Issue Lifecycle § State machine](./issue-lifecycle.md#state-machine)). A failed deploy leaves the milestone open and the Release unpublished; retry the deploy via `workflow_dispatch` on `deploy-prod.yml`, and on success the chain resumes. `release.yml` is idempotent — if a *published* Release for the tag already exists, it skips with a notice rather than failing.

Release notes can be curated **before** publication — the draft Release is editable throughout the beta cycle, so polishing happens continuously with no rushed pre-publish window. Post-publish edits remain possible too; GitHub preserves the edit history on the Release for audit.

The published release is the design output of record for `vX.Y.Z`. The tag and Release together form the durable, externally-citable artifact; the release PR itself becomes part of the audit trail.

## Release notes

Notes are built by `scripts/release-notes.sh`, invoked from three workflows (`cut-release.yml` for the initial draft, `deploy-beta.yml` on every beta push, `release.yml`'s fallback when no draft exists). The script discovers PRs via GitHub's `POST /releases/generate-notes` API, resolves each PR's linked issue from a `Closes #N` keyword in the PR body, and categorizes by the issue's labels (PR labels are used only when a PR has no linked issue — the Dependabot exception).

**Structure:**

```
**Build:** `vX.Y.Z+<short-sha>`
**Milestone:** [vX.Y.Z](.../milestone/N)

## ✨ Features
* <issue-title> ([#N](...), [PR #M](...))
...

## 🐛 Fixes
* ...

## 🔧 Internal
* ...

## 📦 Dependencies
* ...

**Full Changelog:** vX.Y.(Z-1)...vX.Y.Z
```

Sections with no entries are omitted entirely.

**Categorization** is driven by the curated label set on the issue (see [Issue Lifecycle § Labels](./issue-lifecycle.md#labels)). Precedence is first-match-wins:

| Label | Section |
|---|---|
| `bug` | 🐛 Fixes |
| `dependencies` | 📦 Dependencies |
| `chore` | 🔧 Internal |
| `feature` *or* no label | ✨ Features |

Each entry uses the linked **issue's** title (the durable, refinement-curated name) rather than the PR title. The PR # is included as the implementation traceability link. PRs without a linked issue (Dependabot is the documented methodology exception) fall back to the PR's own title and labels.

**Curating before publishing.** The draft is editable at any point in the cycle. If a release note needs a stakeholder-facing rewording, edit the draft directly — `deploy-beta.yml`'s refresh will overwrite the body on the next beta push, so do final polishing after the last merge to beta.

## Closing the release

`release.yml` runs automatically when the production deploy succeeds (see [Publication](#publication)). It publishes the GitHub Release, closes the milestone, and **closes every open issue in the milestone** (commenting `Released in vX.Y.Z` on each) — all repository-owned actions the workflow's built-in token can perform.

Two steps remain, run locally by the tech lead:

1. **Sweep Project `Status` → `Released`.** Run `./scripts/close-release.sh vX.Y.Z` from a clone of the repo. It sets the `Status` field of the milestone's issues to `Released`. This is local rather than part of `release.yml` because GitHub Projects v2 are account-owned — a workflow's built-in `GITHUB_TOKEN` cannot write them, whereas your authenticated `gh` session can. Requires `gh` with the `project` scope: `gh auth refresh -s project,read:project --hostname github.com`.
2. **Delete the beta branch** (`beta/vX.Y.Z`). Its beta environment is torn down per [Environments § Beta](./environments.md#beta).

If the workflow logs a warning that no open milestone matched the tag, close the milestone manually in the GitHub UI — usually a sign the milestone was misnamed or already closed.

**Why issues close at release, not at beta merge.** An issue's PR merges into a `beta/v*` branch, not the default branch — so GitHub's `Closes #N` auto-close (which only fires on default-branch merges) does not apply. That is deliberate: an issue whose code is in beta but not yet shipped is not done — it stays open through UAT and closes only when the release reaches production. `release.yml` performs that close.

## Hotfixes

Hotfixes follow the same convention — a `beta/vX.Y.Z` branch with a patch-bump version (e.g., `beta/v1.2.4` when `v1.2.3` is the current production version). The runbook above applies in full; the differences are operational, not structural:

- **Scope is typically one or two issues** — a single critical fix, possibly with a tightly-scoped accompanying change.
- **UAT may be abbreviated** — smoke-check pass on beta plus targeted stakeholder verification of the specific fix, rather than full regression UAT.
- **Cadence is faster** — the hotfix may go from cut to published in hours rather than the usual release cycle; the ceremony (PR, review, tag, GitHub Release) is unchanged.

Hotfixes are always cut from `main`, never from another open beta branch.

## Parallel releases

Multiple `beta/vX.Y.Z` branches may be open at once (see [Environments § Beta](./environments.md#beta)). Coordination notes:

- **Promote in version order.** The older release merges to `main` first. If `beta/v1.2.0` and `beta/v1.3.0` are both open, `v1.2.0` merges first; `v1.3.0` then rebases on the updated `main` before its own promotion.
- **Each issue belongs to exactly one milestone.** If a fix is needed in both releases, cherry-pick rather than dual-milestoning.
- **Hotfixes interrupt feature releases.** A hotfix cut from `main` while a feature `beta/*` is open promotes immediately; the feature branch rebases on the updated `main` afterward.

## Audit trail

| Audit concern | Evidence |
|---|---|
| Review evidence | Release PR review on `beta/* → main` (deploy approval); UAT outcomes recorded against the beta environment |
| Design outputs | Published GitHub Release at `vX.Y.Z` with curated notes; merged release PR as source-of-truth artifact |
| Control of nonconforming outputs | Post-release defects filed as bug tickets only after publication; pre-release defects return original issues to active work |
| Control of documented information | Milestone closure marks the release scope as complete; the tag and GitHub Release are immutable artifacts; the deployed-artifact version stamp (`vX.Y.Z+<sha>`) provides forensic traceability from runtime back to source commit |

## Open questions / future work

- **Rollback procedure.** Out of scope for the initial runbook; warrants its own document once the production deploy pipeline matures.

## Changelog

- 2026-05-21: Initial draft. Codifies the release ceremony (versioning, cutting, working through, promoting, publishing, closing) previously implicit in `issue-lifecycle.md`'s "release event" terminology. Defaults: SemVer with `vX.Y.Z` tags, on-demand cadence, GitHub Milestone per release, GitHub auto-generated release notes curated by the tech lead, hotfixes share the release-branch convention.
- 2026-05-21: Added `release-draft.yml` (auto-creates draft GitHub Release on `release/* → main` merge) and `release-finalize.yml` (closes the matching milestone on `release: published`) to the seed. Updated Publication and Closing sections accordingly. The `release-publish` open-question entry was split — draft creation and milestone closure are now implemented; Project Status transition remains future work as a `release-finalize.yml` extension.
- 2026-05-21: Adopted v-prefix convention across all Git artifacts — branches renamed from `release/X.Y.Z` to `release/vX.Y.Z`, milestones renamed from `X.Y.Z` to `vX.Y.Z`. Tags were already `vX.Y.Z`. Rationale: single mental model maps unambiguously across branch/milestone/tag, and bridging workflows do not need prefix munging. The redundant `v` after `release/` is accepted as the cost of consistency.
- 2026-05-21: Combined `release-draft.yml` and `release-finalize.yml` into a single `release.yml` that publishes on merge (no draft step) and closes the milestone in the same run. Dropped the curation-as-policy framing — auto-generated notes publish immediately; post-publish edits are allowed and audit-tracked via GitHub's edit history. If pre-publish curation matters later, the workflows can be split back apart (see Open questions). Updated Publication and Closing sections accordingly.
- 2026-05-21: Added Build identifier subsection to Versioning, documenting the `vX.Y.Z+<short-sha>` SemVer build-metadata convention for deployed artifacts. Skuld defines the policy; the consuming project's IaC implements the stamping. Cross-referenced from `environments.md`. Expanded the audit-trail "Control of documented information" row to name the deployed-artifact version stamp as forensic-traceability evidence.
- 2026-05-22: Split publication into a `deploy.yml` + `release.yml` chain. `deploy.yml` triggers on push to `main` and runs IaC deploy (placeholder step ships with the template). `release.yml` now triggers on `Deploy` workflow success — it looks up the source PR for the merge, derives the tag, and publishes the GitHub Release + closes the milestone *only* when production has the code. Makes the methodology's `Released` definition ("merged to `main` AND deployed to production") concrete in workflow semantics rather than just doc text. Added idempotency guard in `release.yml` so retries (via `workflow_dispatch` on `deploy.yml`) are safe.
- 2026-05-22: Renamed release branches from `release/v*` to `beta/v*` for naming consistency with the `beta` deployment environment. The release ceremony itself, release PR title (`Release vX.Y.Z`), GitHub Release artifact, tag, and milestone naming are unchanged — only the branch is renamed. Updated all branch references in this doc; workflows (`deploy-beta.yml`, `deploy-alpha.yml`, `release.yml`) updated in parallel.
- 2026-05-22: Documentation-consistency pass. Fixed two stale workflow references — `release-finalize.yml` → `release.yml` in Cutting a release, and `deploy.yml` → `deploy-prod.yml` in Publication. Corrected the `PULL_REQUEST_TEMPLATE.md` link in Promoting to main to the split `PULL_REQUEST_TEMPLATE/issue-pr.md` path. Consolidated the Promoting-to-main PR-description bullets into a pointer to `release-pr.md` (the bullets duplicated the template, which postdated them).
- 2026-05-22: Implemented release-close issue handling, split along the resource-ownership boundary. A first attempt put the Project `Status → Released` sweep in `release.yml` gated on a `PROJECT_TOKEN` secret; testing then confirmed neither a GitHub App installation token nor a workflow's `GITHUB_TOKEN` can write user-owned Projects v2 (`Resource not accessible by integration`). Final design: `release.yml` closes the milestone's issues on release publish (issues are repository-owned — built-in token suffices, no secret); the Project `Status → Released` sweep is a local `close-release.sh` script run with the operator's `gh` session. Issues now close at `Released`, not at beta-branch merge — they stay open through beta UAT. Closing section rewritten; the `Merged → Released` open-questions item removed.
- 2026-05-22: Added the `cut-release.yml` workflow and reworked publication around a draft Release. `cut-release.yml` (`workflow_dispatch`) creates the `beta/vX.Y.Z` branch, the milestone, and a **draft GitHub Release**. `deploy-beta.yml` refreshes the draft's notes on every beta-branch push, so the draft is a live, editable view of the release throughout the cycle. `release.yml` now publishes that draft (preserving its notes) rather than creating the Release fresh, with a create-fresh fallback if no draft exists. Resolved and removed two open-questions items — `release-cut` workflow and pre-publish curation. Release-notes shaping (`.github/release.yml`) was considered for this update but dropped and re-scoped: it categorizes notes by PR label, and the methodology keeps no labels.
- 2026-05-23: Made the milestone-as-scope-decision rationale explicit in `Cutting a release`. Milestone tagging is intentionally manual and load-bearing: release notes track what merged into the beta branch regardless of milestone (factual record), while release-time issue closing acts only on the milestone (the tech lead's declared scope). A PR that merges into beta without its issue being scoped into the milestone shows in notes but won't auto-close its issue — manual milestone tagging overrides any `Closes #N` claim a PR might make.
- 2026-05-23: Moved release-related scripts under `scripts/`. `close-release.sh` is now `scripts/close-release.sh`; updated all invocation references in this doc and elsewhere. No behavior change.
- 2026-05-23: Added a `Release notes` section. Notes are now built by `scripts/release-notes.sh` (invoked from `cut-release.yml`, `deploy-beta.yml`, and `release.yml`'s fallback path) and categorized by label: 🐛 Fixes / 📦 Dependencies / 🔧 Internal / ✨ Features, with fixed first-match-wins precedence in that order. Entries lead with the linked issue's title (resolved from `Closes #N` in the PR body) rather than the PR title — issues are the durable, refinement-curated names; PRs are the implementation artifact. Header carries the build identifier (`vX.Y.Z+<short-sha>`) and a milestone link. Resolved and removed the Open-Questions item that had blocked release-notes shaping on the "no labels" rule — see [Issue Lifecycle § Labels](./issue-lifecycle.md#labels) for the carve-out (labels are now used for content classification only, distinct from workflow-state metadata which remains on Project fields).
