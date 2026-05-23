# Project Documentation

This directory holds the project's design, acceptance, and delivery artifacts. The project practices manual **Spec-Driven Development** within an audit-friendly documentation discipline. Each artifact type has a distinct lifecycle so that change-control expectations are clear.

## Layout

```
docs/
  README.md                # This index
  specs/                   # Capability specs — permanent, evolving
  features/                # Gherkin .feature files — executable acceptance criteria
  plans/                   # Delivery plans, named by software version
  process/                 # Workflow and process docs
```

The `specs/`, `features/`, and `plans/` directories are created when their first artifacts are added.

## Capability specs

Each spec describes a single capability of the system. Specs are stable artifacts that evolve through change control; each carries a status field, an owner, a "Why this design" section capturing rationale, and a changelog. Once present, list specs in this README under this heading.

## Feature files (executable acceptance criteria)

A BDD runner (e.g., Cucumber, Behave, Cucumber-JVM, SpecFlow) reads `.feature` files directly from `docs/features/`. They are the canonical acceptance criteria — specs reference scenarios; specs do not duplicate them as prose. Once present, list feature files in this README under this heading.

## Delivery plans

Plans are version-named (e.g., `v0.1.0.md`). A plan starts forward-looking ("what vX.Y.Z will deliver") and freezes as the historical delivery record at release. Once present, list plans in this README under this heading.

## Process

- [issue-lifecycle](process/issue-lifecycle.md) — how an issue (feature request, bug, or task) flows from intake through release
- [environments](process/environments.md) — branch-to-environment mapping (prod, beta, alpha) and deploy triggers
- [release](process/release.md) — the release ceremony (versioning, cutting, promoting, publishing, closing)

## Conventions

| Artifact | Lifecycle | Edit after release? |
|---|---|---|
| Spec | Evolves; status field tracks state (Draft → Approved → Implemented → Retired) | Yes, under change control with a changelog entry |
| Feature | Evolves with the spec it's tied to | Yes, under change control |
| Plan | Forward-looking until release; immutable historical record after | No, except status/date fields |

**Where design rationale lives:** each spec opens with a "Why this design" section capturing the substantive reasoning. Plans capture stack-level rationale in their "Stack" section. The reasoning travels with the artifact it justifies; no separate ADR layer.

## Cross-referencing

- Specs link to relevant feature files in their "Acceptance criteria" section.
- Plans link to specs and features they encompass.
- Specs link to other specs by name (e.g., `[other-spec](other-spec.md#why-this-design)`) when rationale or design choices cross capabilities.
