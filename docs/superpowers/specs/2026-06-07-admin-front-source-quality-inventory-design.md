# Admin Front Source Quality Inventory Design

Date: 2026-06-07

## Problem

Admin Vue quality rules already say touched code must not add:

```text
any
as any
Record<string, any>
contract-hiding fallback
silent external helper
```

But current docs only track a few point issues. That is not enough for Codex-first work:

- Reviewers cannot see the current debt shape.
- New agents may treat one known issue as the whole problem.
- Fallbacks and `any` can spread while targeted guards still pass.

## Goal

Generate a source-quality inventory for current `admin_front_ts/src`.

The artifact must show:

```text
any / as any / Record<string, any> candidates
catch(error: any) candidates
logical-or / nullish-coalescing fallback candidates
optional-chain fallback candidates
known priority evidence files
```

## Non-goals

```text
Do not rewrite all Admin Vue code.
Do not fail the build merely because existing debt exists.
Do not classify every fallback as a bug.
Do not scan generated, dependency, declaration, or test files as production source.
Do not pretend regex inventory is type-aware semantic proof.
```

## Data rules

- Scope is `admin_front_ts/src/**/*.ts` and `admin_front_ts/src/**/*.vue`.
- Exclude declaration files.
- Strip comments before scanning.
- Inventory rows are source evidence, not automatic fixes.
- Priority examples must include:
  - `src/views/Layout/components/Header/index.vue`
  - `src/views/Layout/components/Header/components/SearchDialog.vue`
  - `src/views/Login/composables/useForgotPassword.ts`

## Expected artifacts

```text
scripts/export-admin-front-source-quality-inventory.ps1
docs/knowledge/admin-front-source-quality-inventory-YYYY-MM-DD.md
```

The runtime fact checker must verify the artifact exists, has non-zero current debt counts, references known priority files, verifies direct external HTTP count when used by follow-up guards, and is linked from the knowledge base. This prevents the “one fixed component means the whole frontend is clean” lie.
