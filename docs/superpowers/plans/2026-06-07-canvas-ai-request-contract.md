# Canvas AI Request Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development for code behavior changes and superpowers:verification-before-completion before reporting completion.

**Goal:** Close `CANVAS-DOC-003` by making active Canvas AI requests agent_id-only for provider/model ownership.

**Architecture:** Keep provider/model selection in backend AI services through the selected `ai_agents` row. Canvas transports reject client-owned provider/model config fields before calling services.

**Tech Stack:** Go/Gin backend, Canvas Next source tests, Markdown knowledge/contracts, PowerShell fact checker.

---

### Task 1: Red tests

- [ ] Add chat transport test proving `model` override returns 400 and service is not called.
- [ ] Add video transport test proving `model` override returns 400 and service is not called.
- [ ] Extend tests to cover `provider`, `api_key`, and `base_url`.
- [ ] Add video active-client multipart request test because Canvas Next sends FormData.

### Task 2: Backend fix

- [ ] Remove `json:"model"` from chat/video Canvas request structs.
- [ ] Add a small shared internal Canvas request binder for forbidden provider/model config fields.
- [ ] Keep chat JSON-only.
- [ ] Allow video JSON or FormData.
- [ ] Stop forwarding `ModelID: req.ModelID`.
- [ ] Add zh-CN/en-US i18n catalog entry for the rejection message.

### Task 3: Contract and knowledge sync

- [ ] Add Canvas AI request contract review artifact.
- [ ] Update `docs/contracts/admin-api-v1.md`.
- [ ] Update `docs/knowledge/README.md`, `current-runtime-knowledge.md`, and `runtime-source-map.md`.
- [ ] Move `CANVAS-DOC-003` from open to resolved in `docs/status/known-issues.md`.
- [ ] Add runtime fact checker guard.

### Task 4: Verify

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/ai/chat/transport/canvas ./internal/module/ai/video/transport/canvas -run Canvas -count=1
go test ./internal/server -run 'TestRouterInstallsCanvasAI(ChatRoute|VideoRoutes)' -count=1

cd E:\admin_go\canvas_front_next
npm run test -- src/services/api/image.test.ts src/services/api/video.test.ts
npm run typecheck

cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

