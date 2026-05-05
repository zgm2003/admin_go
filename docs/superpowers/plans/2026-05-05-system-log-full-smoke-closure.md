# System Log Full Smoke Closure Plan

> **For agentic workers:** Use `superpowers:executing-plans`. Work in current branch. Do not commit.

**Goal:** Close the verification gap for the already-migrated system log read-only module by adding full-smoke probes and syncing docs.

**Linus three checks:**

```text
1. 真问题：current-status/smoke-matrix 仍写 system log full smoke planned，运行时已经有 Go REST 实现。
2. 更简单做法：不改业务逻辑，只给 full smoke 加 init/files/lines shape 探针；lines 在没有日志文件时显式 skipped。
3. 不破坏什么：只读接口，不写 DB，不删日志，不清空日志，不扩大 systemlog API。
```

## Steps

- [x] Inspect current systemlog contract, route and full smoke script.
- [x] Add full smoke helpers for `system-logs/init`, `system-logs/files`, and conditional `system-logs/files/:name/lines`.
- [x] Summary must expose stable JSON fields for system log probe status.
- [x] Update `docs/migration/current-status.md` from planned to full smoke covered.
- [x] Update `docs/testing/smoke-matrix.md` row from planned to yes/conditional lines.
- [x] Update `admin_back_go/docs/architecture.md` full smoke rule list.
- [x] Run targeted Go tests for systemlog/logstore/server/bootstrap.
- [x] Run `go test -p=1 ./...`, `go vet -p=1 ./...`, contract check, diff check.
- [x] Run full smoke with the existing test account.

