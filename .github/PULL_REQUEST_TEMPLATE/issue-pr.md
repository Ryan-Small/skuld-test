<!--
This PR template is for issue PRs (issue/<N>-slug → beta/vX.Y.Z).
For release PRs (beta/vX.Y.Z → main), use release-pr.md instead.

Base branch: this PR's base should be `beta/vX.Y.Z`, not `main`. Issue branches branch off the active beta branch — see docs/process/issue-lifecycle.md § Branching model.

After opening: link this PR to the issue via the issue's right-sidebar `Development` → `Link a pull request` picker. The `Closes #N` keyword below doesn't auto-create the structured link on non-default-branch PRs — see docs/process/issue-lifecycle.md § Stage 3 — Implementation. The manual link is what makes the PR show up on the issue's Project card.

This template aligns with docs/process/issue-lifecycle.md. The substantive design and codebase analysis live in the linked issue's body (Stage 2: Refinement). This PR confirms delivery against that scope, it does not restate the analysis.
-->

## Linked issue

<!--
Use `Closes #N` when this PR fully resolves the issue (the default).
Use `Refs #N` when this PR advances but does not close the issue (partial work, follow-up split).
PRs without a linked issue should be exceptional — justify in "Notes for reviewer".
-->

Closes #<issue-number>

## Summary

<!--
One paragraph: what does this PR deliver?
Reference the linked issue for full context — don't restate the codebase analysis, risk assessment, or design rationale that already lives in the issue body.

Focus on **behavior**, not files (the diff shows files). Say what the system can do now that it couldn't, what was fixed, or what structural goal was met.

Examples:
- Feature: "Enables operators to enforce per-tenant request rate limits, preventing noisy tenants from degrading service for others. Exceeded limits return 429; the configured limit is exposed on `/health` for monitoring."
- Bug fix: "Fixes the off-by-one that caused the second page of results to skip the boundary record."
- Refactor: "Refactors `OrderProcessor` into three focused classes to bring cyclomatic complexity below 10 per method. No behavioral change."
-->

## Breaking change

<!--
If this PR changes a consumer contract, schema, removes a feature, or otherwise requires adaptation from downstream consumers, mark as breaking and describe what breaks and how to adapt. Feeds changelog and consumer communication.

Each description should name **what broke** (the specific contract violated) and **how to adapt** (the concrete migration step).

Examples:
- API contract: "Removed the `GET /users/by-email` endpoint. Clients should use `GET /users?email=...` instead."
- Schema: "The `created_at` column on `orders` is now NOT NULL; pre-existing rows are backfilled by migration V12. Direct SQL consumers must handle the new constraint."
- Configuration: "Renamed config key `app.api.url` to `app.api.base-url`. Operators must update their configuration; the old key is silently ignored."
-->

- [ ] **No breaking changes**
- [ ] **Breaking change** — describe what breaks and how downstream consumers should adapt:

## Verification

<!--
What the author uniquely verifies — things CI doesn't gate automatically.
CI handles: build, tests passing, linters, type checks. Don't restate those here.
This section is for human-judgment attestation. Use "N/A — <reason>" for items that don't apply.

Attach evidence inline under the relevant check where useful — screenshots, log output, performance numbers, migration result dumps, BDD report excerpts. Fenced code blocks for text artifacts; drag-and-drop for images.
-->

**Does the change work?**
- [ ] **BDD scenarios in `docs/features/`** added or amended for any user-visible behavior change
- [ ] **Automated Tests cover the new or changed behavior** — not just present and passing, but meaningfully exercising the intent.
<!--
For "Manual checks performed", each entry should name the **specific action taken** and the **outcome verified**. Avoid vague claims like "tested it" or "verified it works."

Examples:
- "Posted a typical 50-item payload to the new endpoint; confirmed 201, all items persisted, and a follow-up GET returned the same set."
- "Triggered the new error path with malformed input; confirmed 400 with structured error body."
- "Ran the migration against a production-sized dataset copy; verified completion under 60s and no orphaned rows."
-->
- [ ] **Manual checks performed** — specifically:
  - <what was checked>

**Is it safe to ship and run?**

<!--
"Migration / rollback safety" applies when the PR makes a change that's hard to undo after merge — schema migrations, data backfills, breaking API contracts, removed config keys. For these, verify either:
- The change is reversible (down migration exists, schema change is additive, old clients still work), OR
- A rollback procedure is documented (specific steps to restore prior state).

For additive or code-only changes that are trivially undone by redeploying the prior version, write "N/A — <reason>".

Examples:
- "Down migration `V12_undo.sql` exists and was tested against the upgraded schema."
- "Schema change is additive (new nullable column); rollback is redeploy of the prior version with no data restoration needed."
- "N/A — code refactor; no schema or contract change."
-->
- [ ] **Migration / rollback safety** — schema or breaking-API changes are reversible, or rollback procedure is documented (or N/A — no schema or breaking-API change).
<!--
"Observability" applies when the change introduces new behaviors, code paths, or performance characteristics that need to be detectable in production. For these, verify that logs, metrics, dashboards, or alerts surface the relevant signal — the question is "if this fails or misbehaves in production, will we know?"

For changes that don't introduce observable behavior (pure refactor, doc-only, test-only) or for projects without monitoring infrastructure yet, write "N/A — <reason>".

Examples:
- "Added WARN-level log on the new validation-failure path with request ID and rejection reason."
- "Added `<job>_duration_seconds` histogram and `<operation>_total` counter for the new ingestion job."
- "N/A — code refactor; no new code paths or behaviors to monitor."
-->
- [ ] **Observability** — logs, metrics, or dashboards updated to surface issues with this change (or N/A — change is not operationally observable, or no monitoring in scope yet).

**Do users and operators know?**

- [ ] **Documentation updated** in `docs/` or `README.md` for any user-visible or operationally-significant change (or N/A — no doc-relevant change).


## Deviations from refined issue

<!--
If clarifications were resolved on the PR without changing scope, list them briefly with links to the resolving comments.
-->

- None

## Follow-up / intentionally out-of-scope

<!--
Things noticed during implementation that are intentionally not fixed in this PR (adjacent issues, related cleanup, deferred improvements). Link to follow-up issues if filed.

Leave as "None" if there are no follow-ups.
-->

- None

## Notes for reviewer

<!--
Anything not obvious from the diff — trade-offs taken, considerations the reviewer should know.

Leave as "None" if there's nothing to add.
-->

- None

---

### Reviewer checklist

Each item below is a personal attestation by the reviewer before approving. The PR author should leave these unchecked.

- [ ] **Code readability** — I find that names convey intent, the structure is straightforward to follow, each unit stays at a consistent level of abstraction, non-obvious decisions are explained where the code itself can't, and the code favors clarity over cleverness.
- [ ] **Code quality** — I find that errors are handled appropriately, resources opened are guaranteed to close, types are used precisely, the change fits the codebase's architecture, and the code is expected to perform well at realistic production scale.
- [ ] **Security** — I find no obvious vulnerabilities: no unvalidated input reaching a query, command, or external call; no secrets in code; no authn/authz check this change bypasses or weakens; no sensitive data in logs or responses; and no error messages disclosing internals.
- [ ] **Test quality** — I cannot imagine a code change that would introduce a defect while still passing the test suite.
- [ ] **Mutual acceptance** — I agree with the substantive choices in this change and am willing to support it as part of the team's shared codebase. I do not need to have written it the same way, but I would not approve code I cannot stand behind.
