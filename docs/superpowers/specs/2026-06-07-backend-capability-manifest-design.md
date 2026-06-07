# Backend Capability Manifest Design

Date: 2026-06-07

## Problem

The project already has backend route inventory and DB schema ownership map, but those artifacts do not directly answer:

```text
For this Go capability, where is the source package?
Which platform transports expose it?
Which service/repository/model files belong to it?
Which live MySQL tables does it own?
Is this a real capability or just a helper package?
```

Without that manifest, agents can still put code into the wrong package, create platform-prefixed capability copies, or treat helper packages as product modules.

## Goal

Generate a backend capability manifest from current source and generated source artifacts.

The manifest must start from current source:

```text
admin_back_go/internal/module
docs/knowledge/backend-route-inventory-YYYY-MM-DD.md
docs/knowledge/db-schema-ownership-map-YYYY-MM-DD.md
```

It must produce one row per real backend capability, including nested capabilities such as:

```text
ai/agent
payment/wallet
notification/task
```

## Non-goals

```text
No runtime smoke proof.
No import graph ownership proof.
No canonical writer inference.
No migration history.
No guessed capability when source path does not exist.
```

## Data rules

- A real capability is a source package under `admin_back_go/internal/module` that appears in backend route inventory or DB model ownership.
- Helper packages with Go files but no route/table ownership are listed separately as helper packages, not promoted to capabilities.
- DB ownership uses the latest live schema ownership artifact. Migration files do not override it.
- Empty route count is valid for table-owned internal capabilities such as `notification/task`.

## Expected artifact

```text
scripts/export-backend-capability-manifest.ps1
docs/knowledge/backend-capability-manifest-YYYY-MM-DD.md
```

This artifact is a source ownership and navigation manifest, not runtime proof.
