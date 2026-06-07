# Admin Front JsonEditor Source Quality Review

Date: 2026-06-07

## Decision

`admin_front_ts/src/components/JsonEditor/src/index.vue` JsonEditor parse-error fallback debt has been closed.

The old component mixed UI, parsing, and fallback handling in one SFC. It used `catch (e: any)`, `e?.message || ''`, and `modelValue.value || '{}'`, while also embedding visible Chinese strings directly in a shared component. That hid malformed parse failures and made the empty-editor object rule implicit.

The current code moves parse/format/error-message rules to a pure helper, catches parse failures as `unknown`, requires an `Error` with a non-empty message, and routes visible text through `jsonEditor.*` i18n keys.

## Source change

```text
admin_front_ts/src/components/JsonEditor/src/json.ts:
  jsonEditorParseSource(value)
  parseJsonEditorValue(value)
  formatJsonEditorValue(value)
  requireJsonParseErrorMessage(error)
  empty/whitespace-only editor content is explicitly parsed as {}
  non-Error and empty-message parse failures throw diagnostic errors

admin_front_ts/src/components/JsonEditor/src/index.vue:
  catch (error: unknown)
  requireJsonParseErrorMessage(error)
  parseJsonEditorValue(modelValue.value)
  formatJsonEditorValue(modelValue.value)
  t('jsonEditor.invalidJson', { message })
  t('jsonEditor.formatted')
  t('jsonEditor.format')
  t('jsonEditor.validate')
```

## Guard

```text
admin_front_ts/tests/shared/json-editor/json-editor-source-quality.test.ts:
  rejects catch (e: any)
  rejects e?.message || fallback
  rejects modelValue.value || '{}'
  verifies non-Error and empty Error.message failures are not hidden
  verifies empty editor input remains compatible as {}
  verifies JsonEditor visible text uses i18n keys

admin_front_ts/tests/shared/i18n/no-visible-chinese.test.ts:
  includes src/components/JsonEditor/src/index.vue
```

## Inventory result after cleanup

```text
docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md:
  source files scanned = 280
  any candidates = 7
  as any candidates = 0
  catch(error: any) candidates = 0
  fallback candidates = 562
  direct external HTTP candidates = 0
  JsonEditor/src/index.vue priority evidence = no regex finding in configured categories
```

## Boundary

This only closes JsonEditor parse-error, empty-editor-rule, and touched visible-Chinese debt. It does not close the remaining `DownloadManager`, demo component, system setting parent-ref fallback, or general Admin Vue source-quality inventory rows.



