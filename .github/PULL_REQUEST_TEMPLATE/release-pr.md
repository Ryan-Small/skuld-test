<!--
This PR template is for release PRs (beta/vX.Y.Z → main).
For issue PRs (issue/<N>-slug → beta/vX.Y.Z), use issue-pr.md instead.

This PR is the production deploy approval event. Substantive design review happened during refinement (on each issue); substantive code review happened on the issue PRs. The release PR confirms the assembled release is ready to ship to production.

See docs/process/release.md for the full release ceremony and docs/process/environments.md for environment policy.
-->

## Release

Version: `vX.Y.Z`
Milestone: <link to milestone `vX.Y.Z`>

## Scope

<!--
One paragraph naming the release's headline content: new capabilities, fixes, and any breaking changes. Reference the milestone for the full issue list — don't restate it here.
-->

## UAT outcome

<!--
Stakeholder validation against the version-stamped beta environment (per docs/process/environments.md § Beta). Link to or quote the signoff thread.
-->

- Beta environment:
- Signoff from:
- Evidence:

## Breaking changes

<!--
Aggregates breaking changes across issues in this release. Each issue PR documented its own breaking change; this section consolidates them for downstream consumers and the changelog.

For non-breaking releases, mark "No breaking changes."
-->

- [ ] **No breaking changes**
- [ ] **Breaking changes** — describe each break and how downstream consumers should adapt:

## Risks

<!--
Anything reviewers should weigh before approval:
- Migration sensitivity (schema, data, config)
- Rollback complexity
- Dependencies on out-of-repo work (vendor, environment, coordination with other teams)
- Concentrated change in a sensitive component

Leave as "None" if no notable risks beyond ordinary deploy.
-->

- None

## Smoke checks

<!--
If smoke checks are configured per docs/process/environments.md § Beta, link the latest passing run on the beta environment.
-->

- [ ] Smoke checks passed on beta — link:
- [ ] N/A — smoke checks not configured for this release

## Pre-release defect status

<!--
Confirms all defects discovered during Beta UAT have been resolved on the originating issues. Pre-release defects reopen the originating issue rather than spawning new bug tickets (per docs/process/issue-lifecycle.md § Defect handling).
-->

- [ ] No pre-release defects outstanding
- [ ] N/A — no pre-release defects were found

## Notes for reviewer

<!--
Anything not obvious — coordination needs, sequencing dependencies, UAT surprises.

Leave as "None" if there's nothing to add.
-->

- None

---

### Reviewer checklist

Each item below is a personal attestation by the reviewer before approving. The PR author should leave these unchecked. Approval of this PR is the production deploy approval event (per docs/process/environments.md § Prod).

- [ ] **Release content** — I find that the milestone tags exactly the issues claimed for this release, all linked issues are in `Merged` Status, and no pre-release defects are outstanding.
- [ ] **UAT signoff** — I find that UAT was performed by the right stakeholders against the version-stamped beta environment and the signoff is linked.
- [ ] **Breaking changes** — I find that any breaking changes are documented and that downstream consumers have a concrete adaptation path.
- [ ] **Risks** — I find the listed risks realistic and the response plan (rollback path, monitoring, coordination) sufficient.
- [ ] **Mutual acceptance** — I agree this release is ready to ship to production and am willing to support it as part of the team's shared codebase.
