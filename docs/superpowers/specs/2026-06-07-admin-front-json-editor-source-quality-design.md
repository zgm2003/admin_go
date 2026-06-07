# Admin Front JsonEditor Source Quality Design

Date: 2026-06-07

## Decision

Close the `JsonEditor` shared component's `catch any`, optional-chain error fallback, implicit empty JSON fallback, and touched visible-Chinese debt in one narrow slice.

## Current problem

`admin_front_ts/src/components/JsonEditor/src/index.vue` currently:

- uses `catch (e: any)` in parse error branches;
- renders `e?.message || ''`, hiding malformed or empty error messages;
- parses `modelValue.value || '{}'`, making the empty-editor rule implicit;
- owns user-visible Chinese messages and button labels directly in the component.

That is not good taste. The component should make the empty-editor rule explicit, require parse errors to be real `Error` values with non-empty messages, and route visible text through i18n.

## Scope

In scope:

- Add a tiny pure helper module at `admin_front_ts/src/components/JsonEditor/src/json.ts`.
- Keep empty editor content compatible by treating empty/whitespace-only input as `{}`.
- Replace `catch any` with `catch unknown`.
- Replace optional-chain fallback messages with a fail-closed helper.
- Move JsonEditor visible text to `jsonEditor.*` i18n keys.
- Guard the component with targeted Vitest source/utility tests and the existing visible-Chinese guard.
- Refresh Admin front source-quality inventory and runtime docs/fact checks.

Out of scope:

- Changing system setting save semantics.
- Replacing the textarea UI.
- Solving all remaining Admin Vue fallback rows.
- Touching Go backend or Canvas Next runtime.

## Data and error model

`json.ts` owns the data rules:

```text
empty or whitespace-only editor input -> parse "{}"
non-empty input -> parse the exact string
parse/format failures -> require Error with non-empty message
non-Error or empty-message failures -> throw diagnostic error instead of displaying fallback text
```

The Vue component owns UI only:

```text
parse -> notify via i18n -> keep boolean validate contract
format -> replace model value with pretty JSON -> success notification via i18n
blur -> format valid JSON; leave invalid text untouched
```

## Compatibility

Existing callers still use the same component import and `validate()` exposed method. Empty editor content still validates and formats to `{}`. Invalid JSON still returns `false` from `validate()` and still shows a parse error notification when the parser provides a valid message.

## Verification

Targeted checks:

```powershell
cd E:\admin_go\admin_front_ts
npm run test -- tests/shared/json-editor/json-editor-source-quality.test.ts tests/shared/i18n/no-visible-chinese.test.ts
npm run typecheck
```

Root checks:

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

## Self-review

- No placeholders.
- The slice is limited to one shared Vue component and its generated documentation.
- The empty-editor fallback is not removed; it is made explicit to avoid breaking existing settings UX.
- The design does not claim the full Admin Vue source-quality backlog is closed.
