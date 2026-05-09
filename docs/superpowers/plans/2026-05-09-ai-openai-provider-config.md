# AI OpenAI 供应商配置 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 完全落地 AI 菜单第一个页面“供应商配置”，第一版只支持 OpenAI，支持模型拉取、模型启用、默认模型、健康检测，并去掉当前页面的 Dify/Eino/Direct/RAGFlow 暴露。

**Architecture:** 保留现有 `ai_engine_connections` 作为兼容锚点，产品语义收口为 provider；新增 `ai_provider_models` 保存供应商模型目录。后端增加轻量 OpenAI provider driver，用 `net/http` 调 OpenAI `/models`，不引入新的 AI SDK。前端把 `/ai/providers` 拆成页面容器 + 表单弹窗 + 模型列表组件。

**Tech Stack:** Go 1.21+ / Gin / GORM / MySQL / secretbox / Vue 3 `<script setup lang="ts">` / Element Plus / Vitest / Vite。

---

**Note:** Commit steps are intentionally not executed in this rollout because the user has not explicitly asked to commit. Checkboxes only mean the code/doc work for that section is implemented and verified in the working tree.

## File Structure

### Backend

- Create: `admin_back_go/database/migrations/20260509_ai_openai_provider_config.sql` — schema migration.
- Create: `admin_back_go/internal/platform/ai/provider/types.go` — provider driver interfaces.
- Create: `admin_back_go/internal/platform/ai/provider/openai.go` — OpenAI `/models` driver.
- Create: `admin_back_go/internal/platform/ai/provider/openai_test.go` — driver tests.
- Modify: `admin_back_go/internal/module/aiengine/model.go` — connection fields and provider model.
- Modify: `admin_back_go/internal/module/aiengine/dto.go` — provider/model DTOs.
- Modify: `admin_back_go/internal/module/aiengine/request.go` — OpenAI-only requests.
- Modify: `admin_back_go/internal/module/aiengine/repository.go` — model persistence.
- Modify: `admin_back_go/internal/module/aiengine/service.go` — validation and business logic.
- Modify: `admin_back_go/internal/module/aiengine/handler.go` — new handlers.
- Modify: `admin_back_go/internal/module/aiengine/route.go` — new routes.
- Modify: `admin_back_go/internal/module/aiengine/service_test.go` — service tests.
- Modify: `admin_back_go/internal/bootstrap/route_meta.go` and `route_meta_test.go` — RBAC and operation log metadata.
- Modify: `admin_back_go/internal/server/router_test.go` — route smoke tests.
- Modify: `admin_back_go/docs/architecture.md` — architecture truth.

### Frontend

- Modify: `admin_front_ts/src/api/ai/engineConnections.ts` — provider API contract.
- Modify: `admin_front_ts/src/views/Main/ai/providers/index.vue` — thin container.
- Create: `admin_front_ts/src/views/Main/ai/providers/components/ProviderFormDialog.vue` — form dialog.
- Create: `admin_front_ts/src/views/Main/ai/providers/components/ProviderModelList.vue` — model tags.
- Create: `admin_front_ts/src/views/Main/ai/providers/composables/useProviderForm.ts` — form state.
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts` and `en-US.ts` — labels.
- Modify: `admin_front_ts/tests/shared/ai/ai-engine-connection-api.test.ts` — static API test.

### Root docs / smoke

- Modify: `docs/contracts/admin-api-v1.md` — API contract.
- Modify: `docs/testing/smoke-matrix.md` — smoke expectations.
- Modify: `docs/migration/current-status.md` — current status after verification.
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1` — smoke assertions.

---

## Task 1: Database migration for OpenAI provider config

**Files:**
- Create: `admin_back_go/database/migrations/20260509_ai_openai_provider_config.sql`

- [x] **Step 1: Write the migration**

Create `admin_back_go/database/migrations/20260509_ai_openai_provider_config.sql`:

```sql
-- OpenAI-only provider config slice.
-- This keeps ai_engine_connections as the compatibility table for the first AI menu,
-- and adds a real provider model catalog.

ALTER TABLE `ai_engine_connections`
  MODIFY `engine_type` VARCHAR(32) NOT NULL,
  MODIFY `base_url` VARCHAR(512) NOT NULL DEFAULT '';

ALTER TABLE `ai_engine_connections`
  ADD COLUMN `last_check_error` VARCHAR(1024) NOT NULL DEFAULT '' AFTER `last_checked_at`,
  ADD COLUMN `last_model_sync_at` DATETIME NULL AFTER `last_check_error`,
  ADD COLUMN `last_model_sync_status` VARCHAR(32) NOT NULL DEFAULT 'unknown' AFTER `last_model_sync_at`,
  ADD COLUMN `last_model_sync_error` VARCHAR(1024) NOT NULL DEFAULT '' AFTER `last_model_sync_status`;

CREATE TABLE IF NOT EXISTS `ai_provider_models` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `provider_id` BIGINT UNSIGNED NOT NULL,
  `model_id` VARCHAR(191) NOT NULL,
  `display_name` VARCHAR(191) NOT NULL DEFAULT '',
  `is_default` TINYINT UNSIGNED NOT NULL DEFAULT 2,
  `source` VARCHAR(32) NOT NULL DEFAULT 'remote',
  `raw_json` JSON NULL,
  `status` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `is_del` TINYINT UNSIGNED NOT NULL DEFAULT 2,
  `created_by` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `updated_by` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ai_provider_models_provider_model` (`provider_id`, `model_id`, `is_del`),
  KEY `idx_ai_provider_models_provider_status` (`provider_id`, `status`, `is_del`),
  KEY `idx_ai_provider_models_provider_default` (`provider_id`, `is_default`, `is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI provider enabled model catalog';

UPDATE `permissions`
SET `sort` = CASE `i18n_key`
  WHEN 'menu.ai_providers' THEN 1
  WHEN 'menu.ai_apps' THEN 2
  WHEN 'menu.ai_knowledge' THEN 3
  WHEN 'menu.ai_tools' THEN 4
  WHEN 'menu.ai_runs' THEN 5
  WHEN 'menu.ai_chat' THEN 6
  ELSE `sort`
END,
`updated_at` = NOW()
WHERE `platform` = 'admin'
  AND `is_del` = 2
  AND `i18n_key` IN (
    'menu.ai_providers',
    'menu.ai_apps',
    'menu.ai_knowledge',
    'menu.ai_tools',
    'menu.ai_runs',
    'menu.ai_chat'
  );
```

- [x] **Step 2: Review migration for required columns**

Run:

```powershell
rg -n "CREATE TABLE IF NOT EXISTS ``ai_provider_models``|``is_del``|``created_at``|``updated_at``|menu.ai_providers|menu.ai_chat" admin_back_go/database/migrations/20260509_ai_openai_provider_config.sql
```

Expected: new table contains `is_del`, `created_at`, `updated_at`; menu sort update shows providers/apps/knowledge/tools/runs/chat order.

- [ ] **Step 3: Commit database migration**

```powershell
git -C E:\admin_go\admin_back_go add database/migrations/20260509_ai_openai_provider_config.sql
git -C E:\admin_go\admin_back_go commit -m "feat: add openai provider config schema"
```

---

## Task 2: Add provider driver boundary and OpenAI model listing

**Files:**
- Create: `admin_back_go/internal/platform/ai/provider/types.go`
- Create: `admin_back_go/internal/platform/ai/provider/openai.go`
- Create: `admin_back_go/internal/platform/ai/provider/openai_test.go`

- [x] **Step 1: Write failing OpenAI driver tests**

Create `admin_back_go/internal/platform/ai/provider/openai_test.go`:

```go
package provider

import (
    "context"
    "net/http"
    "net/http/httptest"
    "strings"
    "testing"
)

func TestOpenAIDriverListModels(t *testing.T) {
    server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        if r.URL.Path != "/models" {
            t.Fatalf("path = %s, want /models", r.URL.Path)
        }
        if got := r.Header.Get("Authorization"); got != "Bearer sk-test" {
            t.Fatalf("authorization = %q", got)
        }
        w.Header().Set("Content-Type", "application/json")
        _, _ = w.Write([]byte(`{"object":"list","data":[{"id":"gpt-b","object":"model","created":2,"owned_by":"openai"},{"id":"gpt-a","object":"model","created":1,"owned_by":"openai"}]}`))
    }))
    defer server.Close()

    driver := NewOpenAIDriver(nil)
    models, err := driver.ListModels(context.Background(), Config{BaseURL: server.URL, APIKey: "sk-test"})
    if err != nil {
        t.Fatalf("ListModels error = %v", err)
    }
    if len(models) != 2 {
        t.Fatalf("len(models) = %d, want 2", len(models))
    }
    if models[0].ID != "gpt-a" || models[1].ID != "gpt-b" {
        t.Fatalf("models not sorted by id: %+v", models)
    }
}

func TestOpenAIDriverRejectsMissingAPIKey(t *testing.T) {
    driver := NewOpenAIDriver(nil)
    _, err := driver.ListModels(context.Background(), Config{})
    if err == nil || !strings.Contains(err.Error(), "missing OpenAI API key") {
        t.Fatalf("error = %v, want missing OpenAI API key", err)
    }
}

func TestOpenAIDriverDoesNotLeakAPIKeyOnFailure(t *testing.T) {
    server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        http.Error(w, `{"error":{"message":"bad key"}}`, http.StatusUnauthorized)
    }))
    defer server.Close()

    driver := NewOpenAIDriver(nil)
    _, err := driver.ListModels(context.Background(), Config{BaseURL: server.URL, APIKey: "sk-secret-value"})
    if err == nil {
        t.Fatal("expected error")
    }
    if strings.Contains(err.Error(), "sk-secret-value") {
        t.Fatalf("error leaked api key: %v", err)
    }
}
```

- [x] **Step 2: Run the failing tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/platform/ai/provider
```

Expected before implementation: package or symbols are missing.

- [x] **Step 3: Implement provider driver types**

Create `admin_back_go/internal/platform/ai/provider/types.go`:

```go
package provider

import "context"

const (
    DriverOpenAI = "openai"
    HealthUnknown = "unknown"
    HealthOK = "ok"
    HealthFailed = "failed"
)

type Config struct {
    Driver string
    BaseURL string
    APIKey string
    TimeoutMs int
}

type Model struct {
    ID string
    Object string
    Created int64
    OwnedBy string
    Raw map[string]any
}

type TestResult struct {
    OK bool
    Status string
    LatencyMs int64
    Message string
    ModelCount int
}

type Driver interface {
    Name() string
    DefaultBaseURL() string
    ListModels(ctx context.Context, cfg Config) ([]Model, error)
    TestConnection(ctx context.Context, cfg Config) (*TestResult, error)
}
```

- [x] **Step 4: Implement OpenAI driver**

Create `admin_back_go/internal/platform/ai/provider/openai.go`:

```go
package provider

import (
    "bytes"
    "context"
    "encoding/json"
    "fmt"
    "io"
    "net/http"
    "net/url"
    "sort"
    "strings"
    "time"
)

const defaultOpenAIBaseURL = "https://api.openai.com/v1"

type OpenAIDriver struct { client *http.Client }

func NewOpenAIDriver(client *http.Client) *OpenAIDriver {
    if client == nil { client = &http.Client{Timeout: 15 * time.Second} }
    return &OpenAIDriver{client: client}
}

func (d *OpenAIDriver) Name() string { return DriverOpenAI }
func (d *OpenAIDriver) DefaultBaseURL() string { return defaultOpenAIBaseURL }

func (d *OpenAIDriver) ListModels(ctx context.Context, cfg Config) ([]Model, error) {
    apiKey := strings.TrimSpace(cfg.APIKey)
    if apiKey == "" { return nil, fmt.Errorf("missing OpenAI API key") }
    baseURL, err := normalizeBaseURL(cfg.BaseURL, d.DefaultBaseURL())
    if err != nil { return nil, err }
    req, err := http.NewRequestWithContext(ctx, http.MethodGet, baseURL+"/models", nil)
    if err != nil { return nil, fmt.Errorf("build OpenAI models request: %w", err) }
    req.Header.Set("Authorization", "Bearer "+apiKey)
    req.Header.Set("Accept", "application/json")
    resp, err := d.client.Do(req)
    if err != nil { return nil, fmt.Errorf("request OpenAI models: %w", err) }
    defer resp.Body.Close()
    body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
    if err != nil { return nil, fmt.Errorf("read OpenAI models response: %w", err) }
    if resp.StatusCode < 200 || resp.StatusCode >= 300 {
        return nil, fmt.Errorf("OpenAI models failed: %s %s", resp.Status, sanitizeBody(body))
    }
    var payload struct { Data []map[string]any `json:"data"` }
    if err := json.Unmarshal(body, &payload); err != nil { return nil, fmt.Errorf("decode OpenAI models response: %w", err) }
    models := make([]Model, 0, len(payload.Data))
    for _, item := range payload.Data {
        id, _ := item["id"].(string)
        if strings.TrimSpace(id) == "" { continue }
        object, _ := item["object"].(string)
        ownedBy, _ := item["owned_by"].(string)
        created := int64(0)
        if value, ok := item["created"].(float64); ok { created = int64(value) }
        models = append(models, Model{ID: id, Object: object, Created: created, OwnedBy: ownedBy, Raw: item})
    }
    sort.Slice(models, func(i, j int) bool { return models[i].ID < models[j].ID })
    return models, nil
}

func (d *OpenAIDriver) TestConnection(ctx context.Context, cfg Config) (*TestResult, error) {
    started := time.Now()
    models, err := d.ListModels(ctx, cfg)
    latency := time.Since(started).Milliseconds()
    if err != nil { return &TestResult{OK: false, Status: HealthFailed, LatencyMs: latency, Message: err.Error()}, err }
    return &TestResult{OK: true, Status: HealthOK, LatencyMs: latency, Message: fmt.Sprintf("OpenAI models reachable: %d", len(models)), ModelCount: len(models)}, nil
}

func normalizeBaseURL(value string, fallback string) (string, error) {
    raw := strings.TrimRight(strings.TrimSpace(value), "/")
    if raw == "" { raw = fallback }
    parsed, err := url.Parse(raw)
    if err != nil || parsed.Scheme == "" || parsed.Host == "" { return "", fmt.Errorf("invalid OpenAI base url") }
    if parsed.Scheme != "http" && parsed.Scheme != "https" { return "", fmt.Errorf("invalid OpenAI base url scheme") }
    return raw, nil
}

func sanitizeBody(body []byte) string {
    compact := bytes.TrimSpace(body)
    if len(compact) > 512 { compact = compact[:512] }
    return string(compact)
}
```

- [x] **Step 5: Run provider driver tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/platform/ai/provider
```

Expected: `ok admin_back_go/internal/platform/ai/provider`.

- [ ] **Step 6: Commit provider driver**

```powershell
git -C E:\admin_go\admin_back_go add internal/platform/ai/provider
git -C E:\admin_go\admin_back_go commit -m "feat: add openai provider driver"
```

---

## Task 3: Backend provider service contract and model persistence

**Files:**
- Modify: `admin_back_go/internal/module/aiengine/model.go`
- Modify: `admin_back_go/internal/module/aiengine/dto.go`
- Modify: `admin_back_go/internal/module/aiengine/request.go`
- Modify: `admin_back_go/internal/module/aiengine/repository.go`
- Modify: `admin_back_go/internal/module/aiengine/service.go`
- Modify: `admin_back_go/internal/module/aiengine/service_test.go`

- [x] **Step 1: Write failing service tests**

Add tests for:

```go
func TestInitOnlyReturnsOpenAIDriver(t *testing.T) {
    service := NewService(&fakeRepository{}, secretbox.New("vault-key"), nil)
    result, appErr := service.Init(context.Background())
    if appErr != nil { t.Fatalf("Init error = %v", appErr) }
    if len(result.Dict.EngineTypeArr) != 1 || result.Dict.EngineTypeArr[0].Value != "openai" {
        t.Fatalf("driver options = %+v, want openai only", result.Dict.EngineTypeArr)
    }
}

func TestCreateRequiresAPIKeyAndModels(t *testing.T) {
    service := NewService(&fakeRepository{}, secretbox.New("vault-key"), nil)
    _, appErr := service.Create(context.Background(), CreateInput{Name: "OpenAI", EngineType: "openai", Status: 1})
    if appErr == nil || !strings.Contains(appErr.Message, "API Key") { t.Fatalf("Create error = %v, want API Key required", appErr) }
    _, appErr = service.Create(context.Background(), CreateInput{Name: "OpenAI", EngineType: "openai", APIKey: "sk-test", Status: 1})
    if appErr == nil || !strings.Contains(appErr.Message, "模型") { t.Fatalf("Create error = %v, want model required", appErr) }
}
```

Also add a fake repository assertion that `Create` with `ModelIDs: []string{"gpt-4.1-mini"}` creates provider models and sets exactly one default model.

- [x] **Step 2: Run failing tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aiengine
```

Expected: fail before implementation because `CreateInput` has no `ModelIDs` or service does not validate models.

- [x] **Step 3: Extend model and DTOs**

Add `ProviderModel` to `model.go`, add connection sync fields, and extend `CreateInput`:

```go
type CreateInput struct {
    Name string
    EngineType string
    BaseURL string
    APIKey string
    WorkspaceID string
    ModelIDs []string
    DefaultModelID string
    ModelDisplayNames map[string]string
    Status int
}
```

Add model DTOs: `ProviderModelDTO`, `ModelOptionsInput`, `ModelOptionDTO`, `ModelOptionsResponse`, `ProviderModelsResponse`, `UpdateModelsInput`.

- [x] **Step 4: Extend requests**

Change `request.go` so `engine_type` / `driver` only allow `openai`, `base_url` is optional, mutation requires `model_ids` and `default_model_id`, and add `modelOptionsRequest`.

- [x] **Step 5: Implement repository model methods**

Add to `Repository`:

```go
ListModels(ctx context.Context, providerID uint64) ([]ProviderModel, error)
ReplaceModels(ctx context.Context, providerID uint64, models []ProviderModel, defaultModelID string) error
```

Implement `ReplaceModels` with a GORM transaction: soft-delete current rows for the provider, insert new rows, set exactly one default based on `defaultModelID`.

- [x] **Step 6: Implement service validation**

Replace old labels with:

```go
var engineTypeLabels = map[string]string{"openai": "OpenAI"}
```

Add validation:

```go
func validateSelectedModels(modelIDs []string, defaultModelID string) ([]string, *apperror.Error) {
    seen := map[string]bool{}
    normalized := make([]string, 0, len(modelIDs))
    for _, item := range modelIDs {
        modelID := strings.TrimSpace(item)
        if modelID == "" { continue }
        if !seen[modelID] { seen[modelID] = true; normalized = append(normalized, modelID) }
    }
    if len(normalized) == 0 { return nil, apperror.BadRequest("请至少选择一个模型") }
    if !seen[strings.TrimSpace(defaultModelID)] { return nil, apperror.BadRequest("默认模型必须在已选择模型中") }
    return normalized, nil
}
```

- [x] **Step 7: Wire model persistence in Create/Update**

Create requires non-empty API key and selected models. Update keeps old encrypted key when `api_key` is blank. Both call `ReplaceModels` after provider row mutation.

- [x] **Step 8: Run service tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aiengine
```

Expected: `ok admin_back_go/internal/module/aiengine`.

- [ ] **Step 9: Commit backend service contract**

```powershell
git -C E:\admin_go\admin_back_go add internal/module/aiengine
git -C E:\admin_go\admin_back_go commit -m "feat: support openai provider models"
```

---

## Task 4: Backend provider model preview/sync endpoints and route metadata

**Files:**
- Modify: `admin_back_go/internal/module/aiengine/handler.go`
- Modify: `admin_back_go/internal/module/aiengine/route.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta_test.go`
- Modify: `admin_back_go/internal/server/router_test.go`

- [x] **Step 1: Add service methods to interface**

Add:

```go
PreviewModels(ctx context.Context, input ModelOptionsInput) (*ModelOptionsResponse, *apperror.Error)
SyncModels(ctx context.Context, id uint64) (*ModelOptionsResponse, *apperror.Error)
ListProviderModels(ctx context.Context, id uint64) (*ProviderModelsResponse, *apperror.Error)
UpdateProviderModels(ctx context.Context, id uint64, input UpdateModelsInput) *apperror.Error
```

- [x] **Step 2: Implement PreviewModels and SyncModels**

Preview uses request API key and never persists. Sync decrypts existing provider key, calls OpenAI `/models`, writes sync status fields, and returns options. Both must truncate and sanitize errors.

- [x] **Step 3: Add handler methods**

Add `PreviewModels`, `SyncModels`, `ListProviderModels`, `UpdateProviderModels` to `handler.go`. `PreviewModels` binds `modelOptionsRequest` and returns `ModelOptionsResponse`.

- [x] **Step 4: Register routes**

In `route.go`:

```go
group.POST("/model-options", handler.PreviewModels)
group.POST("/:id/sync-models", handler.SyncModels)
group.GET("/:id/models", handler.ListProviderModels)
group.PUT("/:id/models", handler.UpdateProviderModels)
```

- [x] **Step 5: Add route metadata and sanitization tests**

Add permissions:

```go
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/ai-engine-connections/model-options"): "ai_engine_test",
middleware.NewRouteKey(http.MethodPost, "/api/admin/v1/ai-engine-connections/:id/sync-models"): "ai_engine_test",
middleware.NewRouteKey(http.MethodPut, "/api/admin/v1/ai-engine-connections/:id/models"): "ai_engine_edit",
```

Add tests proving `api_key` is redacted from OperationLog request capture.

- [x] **Step 6: Run backend route tests**

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/bootstrap ./internal/server ./internal/module/aiengine
```

Expected: all three packages pass.

- [ ] **Step 7: Commit route endpoints**

```powershell
git -C E:\admin_go\admin_back_go add internal/module/aiengine internal/bootstrap internal/server
git -C E:\admin_go\admin_back_go commit -m "feat: expose openai provider model endpoints"
```

---

## Task 5: Frontend API contract for OpenAI provider config

**Files:**
- Modify: `admin_front_ts/src/api/ai/engineConnections.ts`
- Modify: `admin_front_ts/tests/shared/ai/ai-engine-connection-api.test.ts`

- [x] **Step 1: Write failing static contract test**

Modify `admin_front_ts/tests/shared/ai/ai-engine-connection-api.test.ts`:

```ts
import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'

const source = readFileSync(resolve(process.cwd(), 'src/api/ai/engineConnections.ts'), 'utf8')

describe('OpenAI provider config API contract', () => {
  it('exposes openai as the only first-slice driver', () => {
    expect(source).toContain("export type AiProviderDriver = 'openai'")
    expect(source).not.toContain("'dify'")
    expect(source).not.toContain("'eino'")
    expect(source).not.toContain("'direct'")
    expect(source).not.toContain("'ragflow'")
  })

  it('sends selected models and default model in mutations', () => {
    expect(source).toContain('model_ids')
    expect(source).toContain('default_model_id')
    expect(source).toContain('model_display_names')
  })

  it('has model preview and provider model endpoints', () => {
    expect(source).toContain('/model-options')
    expect(source).toContain('/sync-models')
    expect(source).toContain('/models')
  })
})
```

- [x] **Step 2: Run failing frontend test**

```powershell
cd E:\admin_go\admin_front_ts
npm test -- tests/shared/ai/ai-engine-connection-api.test.ts
```

Expected before implementation: fail because provider fields are missing.

- [x] **Step 3: Update API types**

Change `engineConnections.ts` to expose:

```ts
export type AiProviderDriver = 'openai'
export type AiEngineType = AiProviderDriver
export type AiEngineHealthStatus = 'unknown' | 'ok' | 'failed'
export type AiModelSyncStatus = 'unknown' | 'ok' | 'failed'
```

Add `AiProviderModelItem`; add mutation fields `model_ids`, `default_model_id`, `model_display_names`; keep old route URLs for compatibility.

- [x] **Step 4: Add API methods**

Add methods:

```ts
previewModels(...)
syncModels(...)
models(...)
updateModels(...)
```

All point to `/api/admin/v1/ai-engine-connections` routes from Task 4.

- [x] **Step 5: Run API contract test**

```powershell
cd E:\admin_go\admin_front_ts
npm test -- tests/shared/ai/ai-engine-connection-api.test.ts
```

Expected: targeted Vitest passes.

- [ ] **Step 6: Commit frontend API contract**

```powershell
git -C E:\admin_go\admin_front_ts add src/api/ai/engineConnections.ts tests/shared/ai/ai-engine-connection-api.test.ts
git -C E:\admin_go\admin_front_ts commit -m "feat: add openai provider api contract"
```

---

## Task 6: Frontend provider UI split and model selection

**Files:**
- Modify: `admin_front_ts/src/views/Main/ai/providers/index.vue`
- Create: `admin_front_ts/src/views/Main/ai/providers/components/ProviderFormDialog.vue`
- Create: `admin_front_ts/src/views/Main/ai/providers/components/ProviderModelList.vue`
- Create: `admin_front_ts/src/views/Main/ai/providers/composables/useProviderForm.ts`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`

- [x] **Step 1: Add provider form composable**

Create `useProviderForm.ts` with typed `ProviderFormState`, `createDefaultProviderForm()`, `useProviderForm(t)`, `rules`, `modelLoading`, `modelOptions`, and `reset()`.

- [x] **Step 2: Create ProviderModelList component**

Create `ProviderModelList.vue` with props `models: AiProviderModelItem[]`, computed enabled models, tags default model with success color, and displays `-` for empty list.

- [x] **Step 3: Create ProviderFormDialog component**

Create `ProviderFormDialog.vue` with props:

```ts
const props = defineProps<{
  modelValue: boolean
  mode: 'add' | 'edit'
  dict: AiEngineConnectionInitResponse['dict']
  initial?: Partial<ProviderFormState>
}>()
```

Emits:

```ts
const emit = defineEmits<{
  'update:modelValue': [value: boolean]
  submitted: []
}>()
```

The component must use `el-select-v2` for driver/model_ids/default_model_id/status, call `AiEngineConnectionApi.previewModels`, and require API key for model preview.

- [x] **Step 4: Make index.vue a thin container**

Keep list/search/table operations in `index.vue`. Replace inline form with `<ProviderFormDialog />`. Health tag mapping must use `ok` / `failed` / `unknown`.

- [x] **Step 5: Update i18n labels**

Add/update labels for: 供应商名称、驱动、模型标识、默认模型、Base URL、API Key、状态、拉取模型、同步模型、测试连接。

- [x] **Step 6: Run frontend checks**

```powershell
cd E:\admin_go\admin_front_ts
npm test -- tests/shared/ai/ai-engine-connection-api.test.ts
npm run build:check
```

Expected: targeted Vitest and build check pass.

- [ ] **Step 7: Commit frontend UI**

```powershell
git -C E:\admin_go\admin_front_ts add src/api/ai/engineConnections.ts src/views/Main/ai/providers src/i18n/locales/zh-CN.ts src/i18n/locales/en-US.ts tests/shared/ai/ai-engine-connection-api.test.ts
git -C E:\admin_go\admin_front_ts commit -m "feat: implement openai provider config ui"
```

---

## Task 7: Docs, smoke, and final verification

**Files:**
- Modify: `docs/contracts/admin-api-v1.md`
- Modify: `docs/testing/smoke-matrix.md`
- Modify: `docs/migration/current-status.md`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`

- [x] **Step 1: Update API contract docs**

Document: OpenAI only, empty base_url uses `https://api.openai.com/v1`, model list comes from `GET /models`, models persist to `ai_provider_models`, API key is write-only/masked.

- [x] **Step 2: Update smoke matrix**

Document: page-init returns driver openai only; list does not leak secrets; users/init AI menu order is `/ai/providers`, `/ai/apps`, `/ai/knowledge`, `/ai/tools`, `/ai/runs`, `/ai/chat`.

- [x] **Step 3: Update full smoke script**

Use:

```powershell
$allowedAiDrivers = @('openai')
$expectedAiPaths = @('/ai/providers','/ai/apps','/ai/knowledge','/ai/tools','/ai/runs','/ai/chat')
```

- [x] **Step 4: Run backend verification**

```powershell
cd E:\admin_go\admin_back_go
go test ./...
go vet ./...
```

If available:

```powershell
golangci-lint run
```

- [x] **Step 5: Run frontend verification**

```powershell
cd E:\admin_go\admin_front_ts
npm test -- tests/shared/ai/ai-engine-connection-api.test.ts
npm run build:check
```

- [x] **Step 6: Run smoke script syntax check**

```powershell
powershell -NoProfile -Command "[scriptblock]::Create((Get-Content -Raw 'E:\admin_go\admin_back_go\scripts\full-admin-smoke.ps1')) | Out-Null"
```

- [x] **Step 7: Residue scan**

```powershell
rg -n "Dify|dify|Eino|eino|RAGFlow|ragflow|workflow|Workflow" E:\admin_go\admin_back_go\internal\module\aiengine E:\admin_go\admin_front_ts\src\views\Main\ai\providers E:\admin_go\admin_front_ts\src\api\ai\engineConnections.ts E:\admin_go\docs\contracts E:\admin_go\docs\testing
```

Expected: no active provider-config residue. Historical docs outside this slice may still contain old terms.

- [ ] **Step 8: Commit docs and smoke**

```powershell
git -C E:\admin_go add docs/contracts/admin-api-v1.md docs/testing/smoke-matrix.md docs/migration/current-status.md
git -C E:\admin_go commit -m "docs: record openai provider config slice"

git -C E:\admin_go\admin_back_go add docs/architecture.md scripts/full-admin-smoke.ps1
git -C E:\admin_go\admin_back_go commit -m "docs: update ai provider smoke contract"
```

---

## Final verification bundle

Run before claiming completion:

```powershell
cd E:\admin_go\admin_back_go
go test ./...
go vet ./...
powershell -NoProfile -Command "[scriptblock]::Create((Get-Content -Raw '.\scripts\full-admin-smoke.ps1')) | Out-Null"

cd E:\admin_go\admin_front_ts
npm test -- tests/shared/ai/ai-engine-connection-api.test.ts
npm run build:check

cd E:\admin_go
rg -n "Dify|dify|Eino|eino|RAGFlow|ragflow|workflow|Workflow" admin_back_go\internal\module\aiengine admin_front_ts\src\views\Main\ai\providers admin_front_ts\src\api\ai\engineConnections.ts docs\contracts docs\testing
```

Completion requires backend tests pass, frontend targeted test/build pass, smoke syntax pass, no active provider-config residue, API Key never leaks, and AI menu order matches the six-item order.
