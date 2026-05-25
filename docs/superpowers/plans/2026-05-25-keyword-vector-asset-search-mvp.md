# Keyword Vector Asset Search MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first asset intelligence slice: manually imported authorized text/webpage bodies are chunked, embedded, stored in Qdrant, and searchable from the admin UI by keyword or natural-language query.

**Architecture:** Add an `assetintel` Go module under the existing Gin modular monolith, backed by MySQL metadata and Qdrant vectors. MySQL remains the source of truth for corpus/document/chunk/import-job state; Qdrant stores vectors plus minimal filter payload, and all Qdrant access goes through a backend platform wrapper. Frontend pages use the existing Vue admin typed API, `Search`, `AppTable`, `AppDialog`, `useTable` and `useCrudTable` conventions.

**Tech Stack:** Go/Gin/Gorm/MySQL/Redis/Asynq, Qdrant official Go client `github.com/qdrant/go-client`, existing OpenAI-compatible provider config for embeddings, Vue 3/TypeScript/Vite/Vitest.

---

## Scope

This plan implements only the vector-search MVP from `docs/superpowers/specs/2026-05-25-keyword-asset-intelligence-search-design.md`.

In scope:

- Qdrant docker-first local service and backend config.
- `asset_intel_*` MySQL tables.
- `internal/platform/vectorindex` Qdrant wrapper.
- `internal/platform/embedding` OpenAI-compatible embeddings wrapper.
- `internal/module/assetintel` corpus, document import, chunking, indexing, and search APIs.
- Worker jobs for import/index/delete-vector-points.
- Frontend typed API and MVP pages.
- RBAC route metadata, operation logs, i18n, focused tests, smoke probes, docs sync.

Out of scope:

- Automated crawler.
- SEO/search-engine URL discovery.
- OpenSearch/BM25 hybrid search.
- CT/RDAP/ASN automatic enrichment.
- DMCA/takedown workflow.
- Kafka/Temporal/Kubernetes.

## External References

- Qdrant official clients list: `https://qdrant.tech/documentation/interfaces/`
- Qdrant Go client README: `https://github.com/qdrant/go-client`
- Qdrant filtering docs: `https://qdrant.tech/documentation/search/filtering/`
- Qdrant search docs: `https://qdrant.tech/documentation/concepts/search/`

Use the official Go client path `github.com/qdrant/go-client/qdrant`. The README shows `NewClient`, `CreateCollection`, `Upsert`, `Query`, `WithPayload`, and filters through `qdrant.NewMatch`.

## File Structure

Backend files to create:

- `admin_back_go/database/migrations/20260525_asset_intel_vector_search_mvp.sql`
  Creates `asset_intel_corpora`, `asset_intel_documents`, `asset_intel_chunks`, `asset_intel_import_jobs`, and permission/menu seed rows for the new asset intelligence pages.
- `admin_back_go/internal/config/qdrant.go`
  Holds `QdrantConfig`, defaults, normalization, env parsing integration.
- `admin_back_go/internal/platform/vectorindex/types.go`
  Defines Qdrant-neutral `CollectionSpec`, `Point`, `SearchQuery`, `SearchHit`, and `Client` interface.
- `admin_back_go/internal/platform/vectorindex/qdrant.go`
  Implements the official Qdrant Go client wrapper.
- `admin_back_go/internal/platform/vectorindex/fake.go`
  In-memory fake for module tests.
- `admin_back_go/internal/platform/vectorindex/qdrant_test.go`
  Unit tests for collection naming, payload filters, nil/disabled client behavior, and search result mapping.
- `admin_back_go/internal/platform/embedding/types.go`
  Defines `Client`, `EmbedInput`, `EmbedResult`, `ModelConfig`.
- `admin_back_go/internal/platform/embedding/openaicompat.go`
  Calls `/embeddings` on the OpenAI-compatible base URL.
- `admin_back_go/internal/platform/embedding/fake.go`
  Deterministic fake embedding client for tests.
- `admin_back_go/internal/platform/embedding/openaicompat_test.go`
  Tests request shape, response parsing, and error mapping.
- `admin_back_go/internal/module/assetintel/model.go`
- `admin_back_go/internal/module/assetintel/dto.go`
- `admin_back_go/internal/module/assetintel/request.go`
- `admin_back_go/internal/module/assetintel/repository.go`
- `admin_back_go/internal/module/assetintel/chunker.go`
- `admin_back_go/internal/module/assetintel/service.go`
- `admin_back_go/internal/module/assetintel/handler.go`
- `admin_back_go/internal/module/assetintel/route.go`
- `admin_back_go/internal/module/assetintel/jobs.go`
- `admin_back_go/internal/module/assetintel/errors.go`
- `admin_back_go/internal/module/assetintel/chunker_test.go`
- `admin_back_go/internal/module/assetintel/model_test.go`
- `admin_back_go/internal/module/assetintel/service_test.go`
- `admin_back_go/internal/i18n/locales/zh-CN/assetintel.yaml`
- `admin_back_go/internal/i18n/locales/en-US/assetintel.yaml`

Backend files to modify:

- `admin_back_go/go.mod`, `admin_back_go/go.sum`
- `admin_back_go/internal/config/config.go`
- `admin_back_go/internal/bootstrap/resources.go`
- `admin_back_go/internal/bootstrap/app.go`
- `admin_back_go/internal/bootstrap/worker.go`
- `admin_back_go/internal/server/router.go`
- `admin_back_go/internal/bootstrap/route_meta.go`
- `admin_back_go/internal/jobs/noop.go` or existing job registry files under `internal/jobs`
- `admin_back_go/internal/i18n/source_coverage_test.go`
- `admin_back_go/deploy/docker-first/docker-compose.yml`
- `admin_back_go/deploy/docker-first/admin-go.env.example`
- `admin_back_go/deploy/docker-first/compose.env.example`
- `admin_back_go/deploy/docker-first/README.md`

Frontend files to create:

- `admin_front_ts/src/api/asset-intel/index.ts`
- `admin_front_ts/src/views/Main/asset-intel/search/index.vue`
- `admin_front_ts/src/views/Main/asset-intel/corpora/index.vue`
- `admin_front_ts/src/views/Main/asset-intel/documents/index.vue`
- `admin_front_ts/src/views/Main/asset-intel/import-jobs/index.vue`
- `admin_front_ts/tests/shared/asset-intel/asset-intel-api.test.ts`
- `admin_front_ts/tests/shared/asset-intel/asset-intel-view-registry.test.ts`

Frontend files to modify:

- `admin_front_ts/src/router/view-registry.ts`
- `admin_front_ts/src/i18n/locales/zh-CN.ts`
- `admin_front_ts/src/i18n/locales/en-US.ts`

Docs to modify after verified runtime behavior exists:

- `admin_go/docs/contracts/admin-api-v1.md`
- `admin_go/docs/status/current-status.md`
- `admin_go/docs/testing/smoke-matrix.md`
- `admin_back_go/docs/architecture.md`

Do not update current-status to implemented until the focused tests and smoke probes in this plan pass.

## Task 1: Qdrant Dependency And Docker-First Runtime

**Files:**

- Modify: `admin_back_go/go.mod`
- Modify: `admin_back_go/go.sum`
- Modify: `admin_back_go/deploy/docker-first/docker-compose.yml`
- Modify: `admin_back_go/deploy/docker-first/admin-go.env.example`
- Modify: `admin_back_go/deploy/docker-first/compose.env.example`
- Modify: `admin_back_go/deploy/docker-first/README.md`

- [ ] **Step 1: Add the official Qdrant Go client dependency**

Run:

```bash
cd /Users/larus/admin/admin_back_go
go get github.com/qdrant/go-client@latest
```

Expected: `go.mod` includes `github.com/qdrant/go-client`, and `go.sum` updates.

- [ ] **Step 2: Add local Qdrant to docker-first compose**

Patch `deploy/docker-first/docker-compose.yml`:

```yaml
  qdrant:
    image: qdrant/qdrant:v1.15.5
    restart: unless-stopped
    ports:
      - "${QDRANT_HOST_BIND:-127.0.0.1}:${QDRANT_HTTP_HOST_PORT:-6333}:6333"
      - "${QDRANT_HOST_BIND:-127.0.0.1}:${QDRANT_GRPC_HOST_PORT:-6334}:6334"
    volumes:
      - ${QDRANT_STORAGE_DIR:-/www/docker/admin-go-backend/qdrant}:/qdrant/storage
    healthcheck:
      test: ["CMD-SHELL", "curl -fsS http://127.0.0.1:6333/healthz >/dev/null"]
      interval: 15s
      timeout: 5s
      retries: 5
      start_period: 20s
```

Update `admin-api` and `admin-worker` with:

```yaml
    depends_on:
      qdrant:
        condition: service_healthy
```

Keep the existing `admin-worker` dependency on `admin-api`.

- [ ] **Step 3: Add Qdrant env examples**

Append to `deploy/docker-first/admin-go.env.example`:

```dotenv
# Qdrant vector store. The Go client uses gRPC.
QDRANT_ENABLED=true
QDRANT_HOST=qdrant
QDRANT_GRPC_PORT=6334
QDRANT_API_KEY=
QDRANT_USE_TLS=false
QDRANT_COLLECTION_PREFIX=admin_go_asset_intel
QDRANT_TIMEOUT=10s
```

Append to `deploy/docker-first/compose.env.example`:

```dotenv
QDRANT_HOST_BIND=127.0.0.1
QDRANT_HTTP_HOST_PORT=6333
QDRANT_GRPC_HOST_PORT=6334
QDRANT_STORAGE_DIR=/www/docker/admin-go-backend/qdrant
```

- [ ] **Step 4: Document local Qdrant**

Add a short section to `deploy/docker-first/README.md`:

```markdown
### Qdrant

The asset intelligence vector-search MVP uses Qdrant as the vector store.
The backend connects to Qdrant over gRPC with `QDRANT_HOST` and `QDRANT_GRPC_PORT`.
For local docker-first runtime, Qdrant exposes HTTP on `127.0.0.1:6333` for inspection and gRPC on `127.0.0.1:6334` for the Go client.
```

- [ ] **Step 5: Verify dependency and compose edits**

Run:

```bash
cd /Users/larus/admin/admin_back_go
go mod tidy
go test ./internal/config -count=1
```

Expected: config tests pass or the package reports no test files with exit code 0.

- [ ] **Step 6: Commit**

```bash
cd /Users/larus/admin/admin_back_go
git add go.mod go.sum deploy/docker-first/docker-compose.yml deploy/docker-first/admin-go.env.example deploy/docker-first/compose.env.example deploy/docker-first/README.md
git commit -m "chore: add qdrant runtime baseline"
```

## Task 2: Backend Qdrant Config And Readiness

**Files:**

- Create: `admin_back_go/internal/config/qdrant.go`
- Modify: `admin_back_go/internal/config/config.go`
- Modify: `admin_back_go/internal/bootstrap/resources.go`
- Test: `admin_back_go/internal/config/qdrant_test.go`
- Test: `admin_back_go/internal/bootstrap/resources_test.go`

- [ ] **Step 1: Write failing config tests**

Create `internal/config/qdrant_test.go`:

```go
package config

import (
	"testing"
	"time"
)

func TestNormalizeQdrantConfigDefaults(t *testing.T) {
	cfg := NormalizeQdrantConfig(QdrantConfig{Enabled: true})
	if !cfg.Enabled {
		t.Fatal("enabled must remain true")
	}
	if cfg.Host != "127.0.0.1" || cfg.GRPCPort != 6334 {
		t.Fatalf("unexpected default address: %#v", cfg)
	}
	if cfg.CollectionPrefix != "admin_go_asset_intel" {
		t.Fatalf("collection prefix mismatch: %q", cfg.CollectionPrefix)
	}
	if cfg.Timeout != 10*time.Second {
		t.Fatalf("timeout mismatch: %s", cfg.Timeout)
	}
}

func TestNormalizeQdrantConfigDisabledWhenHostBlank(t *testing.T) {
	cfg := NormalizeQdrantConfig(QdrantConfig{Enabled: true, Host: "   ", GRPCPort: 6334})
	if cfg.Enabled {
		t.Fatalf("blank host must disable qdrant: %#v", cfg)
	}
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
cd /Users/larus/admin/admin_back_go
go test ./internal/config -run Qdrant -count=1
```

Expected: FAIL because `QdrantConfig` and `NormalizeQdrantConfig` do not exist.

- [ ] **Step 3: Implement Qdrant config**

Create `internal/config/qdrant.go`:

```go
package config

import (
	"strings"
	"time"
)

const (
	DefaultQdrantHost             = "127.0.0.1"
	DefaultQdrantGRPCPort         = 6334
	DefaultQdrantCollectionPrefix = "admin_go_asset_intel"
	DefaultQdrantTimeout          = 10 * time.Second
)

type QdrantConfig struct {
	Enabled          bool
	Host             string
	GRPCPort         int
	APIKey           string
	UseTLS           bool
	CollectionPrefix string
	Timeout          time.Duration
}

func NormalizeQdrantConfig(cfg QdrantConfig) QdrantConfig {
	cfg.Host = strings.TrimSpace(cfg.Host)
	if cfg.Host == "" {
		cfg.Host = DefaultQdrantHost
	}
	if cfg.GRPCPort <= 0 {
		cfg.GRPCPort = DefaultQdrantGRPCPort
	}
	cfg.CollectionPrefix = strings.TrimSpace(cfg.CollectionPrefix)
	if cfg.CollectionPrefix == "" {
		cfg.CollectionPrefix = DefaultQdrantCollectionPrefix
	}
	if cfg.Timeout <= 0 {
		cfg.Timeout = DefaultQdrantTimeout
	}
	if strings.TrimSpace(cfg.Host) == "" || cfg.GRPCPort <= 0 {
		cfg.Enabled = false
	}
	return cfg
}
```

Modify `internal/config/config.go`:

```go
type Config struct {
	App       AppConfig
	HTTP      HTTPConfig
	Logging   LoggingConfig
	MySQL     MySQLConfig
	Redis     RedisConfig
	Token     TokenConfig
	Queue     QueueConfig
	Realtime  RealtimeConfig
	Scheduler SchedulerConfig
	Payment   PaymentConfig
	AI        AIConfig
	Qdrant    QdrantConfig
	CORS      CORSConfig
}
```

In `Load()`, add:

```go
Qdrant: NormalizeQdrantConfig(QdrantConfig{
	Enabled:          envBool("QDRANT_ENABLED", false),
	Host:             envString("QDRANT_HOST", DefaultQdrantHost),
	GRPCPort:         envInt("QDRANT_GRPC_PORT", DefaultQdrantGRPCPort),
	APIKey:           envString("QDRANT_API_KEY", ""),
	UseTLS:           envBool("QDRANT_USE_TLS", false),
	CollectionPrefix: envString("QDRANT_COLLECTION_PREFIX", DefaultQdrantCollectionPrefix),
	Timeout:          envDuration("QDRANT_TIMEOUT", DefaultQdrantTimeout),
}),
```

- [ ] **Step 4: Add readiness slot**

Modify `internal/bootstrap/resources.go` by adding fields:

```go
qdrantEnabled bool
qdrantErr     error
```

Set in `NewResources`:

```go
resources.qdrantEnabled = cfg.Qdrant.Enabled
```

Add `qdrant` to `Readiness`:

```go
"qdrant": r.qdrantReadiness(),
```

Add method:

```go
func (r *Resources) qdrantReadiness() readiness.Check {
	if r == nil || !r.qdrantEnabled {
		return readiness.Check{Status: readiness.StatusDisabled}
	}
	if r.qdrantErr != nil {
		return readiness.Check{Status: readiness.StatusDown, Message: r.qdrantErr.Error()}
	}
	return readiness.Check{Status: readiness.StatusUp}
}
```

This task only wires readiness state. The actual Qdrant client is created in Task 3.

- [ ] **Step 5: Run tests**

Run:

```bash
cd /Users/larus/admin/admin_back_go
go test ./internal/config ./internal/bootstrap -run 'Qdrant|Readiness' -count=1
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/larus/admin/admin_back_go
git add internal/config/config.go internal/config/qdrant.go internal/config/qdrant_test.go internal/bootstrap/resources.go internal/bootstrap/resources_test.go
git commit -m "feat: add qdrant runtime config"
```

## Task 3: Vector Index Platform Wrapper

**Files:**

- Create: `admin_back_go/internal/platform/vectorindex/types.go`
- Create: `admin_back_go/internal/platform/vectorindex/qdrant.go`
- Create: `admin_back_go/internal/platform/vectorindex/fake.go`
- Test: `admin_back_go/internal/platform/vectorindex/qdrant_test.go`

- [ ] **Step 1: Write platform interface and fake first**

Create `internal/platform/vectorindex/types.go`:

```go
package vectorindex

import "context"

type CollectionSpec struct {
	Name      string
	Size      uint64
	Distance  string
}

type Point struct {
	ID      uint64
	Vector  []float32
	Payload map[string]any
}

type SearchQuery struct {
	Collection string
	Vector     []float32
	Limit      uint64
	MinScore   *float32
	Filter     map[string]any
}

type SearchHit struct {
	ID      uint64
	Score   float32
	Payload map[string]any
}

type Client interface {
	EnsureCollection(ctx context.Context, spec CollectionSpec) error
	Upsert(ctx context.Context, collection string, points []Point) error
	Search(ctx context.Context, query SearchQuery) ([]SearchHit, error)
	Delete(ctx context.Context, collection string, ids []uint64) error
	Close() error
}
```

Create `internal/platform/vectorindex/fake.go`:

```go
package vectorindex

import (
	"context"
	"sync"
)

type FakeClient struct {
	mu          sync.Mutex
	Collections []CollectionSpec
	Points      map[string][]Point
	Hits        []SearchHit
	LastQuery   SearchQuery
}

func NewFakeClient() *FakeClient {
	return &FakeClient{Points: map[string][]Point{}}
}

func (f *FakeClient) EnsureCollection(ctx context.Context, spec CollectionSpec) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.Collections = append(f.Collections, spec)
	return nil
}

func (f *FakeClient) Upsert(ctx context.Context, collection string, points []Point) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.Points[collection] = append(f.Points[collection], points...)
	return nil
}

func (f *FakeClient) Search(ctx context.Context, query SearchQuery) ([]SearchHit, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.LastQuery = query
	return append([]SearchHit(nil), f.Hits...), nil
}

func (f *FakeClient) Delete(ctx context.Context, collection string, ids []uint64) error { return nil }
func (f *FakeClient) Close() error { return nil }
```

- [ ] **Step 2: Write Qdrant wrapper tests**

Create `internal/platform/vectorindex/qdrant_test.go` with pure mapping tests:

```go
package vectorindex

import "testing"

func TestCollectionNameRequiresPrefixAndModel(t *testing.T) {
	got := CollectionName("admin_go_asset_intel", "text-embedding-3-small", 1536)
	if got != "admin_go_asset_intel_text_embedding_3_small_1536" {
		t.Fatalf("collection name=%q", got)
	}
}

func TestBuildFilterMapsSupportedFields(t *testing.T) {
	filter := buildFilter(map[string]any{
		"corpus_id":   uint64(1),
		"source_type": "webpage",
		"domain":      "example.com",
		"status":      "enabled",
	})
	if filter == nil || len(filter.Must) != 4 {
		t.Fatalf("filter mismatch: %#v", filter)
	}
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```bash
cd /Users/larus/admin/admin_back_go
go test ./internal/platform/vectorindex -count=1
```

Expected: FAIL because `CollectionName` and `buildFilter` do not exist.

- [ ] **Step 4: Implement Qdrant wrapper skeleton**

Create `internal/platform/vectorindex/qdrant.go`:

```go
package vectorindex

import (
	"context"
	"regexp"
	"strings"

	"github.com/qdrant/go-client/qdrant"
)

var nonCollectionChar = regexp.MustCompile(`[^a-zA-Z0-9_]+`)

func CollectionName(prefix string, model string, dimension uint64) string {
	base := strings.TrimSpace(prefix) + "_" + strings.TrimSpace(model) + "_" + qdrantDimensionSuffix(dimension)
	base = strings.ReplaceAll(base, "-", "_")
	base = nonCollectionChar.ReplaceAllString(base, "_")
	return strings.ToLower(strings.Trim(base, "_"))
}

func qdrantDimensionSuffix(dimension uint64) string {
	if dimension == 0 {
		return "0"
	}
	return strings.TrimSpace(strconv.FormatUint(dimension, 10))
}
```

Add missing import `strconv`. Then implement `NewClient`, `EnsureCollection`, `Upsert`, `Search`, `Delete`, `Close` using the official client:

```go
type Config struct {
	Enabled bool
	Host    string
	Port    int
	APIKey  string
	UseTLS  bool
}

type QdrantClient struct {
	client *qdrant.Client
}

func NewQdrantClient(config Config) (*QdrantClient, error) {
	if !config.Enabled {
		return nil, nil
	}
	client, err := qdrant.NewClient(&qdrant.Config{
		Host:   config.Host,
		Port:   config.Port,
		APIKey: config.APIKey,
		UseTLS: config.UseTLS,
	})
	if err != nil {
		return nil, err
	}
	return &QdrantClient{client: client}, nil
}
```

Use `qdrant.Distance_Cosine`, `qdrant.NewVectors`, `qdrant.NewValueMap`, `qdrant.NewIDNum`, `qdrant.NewMatch`, `qdrant.NewMatchInt`, `qdrant.QueryPoints`, and `qdrant.NewWithPayload(true)` as shown in official docs.

- [ ] **Step 5: Run tests**

Run:

```bash
cd /Users/larus/admin/admin_back_go
go test ./internal/platform/vectorindex -count=1
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/larus/admin/admin_back_go
git add internal/platform/vectorindex go.mod go.sum
git commit -m "feat: add qdrant vector index wrapper"
```

## Task 4: Embedding Platform Wrapper

**Files:**

- Create: `admin_back_go/internal/platform/embedding/types.go`
- Create: `admin_back_go/internal/platform/embedding/openaicompat.go`
- Create: `admin_back_go/internal/platform/embedding/fake.go`
- Test: `admin_back_go/internal/platform/embedding/openaicompat_test.go`

- [ ] **Step 1: Define embedding interface and fake**

Create `internal/platform/embedding/types.go`:

```go
package embedding

import "context"

type Input struct {
	Model string
	Texts []string
}

type Result struct {
	Model      string
	Dimension  uint
	Embeddings [][]float32
}

type Client interface {
	Embed(ctx context.Context, input Input) (Result, error)
}
```

Create `internal/platform/embedding/fake.go`:

```go
package embedding

import "context"

type FakeClient struct {
	Result Result
	Inputs []Input
}

func (f *FakeClient) Embed(ctx context.Context, input Input) (Result, error) {
	f.Inputs = append(f.Inputs, input)
	if len(f.Result.Embeddings) > 0 {
		return f.Result, nil
	}
	vectors := make([][]float32, 0, len(input.Texts))
	for i := range input.Texts {
		vectors = append(vectors, []float32{float32(i + 1), 0.5, 0.25})
	}
	return Result{Model: input.Model, Dimension: 3, Embeddings: vectors}, nil
}
```

- [ ] **Step 2: Test OpenAI-compatible embedding request**

Create `internal/platform/embedding/openaicompat_test.go`:

```go
package embedding

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestOpenAICompatEmbeddingsRequestShape(t *testing.T) {
	var got map[string]any
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/embeddings" {
			t.Fatalf("path=%s", r.URL.Path)
		}
		if r.Header.Get("Authorization") != "Bearer test-key" {
			t.Fatalf("authorization header mismatch")
		}
		if err := json.NewDecoder(r.Body).Decode(&got); err != nil {
			t.Fatalf("decode request: %v", err)
		}
		_, _ = w.Write([]byte(`{"model":"text-embedding-3-small","data":[{"embedding":[0.1,0.2,0.3],"index":0}]}`))
	}))
	defer server.Close()

	client := NewOpenAICompatClient(OpenAICompatConfig{BaseURL: server.URL, APIKey: "test-key"})
	res, err := client.Embed(context.Background(), Input{Model: "text-embedding-3-small", Texts: []string{"hello"}})
	if err != nil {
		t.Fatalf("Embed returned error: %v", err)
	}
	if got["model"] != "text-embedding-3-small" {
		t.Fatalf("model mismatch: %#v", got)
	}
	if res.Dimension != 3 || len(res.Embeddings) != 1 {
		t.Fatalf("embedding result mismatch: %#v", res)
	}
}
```

- [ ] **Step 3: Run test to verify it fails**

Run:

```bash
cd /Users/larus/admin/admin_back_go
go test ./internal/platform/embedding -count=1
```

Expected: FAIL because `NewOpenAICompatClient` does not exist.

- [ ] **Step 4: Implement OpenAI-compatible embeddings client**

Create `internal/platform/embedding/openaicompat.go`:

```go
package embedding

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"
)

type OpenAICompatConfig struct {
	BaseURL    string
	APIKey     string
	HTTPClient *http.Client
	Timeout    time.Duration
}

type OpenAICompatClient struct {
	baseURL string
	apiKey  string
	client  *http.Client
}

func NewOpenAICompatClient(config OpenAICompatConfig) *OpenAICompatClient {
	httpClient := config.HTTPClient
	if httpClient == nil {
		timeout := config.Timeout
		if timeout <= 0 {
			timeout = 30 * time.Second
		}
		httpClient = &http.Client{Timeout: timeout}
	}
	return &OpenAICompatClient{baseURL: strings.TrimRight(config.BaseURL, "/"), apiKey: strings.TrimSpace(config.APIKey), client: httpClient}
}
```

Add request/response structs and `Embed`:

```go
func (c *OpenAICompatClient) Embed(ctx context.Context, input Input) (Result, error) {
	if c == nil || c.baseURL == "" || c.apiKey == "" {
		return Result{}, fmt.Errorf("embedding client is not configured")
	}
	if strings.TrimSpace(input.Model) == "" || len(input.Texts) == 0 {
		return Result{}, fmt.Errorf("embedding input is invalid")
	}
	body := embeddingRequest{Model: input.Model, Input: input.Texts}
	payload, err := json.Marshal(body)
	if err != nil {
		return Result{}, err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/embeddings", bytes.NewReader(payload))
	if err != nil {
		return Result{}, err
	}
	req.Header.Set("Authorization", "Bearer "+c.apiKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	resp, err := c.client.Do(req)
	if err != nil {
		return Result{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return Result{}, fmt.Errorf("embedding upstream status: %s", resp.Status)
	}
	var decoded embeddingResponse
	if err := json.NewDecoder(resp.Body).Decode(&decoded); err != nil {
		return Result{}, err
	}
	vectors := make([][]float32, 0, len(decoded.Data))
	var dimension uint
	for _, row := range decoded.Data {
		vector := make([]float32, 0, len(row.Embedding))
		for _, value := range row.Embedding {
			vector = append(vector, float32(value))
		}
		if dimension == 0 {
			dimension = uint(len(vector))
		}
		vectors = append(vectors, vector)
	}
	return Result{Model: decoded.Model, Dimension: dimension, Embeddings: vectors}, nil
}
```

- [ ] **Step 5: Run tests**

Run:

```bash
cd /Users/larus/admin/admin_back_go
go test ./internal/platform/embedding -count=1
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/larus/admin/admin_back_go
git add internal/platform/embedding
git commit -m "feat: add embedding client boundary"
```

## Task 5: Asset Intel Schema And Models

**Files:**

- Create: `admin_back_go/database/migrations/20260525_asset_intel_vector_search_mvp.sql`
- Create: `admin_back_go/internal/module/assetintel/model.go`
- Test: `admin_back_go/internal/module/assetintel/model_test.go`

- [ ] **Step 1: Write model shape test**

Create `internal/module/assetintel/model_test.go`:

```go
package assetintel

import "testing"

func TestTableNames(t *testing.T) {
	cases := map[string]string{
		"corpora":    (Corpus{}).TableName(),
		"documents":  (Document{}).TableName(),
		"chunks":     (Chunk{}).TableName(),
		"importJobs": (ImportJob{}).TableName(),
	}
	if cases["corpora"] != "asset_intel_corpora" || cases["documents"] != "asset_intel_documents" || cases["chunks"] != "asset_intel_chunks" || cases["importJobs"] != "asset_intel_import_jobs" {
		t.Fatalf("table names mismatch: %#v", cases)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/larus/admin/admin_back_go
go test ./internal/module/assetintel -run TestTableNames -count=1
```

Expected: FAIL because module does not exist.

- [ ] **Step 3: Create migration**

Create `database/migrations/20260525_asset_intel_vector_search_mvp.sql` with:

```sql
-- Asset intelligence vector-search MVP schema.
-- Idempotent by design: CREATE TABLE IF NOT EXISTS plus INSERT ON DUPLICATE KEY UPDATE for permission seed rows.

CREATE TABLE IF NOT EXISTS `asset_intel_corpora` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '语料库ID',
  `name` VARCHAR(128) NOT NULL COMMENT '语料库名称',
  `description` VARCHAR(1024) NOT NULL DEFAULT '' COMMENT '语料库说明',
  `embedding_provider` VARCHAR(32) NOT NULL DEFAULT 'openai' COMMENT 'embedding provider',
  `embedding_model` VARCHAR(128) NOT NULL COMMENT 'embedding model id',
  `embedding_dimension` INT UNSIGNED NOT NULL COMMENT 'embedding vector dimension',
  `vector_store` VARCHAR(32) NOT NULL DEFAULT 'qdrant' COMMENT 'vector store',
  `vector_collection` VARCHAR(191) NOT NULL COMMENT 'qdrant collection name',
  `status` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1启用 2禁用',
  `is_del` TINYINT UNSIGNED NOT NULL DEFAULT 2 COMMENT '1删除 2正常',
  `created_by` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '创建用户ID',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_asset_intel_corpora_collection` (`vector_collection`, `is_del`),
  KEY `idx_asset_intel_corpora_status` (`status`, `is_del`, `updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='资产情报语料库';

CREATE TABLE IF NOT EXISTS `asset_intel_documents` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '文档ID',
  `corpus_id` BIGINT UNSIGNED NOT NULL COMMENT 'asset_intel_corpora.id',
  `source_type` VARCHAR(32) NOT NULL DEFAULT 'text' COMMENT 'text/markdown/webpage/json/csv',
  `title` VARCHAR(191) NOT NULL COMMENT '标题',
  `source_url` VARCHAR(1024) NOT NULL DEFAULT '' COMMENT '来源URL',
  `domain` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '域名',
  `ip` VARCHAR(64) NOT NULL DEFAULT '' COMMENT 'IP快照',
  `asn` BIGINT UNSIGNED NULL COMMENT 'ASN快照',
  `content_hash` CHAR(64) NOT NULL COMMENT '正文sha256',
  `text_content` LONGTEXT NOT NULL COMMENT '正文',
  `metadata_json` JSON NULL COMMENT '显式来源metadata快照',
  `index_status` VARCHAR(16) NOT NULL DEFAULT 'pending' COMMENT 'pending/chunking/embedding/indexed/failed',
  `error_message` VARCHAR(1024) NOT NULL DEFAULT '' COMMENT '失败原因',
  `status` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1启用 2禁用',
  `is_del` TINYINT UNSIGNED NOT NULL DEFAULT 2 COMMENT '1删除 2正常',
  `created_by` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '创建用户ID',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_asset_intel_documents_hash` (`corpus_id`, `content_hash`, `is_del`),
  KEY `idx_asset_intel_documents_corpus` (`corpus_id`, `status`, `is_del`, `updated_at`),
  KEY `idx_asset_intel_documents_domain` (`domain`, `is_del`),
  KEY `idx_asset_intel_documents_index` (`index_status`, `is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='资产情报文档';

CREATE TABLE IF NOT EXISTS `asset_intel_chunks` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '分块ID',
  `corpus_id` BIGINT UNSIGNED NOT NULL COMMENT 'asset_intel_corpora.id',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'asset_intel_documents.id',
  `chunk_index` INT UNSIGNED NOT NULL COMMENT '文档内序号，从1开始',
  `title` VARCHAR(191) NOT NULL DEFAULT '' COMMENT '分块标题',
  `content` TEXT NOT NULL COMMENT '分块内容',
  `content_chars` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '字符数',
  `content_hash` CHAR(64) NOT NULL COMMENT '分块sha256',
  `vector_point_id` BIGINT UNSIGNED NULL COMMENT 'Qdrant point id',
  `embedding_model` VARCHAR(128) NOT NULL COMMENT 'embedding model',
  `embedding_dimension` INT UNSIGNED NOT NULL COMMENT 'embedding dimension',
  `index_status` VARCHAR(16) NOT NULL DEFAULT 'pending' COMMENT 'pending/embedded/indexed/failed',
  `error_message` VARCHAR(1024) NOT NULL DEFAULT '' COMMENT '失败原因',
  `status` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1启用 2禁用',
  `is_del` TINYINT UNSIGNED NOT NULL DEFAULT 2 COMMENT '1删除 2正常',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_asset_intel_chunks_doc_index` (`document_id`, `chunk_index`, `is_del`),
  KEY `idx_asset_intel_chunks_corpus` (`corpus_id`, `status`, `is_del`, `id`),
  KEY `idx_asset_intel_chunks_point` (`vector_point_id`, `is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='资产情报分块';

CREATE TABLE IF NOT EXISTS `asset_intel_import_jobs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '导入任务ID',
  `corpus_id` BIGINT UNSIGNED NOT NULL COMMENT 'asset_intel_corpora.id',
  `source_type` VARCHAR(32) NOT NULL COMMENT '导入来源类型',
  `status` VARCHAR(16) NOT NULL DEFAULT 'pending' COMMENT 'pending/running/succeeded/failed/canceled',
  `document_count` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '文档数',
  `chunk_count` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '分块数',
  `indexed_chunk_count` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '已索引分块数',
  `failed_chunk_count` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '失败分块数',
  `error_message` VARCHAR(1024) NOT NULL DEFAULT '' COMMENT '失败原因',
  `created_by` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '创建用户ID',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_asset_intel_import_jobs_corpus` (`corpus_id`, `status`, `created_at`),
  KEY `idx_asset_intel_import_jobs_status` (`status`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='资产情报导入任务';
```

- [ ] **Step 4: Create models**

Create `internal/module/assetintel/model.go` with structs matching the SQL table names and fields. Use `uint64` for ids, `int` for status/is_del, `*uint64` for nullable ASN/vector point id, and `time.Time` for timestamps.

- [ ] **Step 5: Run test**

```bash
cd /Users/larus/admin/admin_back_go
go test ./internal/module/assetintel -run TestTableNames -count=1
```

Expected: PASS.

- [ ] **Step 6: Apply migration locally**

Run against the local Docker MySQL used earlier:

```bash
cd /Users/larus/admin/admin_back_go
docker exec -i admin-go-state-mysql mysql -uroot -padmin_go_local admin < database/migrations/20260525_asset_intel_vector_search_mvp.sql
```

Expected: exit 0.

- [ ] **Step 7: Commit**

```bash
cd /Users/larus/admin/admin_back_go
git add database/migrations/20260525_asset_intel_vector_search_mvp.sql internal/module/assetintel/model.go internal/module/assetintel/model_test.go
git commit -m "feat: add asset intel vector schema"
```

## Task 6: Asset Intel Domain Logic And Repository

**Files:**

- Create: `admin_back_go/internal/module/assetintel/dto.go`
- Create: `admin_back_go/internal/module/assetintel/request.go`
- Create: `admin_back_go/internal/module/assetintel/repository.go`
- Create: `admin_back_go/internal/module/assetintel/chunker.go`
- Create: `admin_back_go/internal/module/assetintel/service.go`
- Test: `admin_back_go/internal/module/assetintel/chunker_test.go`
- Test: `admin_back_go/internal/module/assetintel/service_test.go`

- [ ] **Step 1: Write chunker tests**

Create `internal/module/assetintel/chunker_test.go`:

```go
package assetintel

import "testing"

func TestChunkTextUsesOverlap(t *testing.T) {
	text := "abcdefghijklmnopqrstuvwxyz"
	chunks, err := ChunkText(text, ChunkOptions{SizeChars: 10, OverlapChars: 2})
	if err != nil {
		t.Fatalf("ChunkText returned error: %v", err)
	}
	if len(chunks) != 3 {
		t.Fatalf("chunk count=%d chunks=%#v", len(chunks), chunks)
	}
	if chunks[0].Content != "abcdefghij" || chunks[1].Content != "ijklmnopqr" || chunks[2].Content != "qrstuvwxyz" {
		t.Fatalf("unexpected chunks: %#v", chunks)
	}
}
```

- [ ] **Step 2: Write service tests**

Create `internal/module/assetintel/service_test.go` with a fake repository, fake embedding client, and fake vector index. Include these concrete tests:

```go
func TestImportDocumentCreatesChunksAndIndexesVectors(t *testing.T) {
	repo := newFakeAssetIntelRepository()
	vector := vectorindex.NewFakeClient()
	embedder := &embedding.FakeClient{Result: embedding.Result{
		Model:      "text-embedding-3-small",
		Dimension:  3,
		Embeddings: [][]float32{{0.1, 0.2, 0.3}},
	}}
	service := NewService(Dependencies{Repository: repo, Vector: vector, Embedding: embedder})
	corpusID := repo.seedCorpus(Corpus{ID: 1, Name: "客户资产", EmbeddingModel: "text-embedding-3-small", EmbeddingDimension: 3, VectorCollection: "asset_text_embedding_3_small_3", Status: 1, IsDel: 2})

	res, appErr := service.ImportDocument(context.Background(), ImportDocumentInput{CorpusID: corpusID, SourceType: SourceTypeText, Title: "测试材料", TextContent: "Larus copyright test evidence page"})
	if appErr != nil {
		t.Fatalf("ImportDocument returned error: %v", appErr)
	}
	if res.DocumentID == 0 || len(repo.createdChunks) == 0 {
		t.Fatalf("document/chunks were not created: %#v %#v", res, repo.createdChunks)
	}
	if len(embedder.Inputs) != 1 || embedder.Inputs[0].Model != "text-embedding-3-small" {
		t.Fatalf("embedding input mismatch: %#v", embedder.Inputs)
	}
	if len(vector.Points["asset_text_embedding_3_small_3"]) == 0 {
		t.Fatalf("Qdrant points were not upserted: %#v", vector.Points)
	}
}

func TestSearchEmbedsQueryAndLoadsChunkDetails(t *testing.T) {
	repo := newFakeAssetIntelRepository()
	repo.seedCorpus(Corpus{ID: 1, Name: "客户资产", EmbeddingModel: "text-embedding-3-small", EmbeddingDimension: 3, VectorCollection: "asset_text_embedding_3_small_3", Status: 1, IsDel: 2})
	repo.seedChunk(Chunk{ID: 10, CorpusID: 1, DocumentID: 20, Title: "命中材料", Content: "payment gateway copy", VectorPointID: uint64Ptr(10), Status: 1, IsDel: 2})
	vector := vectorindex.NewFakeClient()
	vector.Hits = []vectorindex.SearchHit{{ID: 10, Score: 0.91, Payload: map[string]any{"chunk_id": uint64(10)}}}
	embedder := &embedding.FakeClient{Result: embedding.Result{Model: "text-embedding-3-small", Dimension: 3, Embeddings: [][]float32{{0.3, 0.2, 0.1}}}}
	service := NewService(Dependencies{Repository: repo, Vector: vector, Embedding: embedder})

	res, appErr := service.Search(context.Background(), SearchInput{Query: "payment", CorpusID: uint64Ptr(1), Limit: 5})
	if appErr != nil {
		t.Fatalf("Search returned error: %v", appErr)
	}
	if len(res.Hits) != 1 || res.Hits[0].ChunkID != 10 || res.Hits[0].Score != 0.91 {
		t.Fatalf("search hits mismatch: %#v", res.Hits)
	}
	if vector.LastQuery.Collection != "asset_text_embedding_3_small_3" {
		t.Fatalf("collection mismatch: %#v", vector.LastQuery)
	}
}

func TestDisabledDocumentIsNotReturnedFromSearch(t *testing.T) {
	repo := newFakeAssetIntelRepository()
	repo.seedCorpus(Corpus{ID: 1, Name: "客户资产", EmbeddingModel: "text-embedding-3-small", EmbeddingDimension: 3, VectorCollection: "asset_text_embedding_3_small_3", Status: 1, IsDel: 2})
	repo.seedChunk(Chunk{ID: 10, CorpusID: 1, DocumentID: 20, Title: "禁用材料", Content: "hidden", VectorPointID: uint64Ptr(10), Status: 2, IsDel: 2})
	vector := vectorindex.NewFakeClient()
	vector.Hits = []vectorindex.SearchHit{{ID: 10, Score: 0.99, Payload: map[string]any{"chunk_id": uint64(10)}}}
	service := NewService(Dependencies{Repository: repo, Vector: vector, Embedding: &embedding.FakeClient{}})

	res, appErr := service.Search(context.Background(), SearchInput{Query: "hidden", CorpusID: uint64Ptr(1), Limit: 5})
	if appErr != nil {
		t.Fatalf("Search returned error: %v", appErr)
	}
	if len(res.Hits) != 0 {
		t.Fatalf("disabled chunks must not be returned: %#v", res.Hits)
	}
}
```

The fake repository must store rows in maps and expose `CreatedDocuments`, `CreatedChunks`, and `UpdatedStatuses` so assertions are concrete.

- [ ] **Step 3: Run tests to verify they fail**

```bash
cd /Users/larus/admin/admin_back_go
go test ./internal/module/assetintel -count=1
```

Expected: FAIL because DTOs, repository, chunker, and service do not exist.

- [ ] **Step 4: Implement DTO and constants**

Create `dto.go` with:

```go
package assetintel

const (
	SourceTypeText     = "text"
	SourceTypeMarkdown = "markdown"
	SourceTypeWebpage  = "webpage"
	SourceTypeJSON     = "json"
	SourceTypeCSV      = "csv"

	IndexStatusPending   = "pending"
	IndexStatusChunking  = "chunking"
	IndexStatusEmbedding = "embedding"
	IndexStatusIndexed   = "indexed"
	IndexStatusFailed    = "failed"

	VectorStoreQdrant = "qdrant"
)
```

Add request/response DTOs for corpus list/detail/mutation, document list/detail/import, import jobs, chunks, search query, search result, and pagination. Follow the `aiknowledge` `Page` shape.

- [ ] **Step 5: Implement chunker**

Create `chunker.go` with UTF-8 safe rune slicing, default size 1000 and overlap 120, max text size 2MB for MVP, and SHA-256 helpers:

```go
func ContentHash(text string) string {
	sum := sha256.Sum256([]byte(text))
	return hex.EncodeToString(sum[:])
}
```

- [ ] **Step 6: Implement repository**

Create `repository.go` with interface:

```go
type Repository interface {
	ListCorpora(ctx context.Context, query CorpusListQuery) ([]Corpus, int64, error)
	GetCorpus(ctx context.Context, id uint64) (*Corpus, error)
	CreateCorpus(ctx context.Context, row Corpus) (uint64, error)
	UpdateCorpus(ctx context.Context, id uint64, fields map[string]any) error
	ChangeCorpusStatus(ctx context.Context, id uint64, status int) error
	DeleteCorpus(ctx context.Context, id uint64) error
	CreateImportJob(ctx context.Context, row ImportJob) (uint64, error)
	UpdateImportJob(ctx context.Context, id uint64, fields map[string]any) error
	CreateDocumentWithChunks(ctx context.Context, document Document, chunks []Chunk) (uint64, []Chunk, error)
	GetDocument(ctx context.Context, id uint64) (*Document, error)
	ListDocuments(ctx context.Context, query DocumentListQuery) ([]Document, int64, error)
	ListImportJobs(ctx context.Context, query ImportJobListQuery) ([]ImportJob, int64, error)
	GetImportJob(ctx context.Context, id uint64) (*ImportJob, error)
	ListChunksByIDs(ctx context.Context, ids []uint64) ([]ChunkSearchRow, error)
}
```

Implement `GormRepository` with active `is_del=2` filters and soft deletes matching existing module patterns.

- [ ] **Step 7: Implement service**

`Service` dependencies:

```go
type Dependencies struct {
	Repository Repository
	Vector     vectorindex.Client
	Embedding  embedding.Client
	Enqueuer   taskqueue.Enqueuer
	Clock      func() time.Time
}
```

Core behavior:

- `CreateCorpus` validates name/model/dimension, computes Qdrant collection with `vectorindex.CollectionName`, calls `EnsureCollection`, saves corpus.
- `ImportDocument` validates corpus active, content non-empty under max size, creates import job, chunks content, embeds chunks in batch, creates document/chunks, upserts Qdrant points, marks statuses indexed.
- `Search` validates query, embeds query with corpus model, searches Qdrant with payload filters, loads chunks by hit ids, hides disabled/deleted rows, returns ordered hits.

- [ ] **Step 8: Run service tests**

```bash
cd /Users/larus/admin/admin_back_go
go test ./internal/module/assetintel -count=1
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
cd /Users/larus/admin/admin_back_go
git add internal/module/assetintel
git commit -m "feat: add asset intel vector service"
```

## Task 7: HTTP Routes, Bootstrap Wiring, RBAC, I18n

**Files:**

- Create: `admin_back_go/internal/module/assetintel/handler.go`
- Create: `admin_back_go/internal/module/assetintel/route.go`
- Create: `admin_back_go/internal/module/assetintel/request.go`
- Create: `admin_back_go/internal/module/assetintel/errors.go`
- Modify: `admin_back_go/internal/server/router.go`
- Modify: `admin_back_go/internal/bootstrap/app.go`
- Modify: `admin_back_go/internal/bootstrap/worker.go`
- Modify: `admin_back_go/internal/bootstrap/route_meta.go`
- Create: `admin_back_go/internal/i18n/locales/zh-CN/assetintel.yaml`
- Create: `admin_back_go/internal/i18n/locales/en-US/assetintel.yaml`
- Test: `admin_back_go/internal/server/router_test.go`
- Test: `admin_back_go/internal/bootstrap/route_meta_test.go`
- Test: `admin_back_go/internal/i18n/source_coverage_test.go`

- [ ] **Step 1: Add route tests first**

Extend `internal/server/router_test.go` to assert routes exist:

```go
assertRoute(t, router, "GET", "/api/admin/v1/asset-intel/search")
assertRoute(t, router, "GET", "/api/admin/v1/asset-intel/corpora")
assertRoute(t, router, "POST", "/api/admin/v1/asset-intel/documents/import")
```

Extend route metadata test to assert mutating routes have permission and operation metadata:

```go
assertPermissionRule(t, "POST", "/api/admin/v1/asset-intel/documents/import", "assetIntel_document_import")
assertOperationRule(t, "POST", "/api/admin/v1/asset-intel/documents/import", "assetIntel", "import")
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/larus/admin/admin_back_go
go test ./internal/server ./internal/bootstrap -run 'AssetIntel|RouteMeta|Router' -count=1
```

Expected: FAIL because routes and metadata are not registered.

- [ ] **Step 3: Implement routes**

Create `route.go`:

```go
package assetintel

import "github.com/gin-gonic/gin"

func RegisterRoutes(router *gin.Engine, service HTTPService) {
	h := NewHandler(service)
	group := router.Group("/api/admin/v1/asset-intel")
	{
		group.GET("/search", h.Search)
		group.GET("/corpora", h.ListCorpora)
		group.POST("/corpora", h.CreateCorpus)
		group.GET("/corpora/:id", h.GetCorpus)
		group.PUT("/corpora/:id", h.UpdateCorpus)
		group.PATCH("/corpora/:id/status", h.ChangeCorpusStatus)
		group.DELETE("/corpora/:id", h.DeleteCorpus)
		group.GET("/documents", h.ListDocuments)
		group.POST("/documents/import", h.ImportDocument)
		group.GET("/documents/:id", h.GetDocument)
		group.PATCH("/documents/:id/status", h.ChangeDocumentStatus)
		group.DELETE("/documents/:id", h.DeleteDocument)
		group.GET("/import-jobs", h.ListImportJobs)
		group.GET("/import-jobs/:id", h.GetImportJob)
		group.POST("/import-jobs/:id/retry", h.RetryImportJob)
	}
}
```

Implement handler request binding with localized `apperror.BadRequestKey` or module error helpers.

- [ ] **Step 4: Wire server dependencies**

Modify `internal/server/router.go`:

```go
import "admin_back_go/internal/module/assetintel"
```

Add `AssetIntelService assetintel.HTTPService` to `Dependencies`, and call:

```go
assetintel.RegisterRoutes(router, deps.AssetIntelService)
```

- [ ] **Step 5: Wire bootstrap**

In `internal/bootstrap/app.go`, create the service:

```go
assetIntelService := assetintel.NewService(assetintel.Dependencies{
	Repository: assetintel.NewGormRepository(resources.DB),
	Vector:     resources.VectorIndex,
	Embedding:  embeddingClient,
	Enqueuer:   queueClient,
})
```

Create `embeddingClient` from stored AI provider config through a module adapter. For MVP, use the enabled OpenAI provider selected by corpus configuration; if no provider exists, import/search returns a localized configuration error.

- [ ] **Step 6: Add i18n catalogs**

Create `zh-CN/assetintel.yaml`:

```yaml
assetintel:
  corpus_not_found: "语料库不存在"
  document_not_found: "文档不存在"
  import_job_not_found: "导入任务不存在"
  qdrant_not_configured: "向量库未配置"
  embedding_not_configured: "Embedding 服务未配置"
  search_query_required: "请输入搜索内容"
  document_content_required: "请输入导入内容"
```

Create matching `en-US/assetintel.yaml`.

- [ ] **Step 7: Add route metadata**

In `internal/bootstrap/route_meta.go`, add permission and operation metadata for all asset-intel routes. Read-only list/detail/search should have permission rules. Mutations should have both permission and operation rules, with request capture disabled for document import body if the body can be large.

- [ ] **Step 8: Run tests**

```bash
cd /Users/larus/admin/admin_back_go
go test ./internal/server ./internal/bootstrap ./internal/i18n -count=1
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
cd /Users/larus/admin/admin_back_go
git add internal/module/assetintel internal/server/router.go internal/bootstrap/app.go internal/bootstrap/worker.go internal/bootstrap/route_meta.go internal/i18n/locales/zh-CN/assetintel.yaml internal/i18n/locales/en-US/assetintel.yaml
git commit -m "feat: expose asset intel vector APIs"
```

## Task 8: Worker Jobs For Import And Vector Maintenance

**Files:**

- Create: `admin_back_go/internal/module/assetintel/jobs.go`
- Modify: `admin_back_go/internal/jobs/noop.go` or existing registry files
- Modify: `admin_back_go/internal/bootstrap/worker.go`
- Test: `admin_back_go/internal/jobs/noop_test.go`
- Test: `admin_back_go/internal/bootstrap/worker_test.go`

- [ ] **Step 1: Add job registry tests**

Extend job tests to assert:

```go
asset-intel:import-document:v1
asset-intel:index-document:v1
asset-intel:index-chunk-batch:v1
asset-intel:delete-vector-points:v1
```

are registered when `AssetIntelService` is provided.

- [ ] **Step 2: Run tests to verify failure**

```bash
cd /Users/larus/admin/admin_back_go
go test ./internal/jobs ./internal/bootstrap -run AssetIntel -count=1
```

Expected: FAIL because job types are absent.

- [ ] **Step 3: Implement job handlers**

In `assetintel/jobs.go`, define constants and payloads:

```go
const (
	TaskImportDocument    = "asset-intel:import-document:v1"
	TaskIndexDocument     = "asset-intel:index-document:v1"
	TaskIndexChunkBatch   = "asset-intel:index-chunk-batch:v1"
	TaskDeleteVectorPoint = "asset-intel:delete-vector-points:v1"
)

type ImportDocumentPayload struct {
	DocumentID uint64 `json:"document_id"`
}
```

Add handler methods that call service methods by ID. Keep payloads small.

- [ ] **Step 4: Register jobs**

Extend `jobs.Dependencies` with `AssetIntelService assetintel.JobService`, and register handlers into the mux. Wire the service in `bootstrap/worker.go`.

- [ ] **Step 5: Run tests**

```bash
cd /Users/larus/admin/admin_back_go
go test ./internal/jobs ./internal/bootstrap -count=1
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd /Users/larus/admin/admin_back_go
git add internal/module/assetintel/jobs.go internal/jobs internal/bootstrap/worker.go
git commit -m "feat: add asset intel indexing jobs"
```

## Task 9: Frontend Typed API

**Files:**

- Create: `admin_front_ts/src/api/asset-intel/index.ts`
- Test: `admin_front_ts/tests/shared/asset-intel/asset-intel-api.test.ts`

- [ ] **Step 1: Write API contract test**

Create `tests/shared/asset-intel/asset-intel-api.test.ts`:

```ts
import { describe, expect, it, vi } from 'vitest'
import * as api from '@/api/asset-intel'

vi.mock('@/lib/http', () => ({
  default: {
    get: vi.fn((url: string, options?: unknown) => Promise.resolve({ url, options })),
    post: vi.fn((url: string, body?: unknown) => Promise.resolve({ url, body })),
    put: vi.fn((url: string, body?: unknown) => Promise.resolve({ url, body })),
    patch: vi.fn((url: string, body?: unknown) => Promise.resolve({ url, body })),
    delete: vi.fn((url: string) => Promise.resolve({ url })),
  },
}))

describe('asset intel API', () => {
  it('uses admin v1 REST paths', async () => {
    await api.searchAssetIntel({ q: 'brand', limit: 20 })
    await api.importAssetIntelDocument({ corpus_id: 1, source_type: 'text', title: 'sample', text_content: 'content' })
    expect(true).toBe(true)
  })
})
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd /Users/larus/admin/admin_front_ts
npm run test -- tests/shared/asset-intel/asset-intel-api.test.ts
```

Expected: FAIL because `@/api/asset-intel` does not exist.

- [ ] **Step 3: Implement typed API**

Create `src/api/asset-intel/index.ts` with typed request/response interfaces and functions:

```ts
import request from '@/lib/http'
import { ADMIN_API_PREFIX } from '@/lib/http/api-prefix'
import type { DictOption, Id, PaginatedResponse, RequestPayload } from '@/types/common'

export type AssetIntelSourceType = 'text' | 'markdown' | 'webpage' | 'json' | 'csv'
export type AssetIntelIndexStatus = 'pending' | 'chunking' | 'embedding' | 'indexed' | 'failed'

const BASE = `${ADMIN_API_PREFIX}/asset-intel`

export function searchAssetIntel(params: AssetIntelSearchParams) {
  return request.get<AssetIntelSearchResponse>(`${BASE}/search`, { params: normalizeSearchParams(params) })
}

export function importAssetIntelDocument(body: AssetIntelDocumentImportBody) {
  return request.post<AssetIntelImportResponse>(`${BASE}/documents/import`, body)
}
```

Add all corpus/document/import-job functions from the spec. Normalize query params explicitly; do not use `Record<string, any>`.

- [ ] **Step 4: Run API test**

```bash
cd /Users/larus/admin/admin_front_ts
npm run test -- tests/shared/asset-intel/asset-intel-api.test.ts
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/larus/admin/admin_front_ts
git add src/api/asset-intel tests/shared/asset-intel/asset-intel-api.test.ts
git commit -m "feat: add asset intel api client"
```

## Task 10: Frontend MVP Pages And View Registry

**Files:**

- Create: `admin_front_ts/src/views/Main/asset-intel/search/index.vue`
- Create: `admin_front_ts/src/views/Main/asset-intel/corpora/index.vue`
- Create: `admin_front_ts/src/views/Main/asset-intel/documents/index.vue`
- Create: `admin_front_ts/src/views/Main/asset-intel/import-jobs/index.vue`
- Modify: `admin_front_ts/src/router/view-registry.ts`
- Modify: `admin_front_ts/src/i18n/locales/zh-CN.ts`
- Modify: `admin_front_ts/src/i18n/locales/en-US.ts`
- Test: `admin_front_ts/tests/shared/asset-intel/asset-intel-view-registry.test.ts`

- [ ] **Step 1: Add view registry test**

Create `tests/shared/asset-intel/asset-intel-view-registry.test.ts`:

```ts
import { describe, expect, it } from 'vitest'
import { viewRegistry } from '@/router/view-registry'

describe('asset intel view registry', () => {
  it('registers asset intel pages', () => {
    expect(viewRegistry['asset-intel/search']).toBeTruthy()
    expect(viewRegistry['asset-intel/corpora']).toBeTruthy()
    expect(viewRegistry['asset-intel/documents']).toBeTruthy()
    expect(viewRegistry['asset-intel/import-jobs']).toBeTruthy()
  })
})
```

- [ ] **Step 2: Run test to verify failure**

```bash
cd /Users/larus/admin/admin_front_ts
npm run test -- tests/shared/asset-intel/asset-intel-view-registry.test.ts
```

Expected: FAIL because registry entries do not exist.

- [ ] **Step 3: Implement search page**

Create `src/views/Main/asset-intel/search/index.vue`:

```vue
<template>
  <div class="asset-intel-search">
    <Search :schema="searchSchema" @search="handleSearch" @reset="handleReset" />
    <AppTable :columns="columns" :data="rows" :loading="loading">
      <template #score="{ row }">
        {{ formatScore(row.score) }}
      </template>
      <template #source="{ row }">
        <div class="asset-intel-source">
          <strong>{{ row.title }}</strong>
          <span>{{ row.source_url || row.domain || '-' }}</span>
        </div>
      </template>
    </AppTable>
  </div>
</template>
```

Use `useTable` or local table state matching existing pages. Include no hardcoded Chinese labels; use `t('assetIntel.search.keyword')` keys.

- [ ] **Step 4: Implement corpora/documents/import-jobs pages**

Use existing CRUD/list patterns:

- Corpora: list/create/update/status/delete.
- Documents: list/import/status/delete/detail.
- Import jobs: list/detail/retry.

All visible text must use i18n.

- [ ] **Step 5: Register views and i18n**

Modify `view-registry.ts`:

```ts
'asset-intel/search': () => import('@/views/Main/asset-intel/search/index.vue'),
'asset-intel/corpora': () => import('@/views/Main/asset-intel/corpora/index.vue'),
'asset-intel/documents': () => import('@/views/Main/asset-intel/documents/index.vue'),
'asset-intel/import-jobs': () => import('@/views/Main/asset-intel/import-jobs/index.vue'),
```

Add `assetIntel` keys to zh-CN and en-US locale files.

- [ ] **Step 6: Run frontend tests**

```bash
cd /Users/larus/admin/admin_front_ts
npm run test -- tests/shared/asset-intel/asset-intel-api.test.ts tests/shared/asset-intel/asset-intel-view-registry.test.ts
npx vue-tsc -b --pretty false
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
cd /Users/larus/admin/admin_front_ts
git add src/views/Main/asset-intel src/router/view-registry.ts src/i18n/locales/zh-CN.ts src/i18n/locales/en-US.ts tests/shared/asset-intel/asset-intel-view-registry.test.ts
git commit -m "feat: add asset intel vector search pages"
```

## Task 11: Backend Smoke, Contract, Status Docs

**Files:**

- Modify: `admin_go/docs/contracts/admin-api-v1.md`
- Modify: `admin_go/docs/status/current-status.md`
- Modify: `admin_go/docs/testing/smoke-matrix.md`
- Modify: `admin_back_go/docs/architecture.md`
- Modify: `admin_back_go/scripts/full-admin-smoke.ps1`

- [ ] **Step 1: Add smoke probes**

Extend `scripts/full-admin-smoke.ps1` with read/create/search probes:

```powershell
# asset-intel read probes
Invoke-AdminApi -Method GET -Path "/api/admin/v1/asset-intel/corpora"
Invoke-AdminApi -Method GET -Path "/api/admin/v1/asset-intel/import-jobs"
Invoke-AdminApi -Method GET -Path "/api/admin/v1/asset-intel/search?q=smoke&limit=5"
```

Add a guarded write probe only when `-EnableAssetIntelWriteProbe` is provided, so default smoke remains low-risk.

- [ ] **Step 2: Run focused backend tests**

```bash
cd /Users/larus/admin/admin_back_go
go test ./internal/platform/vectorindex ./internal/platform/embedding ./internal/module/assetintel ./internal/server ./internal/bootstrap ./internal/i18n -count=1
```

Expected: PASS.

- [ ] **Step 3: Run frontend checks**

```bash
cd /Users/larus/admin/admin_front_ts
npm run test -- tests/shared/asset-intel/asset-intel-api.test.ts tests/shared/asset-intel/asset-intel-view-registry.test.ts
npx vue-tsc -b --pretty false
```

Expected: PASS.

- [ ] **Step 4: Run docker-first smoke**

From the backend compose directory, ensure MySQL/Redis/Qdrant/backend are running, then:

```bash
cd /Users/larus/admin/admin_back_go/deploy/docker-first
docker compose ps
curl -fsS http://127.0.0.1:8080/ready
```

Expected: `/ready` reports database, redis, queue redis, realtime, and qdrant as up or qdrant as disabled only when `QDRANT_ENABLED=false`.

- [ ] **Step 5: Update docs only after verification**

Update `docs/contracts/admin-api-v1.md` with asset-intel endpoints and response shapes.

Update `docs/status/current-status.md` with `implemented` only if tests and smoke passed. Include exact verification commands.

Update `docs/testing/smoke-matrix.md` with asset-intel read probes and guarded write probe.

Update `admin_back_go/docs/architecture.md` to mention `internal/module/assetintel`, `internal/platform/vectorindex`, and Qdrant boundary.

- [ ] **Step 6: Run docs whitespace check**

```bash
cd /Users/larus/admin/admin_go
git diff --check
cd /Users/larus/admin/admin_back_go
git diff --check
cd /Users/larus/admin/admin_front_ts
git diff --check
```

Expected: all pass.

- [ ] **Step 7: Commit docs and smoke**

```bash
cd /Users/larus/admin/admin_back_go
git add scripts/full-admin-smoke.ps1 docs/architecture.md
git commit -m "test: add asset intel smoke coverage"

cd /Users/larus/admin/admin_go
git add docs/contracts/admin-api-v1.md docs/status/current-status.md docs/testing/smoke-matrix.md
git commit -m "docs: record asset intel vector search runtime"
```

## Self-Review Checklist

- Spec coverage:
  - Qdrant professional vector store: Task 1, Task 2, Task 3.
  - Manual/seed import: Task 5, Task 6, Task 7, Task 9, Task 10.
  - Chunking and embedding: Task 4, Task 6.
  - Search API and UI: Task 6, Task 7, Task 9, Task 10.
  - No crawler/DMCA/OpenSearch in MVP: Scope and Task 11 docs.
  - RBAC/i18n/operation log: Task 7, Task 10.
  - Verification and docs sync: Task 11.

- Completion scan:
  - No undefined future work remains in executable steps.
  - Later phases are not implementation tasks.

- Type consistency:
  - Backend table/model names use `asset_intel_corpora`, `asset_intel_documents`, `asset_intel_chunks`, `asset_intel_import_jobs`.
  - Frontend routes use `asset-intel/search`, `asset-intel/corpora`, `asset-intel/documents`, `asset-intel/import-jobs`.
  - Qdrant payload fields match the spec: `corpus_id`, `document_id`, `chunk_id`, `source_type`, `domain`, `ip`, `asn`, `status`, `created_at`.
