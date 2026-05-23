# Process: Environments

## Purpose

Defines the environments this project deploys to, how branches map to them, and when each environment receives traffic. Complements [Issue Lifecycle](./issue-lifecycle.md) — branching policy lives there, environment policy lives here.

This document is infra-neutral. Policy (what environments exist, what they are for, how they are populated) lives here. Mechanism (which cloud, which orchestrator, how ephemeral environments are provisioned) lives in the project's IaC.

## Environment table

| Environment | Branch | Deploy trigger | Lifetime | Audit role |
|---|---|---|---|---|
| Prod | `main` | Push (after beta-branch merge) | Always-on | `Released` state evidence |
| Beta | `beta/vX.Y.Z` | Push (branch creation + each issue-branch merge) | Lifetime of the beta branch | Pre-release UAT evidence |
| Alpha | `issue/<N>-<slug>` | PR open + each push | PR open through PR close/merge | Pre-merge developer/tech-lead verification |

## GitHub Environment objects vs. deployed instances

GitHub's Environments feature provides per-environment **policy holders** — objects that carry deployment branch rules, required reviewers, wait timers, and environment-scoped secrets. These are distinct from the **deployed instances** themselves (the actual running services, hostnames, infrastructure resources).

In this project's model:

- A single `prod` GitHub Environment is the policy holder for production deploys (branch rule: `main` only). The deployed production service (`<app>` hostname, the resources behind it) is provisioned by the IaC.
- A single `beta` GitHub Environment is the policy holder for all beta-branch deploys (branch rule: `beta/*`). The actual deployed instances are version-stamped (`v1.2.0.beta.<app>`, `v1.3.0.beta.<app>`) and provisioned per beta branch by the IaC. One GitHub Environment maps to many version-stamped deployed instances when parallel releases are open.
- Alpha environments are typically dynamic — a fresh GitHub Environment named `alpha-pr-<N>` per open PR, created by the alpha deploy workflow on PR open and torn down on PR close.

`scripts/setup.sh` creates the `prod` and `beta` GitHub Environment policy holders. Deployed-instance naming, provisioning, and teardown live in the project's IaC.

## Prod

`main` deploys to a single always-on production service. Production is the only environment where the `Released` state of an issue takes effect — the audit boundary in [Issue Lifecycle § Defect handling](./issue-lifecycle.md#defect-handling-pre-release-vs-post-release) is "merged to `main` *and* deployed to production." Bugs found in production are post-release defects; bugs found anywhere else are not.

**Deploy approval.** The PR review event on the `beta/* → main` merge *is* the deploy approval; there is no separate post-merge gate. The deploy follows the merge automatically, and the PR review record is the review evidence for the deploy.

**Build identifier.** Production services expose `vX.Y.Z+<short-sha>` as their reported version (see [Release § Versioning](./release.md#versioning)) — the release version plus the commit SHA running. The same convention applies to beta and alpha environments; production just has the highest stakes for runtime-to-source traceability.

## Beta

Each `beta/vX.Y.Z` branch gets its own beta environment. Beta is where pre-release UAT happens — stakeholder validation of the assembled release before promotion to `main`. Findings here are pre-release defects (incomplete work on the underlying issues), not new bug tickets.

**Parallel releases.** Multiple `beta/*` branches may be open at once; each gets its own beta environment. Environment names should version-stamp the release (e.g., `v1.2.0.beta.<app>`, `v1.3.0.beta.<app>`) so UAT evidence is unambiguously tied to a specific release.

**Smoke checks (optional gate).** When automated smoke tests exist, run them against the beta environment via CI; if implemented, configure branch protection on `main` to require the smoke-check status before allowing the `beta/* → main` merge. The check result is review evidence alongside UAT outcomes. This gate is not mandated — without a meaningful smoke surface, UAT alone is the validation event.

## Alpha

Each open PR on an `issue/*` branch gets an ephemeral alpha environment — deployed on PR open, updated on each push, torn down on PR close or merge. Alpha supports the "Verify before declaring done" discipline without consuming beta capacity for not-yet-merged work.

**Preferred over a long-lived dev environment.** A `develop` branch with a shared dev cluster is an allowed substitution when ephemeral provisioning is too expensive, but it adds a merge target that does not exist in the issue-branch model and muddies the `main = released` invariant the audit trail depends on. Default to per-PR alpha environments; substitute only when cost forces it.

**Data layer.** Alpha environments need data. The default is a **shared development database** — cheapest, fastest spin-up, sufficient for most changes. When data-layer conflicts are frequent (concurrent migrations, destructive schema changes, multi-tenant corruption risk), provision per-PR databases instead. The choice and its provisioning live in the project's IaC, not in this document.

## Example realization

No orchestrator is prescribed. For a project on AWS ECS, a typical realization is:

- A long-lived ECS service for production behind the production ALB.
- One ECS service per active `beta/*` branch behind a shared pre-production ALB, host-routed by version (`v1.2.0.beta.<app>`).
- One ECS service per open issue-branch PR behind the same pre-production ALB, host-routed by PR (`pr-<N>.<app>`).
- A shared dev RDS instance reached by both beta and alpha services.
- CI (e.g., GitHub Actions) triggers deploys on push to `main` and `beta/*`, and on PR open/push for `issue/*`; teardown on PR close/merge and on beta-branch merge.

## Open questions / future work

- **Alpha-env staleness sweep.** Alpha environments are torn down on PR close/merge; long-open PRs whose alpha environments remain live and accrue cost are not yet addressed. Likely shape: a scheduled workflow comments on PRs whose alpha environment has been live past a configurable idle threshold (suggest 14–30 days), prompting close-or-keep. The policy knob is defined here; the project's IaC implements the workflow.

## Changelog

- 2026-05-21: Added `GitHub Environment objects vs. deployed instances` section explicitly distinguishing the policy-holder layer (created by `setup.sh`) from the version-stamped deployed instances (provisioned by IaC).
- 2026-05-22: Renamed `Preview` to `Alpha` throughout to match the `alpha/beta/prod` progression that the deploy workflows now follow (`deploy-alpha.yml`, `deploy-beta.yml`, `deploy-prod.yml`). Alpha environments are dynamic GitHub Environment objects named `alpha-pr-<N>` — one per open PR, created by the alpha deploy workflow and deleted on PR close.
- 2026-05-22: Renamed the pre-production branch from `release/v*` to `beta/v*` (Environment table, GitHub-Environment section, Beta section, example realization) — done in parallel with the same rename in `issue-lifecycle.md` and `release.md`, so the branch name now matches the `beta` environment it deploys to.
- 2026-05-23: Renamed the GitHub Environment object from `production` to `prod` for symmetry with `beta` and `alpha`. Section heading `## Production` → `## Prod` (fragment is now `#prod`); Environment-table cell `Production` → `Prod`; all backticked env identifiers updated. The English word "production" (the runtime concept — "deployed to production", "production service") is unchanged. Cross-doc fragment links to `#production` updated in `release.md`, `issue-lifecycle.md`, and `release-pr.md`. `deploy-prod.yml` aligned to the symmetry: workflow `name: Production Deploy` → `Prod Deploy`, job name `Deploy to production` → `Deploy to prod`, concurrency group `production-deploy` → `prod-deploy`, `environment: production` → `environment: prod`. `scripts/setup.sh` Step 5 creates `prod` (was `production`); `scripts/rehearse.sh` checks for `prod` and waits on the renamed `Prod Deploy` workflow.
