# Address Dict Redis Cache Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cache the large `address` dictionary tree in Redis forever while keeping MySQL as the truth source and preserving the existing profile/user API response shape.

**Architecture:** Add a narrow `user` module cache boundary for the derived address dictionary snapshot. `Service` reads address data through cache-aside: Redis hit returns the snapshot, Redis miss/corrupt/error falls back to MySQL, MySQL rebuild writes Redis with no expiration. Existing handlers, routes, and frontend contracts stay unchanged.

**Tech Stack:** Go, Gin module service pattern, GORM-backed MySQL repository, `github.com/redis/go-redis/v9`, existing `internal/platform/redisclient`, table-driven Go tests, PowerShell smoke scripts.

---

## Source Spec

Read first:

```text
E:/admin_go/docs/superpowers/specs/2026-05-11-address-dict-redis-cache-design.md
```

Important constraints from the spec:

```text
MySQL address table remains truth source.
Redis key is permanent: Set expiration = 0.
Existing API shape keeps auth_address_tree.
No frontend changes in this slice.
No address CRUD or universal dict center in this slice.
```

## File Structure

### Create

```text
admin_back_go/internal/module/user/address_dict_cache.go
```

Responsibility:

```text
Own the address dict cache contract, Redis implementation, cache key, JSON payload, version check, and corrupt-cache sentinel error.
```

### Modify

```text
admin_back_go/internal/module/user/service.go
```

Responsibility:

```text
Inject AddressDictCache, load address dict through cache-aside, replace direct ActiveAddresses calls in PageInit/Profile/List, build path_by_id for address_show.
```

```text
admin_back_go/internal/module/user/service_test.go
```

Responsibility:

```text
Add fake AddressDictCache and regression tests for hit/miss/error/corrupt flows.
```

```text
admin_back_go/internal/bootstrap/app.go
```

Responsibility:

```text
Wire Redis address dict cache into user.NewService.
```

```text
docs/contracts/admin-api-v1.md
docs/migration/current-status.md
admin_back_go/docs/architecture.md
```

Responsibility:

```text
Document address dict cache source, Redis key, no-TTL policy, fallback behavior, and invalidation runbook.
```

---

## Task 1: Add Address Dict Cache Contract and Redis Implementation

**Files:**

- Create: `E:/admin_go/admin_back_go/internal/module/user/address_dict_cache.go`
- Test: `E:/admin_go/admin_back_go/internal/module/user/address_dict_cache_test.go`

- [ ] **Step 1: Write failing cache tests**

Create `E:/admin_go/admin_back_go/internal/module/user/address_dict_cache_test.go`:

```go
package user

import (
	"context"
	"errors"
	"testing"
)

func TestNewRedisAddressDictCacheReturnsNilWithoutRedis(t *testing.T) {
	if got := NewRedisAddressDictCache(nil); got != nil {
		t.Fatalf("expected nil cache for nil redis client, got %#v", got)
	}
}

func TestDecodeAddressDictSnapshotRejectsCorruptJSON(t *testing.T) {
	_, ok, err := decodeAddressDictSnapshot([]byte(`{"version":`))
	if ok {
		t.Fatalf("expected corrupt payload not to be a cache hit")
	}
	if !errors.Is(err, ErrAddressDictCacheCorrupt) {
		t.Fatalf("expected ErrAddressDictCacheCorrupt, got %v", err)
	}
}

func TestDecodeAddressDictSnapshotTreatsVersionMismatchAsMiss(t *testing.T) {
	_, ok, err := decodeAddressDictSnapshot([]byte(`{"version":99,"tree":[],"path_by_id":{}}`))
	if err != nil {
		t.Fatalf("expected no error for version mismatch, got %v", err)
	}
	if ok {
		t.Fatalf("expected version mismatch to be a cache miss")
	}
}

func TestEncodeDecodeAddressDictSnapshotRoundTrip(t *testing.T) {
	input := AddressDictSnapshot{
		Version:          addressDictSnapshotVersion,
		GeneratedAt:      "2026-05-11 10:00:00",
		RowCount:         2,
		SourceMaxUpdated: "2026-03-09 10:56:01",
		Tree: []AddressTreeNode{{
			ID:       1,
			ParentID: 0,
			Label:    "中国",
			Value:    1,
			Children: []AddressTreeNode{{
				ID:       2,
				ParentID: 1,
				Label:    "江苏",
				Value:    2,
			}},
		}},
		PathByID: map[int64][]string{
			1: []string{"中国"},
			2: []string{"中国", "江苏"},
		},
	}

	payload, err := encodeAddressDictSnapshot(input)
	if err != nil {
		t.Fatalf("encodeAddressDictSnapshot returned error: %v", err)
	}

	got, ok, err := decodeAddressDictSnapshot(payload)
	if err != nil {
		t.Fatalf("decodeAddressDictSnapshot returned error: %v", err)
	}
	if !ok {
		t.Fatalf("expected cache hit after round trip")
	}
	if got.Version != addressDictSnapshotVersion || got.RowCount != 2 {
		t.Fatalf("snapshot metadata mismatch: %#v", got)
	}
	if len(got.Tree) != 1 || got.Tree[0].Children[0].Label != "江苏" {
		t.Fatalf("tree mismatch: %#v", got.Tree)
	}
	if path := got.PathByID[2]; len(path) != 2 || path[0] != "中国" || path[1] != "江苏" {
		t.Fatalf("path mismatch: %#v", got.PathByID)
	}
}

func TestNilRedisAddressDictCacheMethodsAreNoops(t *testing.T) {
	var cache *RedisAddressDictCache
	ctx := context.Background()

	if _, ok, err := cache.Get(ctx); ok || err != nil {
		t.Fatalf("nil cache Get mismatch: ok=%v err=%v", ok, err)
	}
	if err := cache.Set(ctx, AddressDictSnapshot{}); err != nil {
		t.Fatalf("nil cache Set returned error: %v", err)
	}
	if err := cache.Delete(ctx); err != nil {
		t.Fatalf("nil cache Delete returned error: %v", err)
	}
}
```

- [ ] **Step 2: Run cache tests and verify they fail**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/user -run "Test(NewRedisAddressDictCache|DecodeAddressDictSnapshot|EncodeDecodeAddressDictSnapshot|NilRedisAddressDictCache)" -count=1
```

Expected:

```text
FAIL
undefined: NewRedisAddressDictCache
undefined: decodeAddressDictSnapshot
undefined: AddressDictSnapshot
```

- [ ] **Step 3: Implement cache file**

Create `E:/admin_go/admin_back_go/internal/module/user/address_dict_cache.go`:

```go
package user

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"admin_back_go/internal/platform/redisclient"

	"github.com/redis/go-redis/v9"
)

const (
	addressDictCacheKey         = "admin_go:dict:address:v1"
	addressDictSnapshotVersion  = 1
)

var ErrAddressDictCacheCorrupt = errors.New("address dict cache corrupt")

type AddressDictCache interface {
	Get(ctx context.Context) (AddressDictSnapshot, bool, error)
	Set(ctx context.Context, snapshot AddressDictSnapshot) error
	Delete(ctx context.Context) error
}

type AddressDictSnapshot struct {
	Version          int                `json:"version"`
	GeneratedAt      string             `json:"generated_at"`
	RowCount         int                `json:"row_count"`
	SourceMaxUpdated string             `json:"source_max_updated"`
	Tree             []AddressTreeNode  `json:"tree"`
	PathByID         map[int64][]string `json:"path_by_id"`
}

type RedisAddressDictCache struct {
	client *redisclient.Client
	key    string
}

func NewRedisAddressDictCache(client *redisclient.Client) *RedisAddressDictCache {
	if client == nil || client.Redis == nil {
		return nil
	}
	return &RedisAddressDictCache{client: client, key: addressDictCacheKey}
}

func (c *RedisAddressDictCache) Get(ctx context.Context) (AddressDictSnapshot, bool, error) {
	if c == nil || c.client == nil || c.client.Redis == nil {
		return AddressDictSnapshot{}, false, nil
	}
	payload, err := c.client.Redis.Get(ctx, c.key).Bytes()
	if errors.Is(err, redis.Nil) {
		return AddressDictSnapshot{}, false, nil
	}
	if err != nil {
		return AddressDictSnapshot{}, false, err
	}
	return decodeAddressDictSnapshot(payload)
}

func (c *RedisAddressDictCache) Set(ctx context.Context, snapshot AddressDictSnapshot) error {
	if c == nil || c.client == nil || c.client.Redis == nil {
		return nil
	}
	payload, err := encodeAddressDictSnapshot(snapshot)
	if err != nil {
		return err
	}
	return c.client.Redis.Set(ctx, c.key, payload, 0).Err()
}

func (c *RedisAddressDictCache) Delete(ctx context.Context) error {
	if c == nil || c.client == nil || c.client.Redis == nil {
		return nil
	}
	return c.client.Redis.Del(ctx, c.key).Err()
}

func encodeAddressDictSnapshot(snapshot AddressDictSnapshot) ([]byte, error) {
	snapshot.Version = addressDictSnapshotVersion
	if snapshot.Tree == nil {
		snapshot.Tree = []AddressTreeNode{}
	}
	if snapshot.PathByID == nil {
		snapshot.PathByID = map[int64][]string{}
	}
	return json.Marshal(snapshot)
}

func decodeAddressDictSnapshot(payload []byte) (AddressDictSnapshot, bool, error) {
	var snapshot AddressDictSnapshot
	if err := json.Unmarshal(payload, &snapshot); err != nil {
		return AddressDictSnapshot{}, false, fmt.Errorf("%w: %v", ErrAddressDictCacheCorrupt, err)
	}
	if snapshot.Version != addressDictSnapshotVersion {
		return AddressDictSnapshot{}, false, nil
	}
	if snapshot.Tree == nil {
		snapshot.Tree = []AddressTreeNode{}
	}
	if snapshot.PathByID == nil {
		snapshot.PathByID = map[int64][]string{}
	}
	return snapshot, true, nil
}
```

- [ ] **Step 4: Run cache tests and verify they pass**

Run:

```powershell
cd E:/admin_go/admin_back_go
gofmt -w internal/module/user/address_dict_cache.go internal/module/user/address_dict_cache_test.go
go test ./internal/module/user -run "Test(NewRedisAddressDictCache|DecodeAddressDictSnapshot|EncodeDecodeAddressDictSnapshot|NilRedisAddressDictCache)" -count=1
```

Expected:

```text
ok  	admin_back_go/internal/module/user
```

- [ ] **Step 5: Commit cache contract**

Run:

```powershell
cd E:/admin_go/admin_back_go
git add internal/module/user/address_dict_cache.go internal/module/user/address_dict_cache_test.go
git commit -m "feat(user): add address dict redis cache contract"
```

Expected:

```text
[branch <sha>] feat(user): add address dict redis cache contract
```

---

## Task 2: Add Service Cache-Aside Loader

**Files:**

- Modify: `E:/admin_go/admin_back_go/internal/module/user/service.go`
- Modify: `E:/admin_go/admin_back_go/internal/module/user/service_test.go`

- [ ] **Step 1: Add fake cache to tests**

Modify `E:/admin_go/admin_back_go/internal/module/user/service_test.go`.

Add `addressCalls int` to `fakeUserRepository`:

```go
type fakeUserRepository struct {
	user                 *User
	profile              *Profile
	role                 *Role
	roleOptions          []Role
	addresses            []Address
	addressCalls         int
	listRows             []ListRow
	listTotal            int64
	exportRows           []ExportUserRow
	exportIDs            []int64
	entries              []QuickEntry
	rolesByID            map[int64]*Role
	emailUsed            bool
	phoneUsed            bool
	existsEmailUserID    int64
	existsEmail          string
	existsPhoneUserID    int64
	existsPhone          string
	listQuery            ListQuery
	txCalled             bool
	updatedUserID        int64
	updatedUserFields    map[string]any
	updatedProfileUserID int64
	updatedProfileFields map[string]any
	ensuredProfile       *Profile
	statusUserID         int64
	statusValue          int
	deletedIDs           []int64
	batchUpdate          BatchProfileUpdate
	err                  error
}
```

Change `ActiveAddresses`:

```go
func (f *fakeUserRepository) ActiveAddresses(ctx context.Context) ([]Address, error) {
	f.addressCalls++
	return f.addresses, f.err
}
```

Add fake cache after `fakeUserRepository` methods:

```go
type fakeAddressDictCache struct {
	snapshot    AddressDictSnapshot
	hit         bool
	getErr      error
	setErr      error
	deleteErr   error
	getCalls    int
	setCalls    int
	deleteCalls int
	saved       AddressDictSnapshot
}

func (f *fakeAddressDictCache) Get(ctx context.Context) (AddressDictSnapshot, bool, error) {
	f.getCalls++
	return f.snapshot, f.hit, f.getErr
}

func (f *fakeAddressDictCache) Set(ctx context.Context, snapshot AddressDictSnapshot) error {
	f.setCalls++
	f.saved = snapshot
	return f.setErr
}

func (f *fakeAddressDictCache) Delete(ctx context.Context) error {
	f.deleteCalls++
	return f.deleteErr
}
```

- [ ] **Step 2: Write failing loader tests**

Append these tests to `E:/admin_go/admin_back_go/internal/module/user/service_test.go`:

```go
func TestServiceLoadAddressDictUsesCacheHit(t *testing.T) {
	repo := &fakeUserRepository{
		addresses: []Address{{ID: 99, ParentID: 0, Name: "不应该查询"}},
	}
	cache := &fakeAddressDictCache{
		hit: true,
		snapshot: AddressDictSnapshot{
			Version:  addressDictSnapshotVersion,
			RowCount: 1,
			Tree: []AddressTreeNode{{
				ID:    1,
				Label: "中国",
				Value: 1,
			}},
			PathByID: map[int64][]string{1: []string{"中国"}},
		},
	}
	svc := NewService(repo, &fakePermissionBuilder{}, nil, time.Minute, WithAddressDictCache(cache))

	got, err := svc.loadAddressDict(context.Background())

	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if len(got.Tree) != 1 || got.Tree[0].Label != "中国" {
		t.Fatalf("unexpected cached tree: %#v", got.Tree)
	}
	if repo.addressCalls != 0 {
		t.Fatalf("expected cache hit to avoid DB, got %d address calls", repo.addressCalls)
	}
	if cache.getCalls != 1 || cache.setCalls != 0 {
		t.Fatalf("cache calls mismatch: get=%d set=%d", cache.getCalls, cache.setCalls)
	}
}

func TestServiceLoadAddressDictMissRebuildsAndSavesCache(t *testing.T) {
	repo := &fakeUserRepository{
		addresses: []Address{
			{ID: 1, ParentID: 0, Name: "中国", UpdatedAt: time.Date(2026, 3, 9, 10, 56, 1, 0, time.Local)},
			{ID: 2, ParentID: 1, Name: "江苏", UpdatedAt: time.Date(2026, 3, 9, 10, 56, 1, 0, time.Local)},
		},
	}
	cache := &fakeAddressDictCache{}
	svc := NewService(repo, &fakePermissionBuilder{}, nil, time.Minute, WithAddressDictCache(cache))

	got, err := svc.loadAddressDict(context.Background())

	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if repo.addressCalls != 1 {
		t.Fatalf("expected one DB address query, got %d", repo.addressCalls)
	}
	if cache.setCalls != 1 {
		t.Fatalf("expected cache Set once, got %d", cache.setCalls)
	}
	if got.RowCount != 2 || got.SourceMaxUpdated != "2026-03-09 10:56:01" {
		t.Fatalf("snapshot metadata mismatch: %#v", got)
	}
	if path := got.PathByID[2]; len(path) != 2 || path[0] != "中国" || path[1] != "江苏" {
		t.Fatalf("path_by_id mismatch: %#v", got.PathByID)
	}
	if len(cache.saved.Tree) != 1 || cache.saved.Tree[0].Children[0].Label != "江苏" {
		t.Fatalf("saved tree mismatch: %#v", cache.saved.Tree)
	}
}

func TestServiceLoadAddressDictRedisErrorFallsBackToDatabase(t *testing.T) {
	repo := &fakeUserRepository{
		addresses: []Address{{ID: 1, ParentID: 0, Name: "中国"}},
	}
	cache := &fakeAddressDictCache{getErr: errors.New("redis down")}
	svc := NewService(repo, &fakePermissionBuilder{}, nil, time.Minute, WithAddressDictCache(cache))

	got, err := svc.loadAddressDict(context.Background())

	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if repo.addressCalls != 1 {
		t.Fatalf("expected fallback DB query, got %d", repo.addressCalls)
	}
	if cache.deleteCalls != 0 {
		t.Fatalf("expected redis connection error not to delete cache, got %d deletes", cache.deleteCalls)
	}
	if len(got.Tree) != 1 || got.Tree[0].Label != "中国" {
		t.Fatalf("fallback tree mismatch: %#v", got.Tree)
	}
}

func TestServiceLoadAddressDictCorruptCacheDeletesAndFallsBack(t *testing.T) {
	repo := &fakeUserRepository{
		addresses: []Address{{ID: 1, ParentID: 0, Name: "中国"}},
	}
	cache := &fakeAddressDictCache{getErr: ErrAddressDictCacheCorrupt}
	svc := NewService(repo, &fakePermissionBuilder{}, nil, time.Minute, WithAddressDictCache(cache))

	got, err := svc.loadAddressDict(context.Background())

	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if repo.addressCalls != 1 {
		t.Fatalf("expected fallback DB query, got %d", repo.addressCalls)
	}
	if cache.deleteCalls != 1 {
		t.Fatalf("expected corrupt cache delete once, got %d", cache.deleteCalls)
	}
	if len(got.Tree) != 1 || got.Tree[0].Value != 1 {
		t.Fatalf("fallback tree mismatch: %#v", got.Tree)
	}
}

func TestServiceLoadAddressDictSetErrorStillReturnsDatabaseResult(t *testing.T) {
	repo := &fakeUserRepository{
		addresses: []Address{{ID: 1, ParentID: 0, Name: "中国"}},
	}
	cache := &fakeAddressDictCache{setErr: errors.New("set failed")}
	svc := NewService(repo, &fakePermissionBuilder{}, nil, time.Minute, WithAddressDictCache(cache))

	got, err := svc.loadAddressDict(context.Background())

	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if repo.addressCalls != 1 || cache.setCalls != 1 {
		t.Fatalf("calls mismatch: address=%d set=%d", repo.addressCalls, cache.setCalls)
	}
	if len(got.Tree) != 1 || got.Tree[0].Label != "中国" {
		t.Fatalf("tree mismatch: %#v", got.Tree)
	}
}
```

- [ ] **Step 3: Run loader tests and verify they fail**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/user -run "TestServiceLoadAddressDict" -count=1
```

Expected:

```text
FAIL
undefined: WithAddressDictCache
svc.loadAddressDict undefined
```

- [ ] **Step 4: Add service cache injection and loader**

Modify `E:/admin_go/admin_back_go/internal/module/user/service.go`.

Add `errors` to imports:

```go
import (
	"context"
	"errors"
	"math"
	"regexp"
	"sort"
	"strings"
	"time"
```

Add `addressCache` to `Service`:

```go
type Service struct {
	repository        Repository
	permissionBuilder PermissionBuilder
	buttonCache       ButtonCache
	buttonCacheTTL    time.Duration
	platforms         []string
	verifyCodeStore   VerifyCodeStore
	verifyCodePrefix  string
	exportTaskCreator ExportTaskCreator
	exportEnqueuer    taskqueue.Enqueuer
	addressCache      AddressDictCache
}
```

Add option after `WithExportEnqueuer`:

```go
func WithAddressDictCache(cache AddressDictCache) Option {
	return func(s *Service) {
		s.addressCache = cache
	}
}
```

Add loader and snapshot builders near address helper functions:

```go
func (s *Service) loadAddressDict(ctx context.Context) (*AddressDictSnapshot, error) {
	if s == nil || s.repository == nil {
		return nil, ErrRepositoryNotConfigured
	}
	if s.addressCache != nil {
		snapshot, ok, err := s.addressCache.Get(ctx)
		if err == nil && ok {
			return &snapshot, nil
		}
		if errors.Is(err, ErrAddressDictCacheCorrupt) {
			_ = s.addressCache.Delete(ctx)
		}
	}

	rows, err := s.repository.ActiveAddresses(ctx)
	if err != nil {
		return nil, err
	}
	snapshot := buildAddressDictSnapshot(rows, time.Now())
	if s.addressCache != nil {
		_ = s.addressCache.Set(ctx, snapshot)
	}
	return &snapshot, nil
}

func buildAddressDictSnapshot(rows []Address, generatedAt time.Time) AddressDictSnapshot {
	snapshot := AddressDictSnapshot{
		Version:     addressDictSnapshotVersion,
		GeneratedAt: formatTime(generatedAt),
		RowCount:    len(rows),
		Tree:        buildAddressTree(rows),
		PathByID:    buildAddressPathByID(rows),
	}
	var maxUpdated time.Time
	for _, row := range rows {
		if row.UpdatedAt.After(maxUpdated) {
			maxUpdated = row.UpdatedAt
		}
	}
	if !maxUpdated.IsZero() {
		snapshot.SourceMaxUpdated = formatTime(maxUpdated)
	}
	return snapshot
}

func buildAddressPathByID(rows []Address) map[int64][]string {
	addressMap := makeAddressMap(rows)
	result := make(map[int64][]string, len(addressMap))
	for id := range addressMap {
		path := buildAddressPath(id, addressMap)
		if len(path) == 0 {
			continue
		}
		result[id] = path
	}
	return result
}
```

- [ ] **Step 5: Run loader tests and verify they pass**

Run:

```powershell
cd E:/admin_go/admin_back_go
gofmt -w internal/module/user/service.go internal/module/user/service_test.go
go test ./internal/module/user -run "TestServiceLoadAddressDict" -count=1
```

Expected:

```text
ok  	admin_back_go/internal/module/user
```

- [ ] **Step 6: Commit loader**

Run:

```powershell
cd E:/admin_go/admin_back_go
git add internal/module/user/service.go internal/module/user/service_test.go
git commit -m "feat(user): load address dict through cache-aside"
```

Expected:

```text
[branch <sha>] feat(user): load address dict through cache-aside
```

---

## Task 3: Replace Direct Address Loads in PageInit, Profile, and List

**Files:**

- Modify: `E:/admin_go/admin_back_go/internal/module/user/service.go`
- Modify: `E:/admin_go/admin_back_go/internal/module/user/service_test.go`

- [ ] **Step 1: Write failing consumer tests**

Append these tests to `E:/admin_go/admin_back_go/internal/module/user/service_test.go`:

```go
func TestServicePageInitUsesCachedAddressTree(t *testing.T) {
	repo := &fakeUserRepository{
		roleOptions: []Role{{ID: 1, Name: "管理员"}},
		addresses:   []Address{{ID: 99, ParentID: 0, Name: "不应该查询"}},
	}
	cache := &fakeAddressDictCache{
		hit: true,
		snapshot: AddressDictSnapshot{
			Version:  addressDictSnapshotVersion,
			Tree:     []AddressTreeNode{{ID: 1, Label: "中国", Value: 1}},
			PathByID: map[int64][]string{1: []string{"中国"}},
		},
	}
	svc := NewService(repo, &fakePermissionBuilder{}, nil, time.Minute, WithAddressDictCache(cache))

	got, appErr := svc.PageInit(context.Background())

	if appErr != nil {
		t.Fatalf("expected no app error, got %v", appErr)
	}
	if repo.addressCalls != 0 {
		t.Fatalf("expected PageInit to avoid DB on cache hit, got %d calls", repo.addressCalls)
	}
	if len(got.Dict.AuthAddressTree) != 1 || got.Dict.AuthAddressTree[0].Label != "中国" {
		t.Fatalf("address tree mismatch: %#v", got.Dict.AuthAddressTree)
	}
}

func TestServiceProfileUsesCachedAddressTree(t *testing.T) {
	password := "$2y$10$hash"
	repo := &fakeUserRepository{
		user:    &User{ID: 8, Username: "alice", RoleID: 2, Password: &password},
		profile: &Profile{UserID: 8, Sex: enum.SexFemale, AddressID: 2},
		role:    &Role{ID: 2, Name: "运营"},
	}
	cache := &fakeAddressDictCache{
		hit: true,
		snapshot: AddressDictSnapshot{
			Version:  addressDictSnapshotVersion,
			Tree:     []AddressTreeNode{{ID: 1, Label: "中国", Value: 1}},
			PathByID: map[int64][]string{1: []string{"中国"}},
		},
	}
	svc := NewService(repo, &fakePermissionBuilder{}, nil, time.Minute, WithAddressDictCache(cache))

	got, appErr := svc.Profile(context.Background(), 8, 8)

	if appErr != nil {
		t.Fatalf("expected no app error, got %v", appErr)
	}
	if repo.addressCalls != 0 {
		t.Fatalf("expected Profile to avoid DB on cache hit, got %d calls", repo.addressCalls)
	}
	if len(got.Dict.AuthAddressTree) != 1 || got.Dict.AuthAddressTree[0].Label != "中国" {
		t.Fatalf("profile address tree mismatch: %#v", got.Dict.AuthAddressTree)
	}
}

func TestServiceListUsesCachedPathByIDForAddressShow(t *testing.T) {
	detail := "玄武区"
	addressID := int64(2)
	repo := &fakeUserRepository{
		listRows: []ListRow{{
			ID:            8,
			Username:      "alice",
			AddressID:     &addressID,
			DetailAddress: &detail,
			Status:        enum.CommonYes,
		}},
		listTotal: 1,
		addresses: []Address{{ID: 99, ParentID: 0, Name: "不应该查询"}},
	}
	cache := &fakeAddressDictCache{
		hit: true,
		snapshot: AddressDictSnapshot{
			Version:  addressDictSnapshotVersion,
			Tree:     []AddressTreeNode{{ID: 1, Label: "中国", Value: 1}},
			PathByID: map[int64][]string{2: []string{"中国", "江苏", "南京"}},
		},
	}
	svc := NewService(repo, &fakePermissionBuilder{}, nil, time.Minute, WithAddressDictCache(cache))

	got, appErr := svc.List(context.Background(), ListQuery{CurrentPage: 1, PageSize: 10})

	if appErr != nil {
		t.Fatalf("expected no app error, got %v", appErr)
	}
	if repo.addressCalls != 0 {
		t.Fatalf("expected List to avoid DB on cache hit, got %d calls", repo.addressCalls)
	}
	if len(got.List) != 1 || got.List[0].AddressShow != "中国-江苏-南京-玄武区" {
		t.Fatalf("address_show mismatch: %#v", got.List)
	}
}
```

- [ ] **Step 2: Run consumer tests and verify they fail**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/user -run "TestService(PageInitUsesCachedAddressTree|ProfileUsesCachedAddressTree|ListUsesCachedPathByIDForAddressShow)" -count=1
```

Expected:

```text
FAIL
expected PageInit/Profile/List to avoid DB on cache hit
```

- [ ] **Step 3: Replace PageInit address load**

In `E:/admin_go/admin_back_go/internal/module/user/service.go`, replace:

```go
	addresses, err := s.repository.ActiveAddresses(ctx)
	if err != nil {
		return nil, apperror.Wrap(apperror.CodeInternal, 500, "查询地址字典失败", err)
	}
```

with:

```go
	addressDict, err := s.loadAddressDict(ctx)
	if err != nil {
		return nil, apperror.Wrap(apperror.CodeInternal, 500, "查询地址字典失败", err)
	}
```

Then replace:

```go
AuthAddressTree: buildAddressTree(addresses),
```

with:

```go
AuthAddressTree: addressDict.Tree,
```

- [ ] **Step 4: Replace Profile address load**

In `E:/admin_go/admin_back_go/internal/module/user/service.go`, replace:

```go
	addresses, findAddressErr := s.repository.ActiveAddresses(ctx)
	if findAddressErr != nil {
		return nil, apperror.Wrap(apperror.CodeInternal, 500, "查询地址字典失败", findAddressErr)
	}
```

with:

```go
	addressDict, findAddressErr := s.loadAddressDict(ctx)
	if findAddressErr != nil {
		return nil, apperror.Wrap(apperror.CodeInternal, 500, "查询地址字典失败", findAddressErr)
	}
```

Then replace:

```go
AuthAddressTree: buildAddressTree(addresses),
```

with:

```go
AuthAddressTree: addressDict.Tree,
```

- [ ] **Step 5: Replace List address map usage**

In `E:/admin_go/admin_back_go/internal/module/user/service.go`, replace:

```go
	addresses, err := s.repository.ActiveAddresses(ctx)
	if err != nil {
		return nil, apperror.Wrap(apperror.CodeInternal, 500, "查询地址字典失败", err)
	}
	addressMap := makeAddressMap(addresses)

	list := make([]ListItem, 0, len(rows))
	for _, row := range rows {
		list = append(list, formatListItem(row, addressMap))
	}
```

with:

```go
	addressDict, err := s.loadAddressDict(ctx)
	if err != nil {
		return nil, apperror.Wrap(apperror.CodeInternal, 500, "查询地址字典失败", err)
	}

	list := make([]ListItem, 0, len(rows))
	for _, row := range rows {
		list = append(list, formatListItem(row, addressDict.PathByID))
	}
```

Change helper signatures:

```go
func formatListItem(row ListRow, addressPathByID map[int64][]string) ListItem {
```

Replace inside `formatListItem`:

```go
AddressShow: buildAddressShow(addressID, detailAddress, addressMap),
```

with:

```go
AddressShow: buildAddressShow(addressID, detailAddress, addressPathByID),
```

Replace `buildAddressShow` with:

```go
func buildAddressShow(addressID int64, detail string, addressPathByID map[int64][]string) string {
	parts := make([]string, 0, 4)
	if addressID > 0 {
		for _, name := range addressPathByID[addressID] {
			if name != "" {
				parts = append(parts, name)
			}
		}
	}
	if detail != "" {
		parts = append(parts, detail)
	}
	return strings.Join(parts, "-")
}
```

Keep `makeAddressMap` and `buildAddressPath` because `buildAddressPathByID` uses them.

- [ ] **Step 6: Run focused consumer tests**

Run:

```powershell
cd E:/admin_go/admin_back_go
gofmt -w internal/module/user/service.go internal/module/user/service_test.go
go test ./internal/module/user -run "TestService(PageInitReturnsRoleSexPlatformAndAddressTree|ProfileReturnsDetailDictAndSelfFlag|PageInitUsesCachedAddressTree|ProfileUsesCachedAddressTree|ListUsesCachedPathByIDForAddressShow|LoadAddressDict)" -count=1
```

Expected:

```text
ok  	admin_back_go/internal/module/user
```

- [ ] **Step 7: Run full user module tests**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/user -count=1
```

Expected:

```text
ok  	admin_back_go/internal/module/user
```

- [ ] **Step 8: Commit consumer replacement**

Run:

```powershell
cd E:/admin_go/admin_back_go
git add internal/module/user/service.go internal/module/user/service_test.go
git commit -m "perf(user): reuse cached address dict in profile flows"
```

Expected:

```text
[branch <sha>] perf(user): reuse cached address dict in profile flows
```

---

## Task 4: Wire Redis Cache in Bootstrap

**Files:**

- Modify: `E:/admin_go/admin_back_go/internal/bootstrap/app.go`

- [ ] **Step 1: Add wiring**

Modify `E:/admin_go/admin_back_go/internal/bootstrap/app.go`.

Replace:

```go
	userRepository := user.NewGormRepository(resources.DB)
```

with:

```go
	userRepository := user.NewGormRepository(resources.DB)
	addressDictCache := user.NewRedisAddressDictCache(resources.Redis)
```

Add the new option to `user.NewService`:

```go
	userService := user.NewService(
		userRepository,
		permissionService,
		buttonGrantCache,
		0,
		user.WithVerifyCodeStore(auth.NewRedisCodeStore(resources.Redis), cfg.VerifyCode.RedisPrefix),
		user.WithExportTaskCreator(exportTaskService),
		user.WithExportEnqueuer(queueClient),
		user.WithAddressDictCache(addressDictCache),
	)
```

- [ ] **Step 2: Run bootstrap tests**

Run:

```powershell
cd E:/admin_go/admin_back_go
gofmt -w internal/bootstrap/app.go
go test ./internal/bootstrap -count=1
```

Expected:

```text
ok  	admin_back_go/internal/bootstrap
```

- [ ] **Step 3: Run server route tests**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/server -count=1
```

Expected:

```text
ok  	admin_back_go/internal/server
```

- [ ] **Step 4: Commit bootstrap wiring**

Run:

```powershell
cd E:/admin_go/admin_back_go
git add internal/bootstrap/app.go
git commit -m "feat(user): wire redis address dict cache"
```

Expected:

```text
[branch <sha>] feat(user): wire redis address dict cache
```

---

## Task 5: Sync Contracts and Architecture Docs

**Files:**

- Modify: `E:/admin_go/docs/contracts/admin-api-v1.md`
- Modify: `E:/admin_go/docs/migration/current-status.md`
- Modify: `E:/admin_go/admin_back_go/docs/architecture.md`

- [ ] **Step 1: Update API contract profile section**

In `E:/admin_go/docs/contracts/admin-api-v1.md`, under `## Profile` rules, add:

````markdown
地址字典来源：

```text
MySQL address 表是真相源。
Go user service 通过 Redis cache-aside 读取派生地址树。
Redis key: admin_go:dict:address:v1
TTL: none，redis TTL 期望为 -1。
Redis miss / Redis error / corrupt cache 会回源 MySQL 重建，不改变 response shape。
```
````

- [ ] **Step 2: Update users page-init section**

In `E:/admin_go/docs/contracts/admin-api-v1.md`, near the users `auth_address_tree` definition, add:

```markdown
`auth_address_tree` 是地址大字典，当前由 Go 后端从 Redis `admin_go:dict:address:v1` 读取；缓存不存在或不可用时回源 MySQL `address` 表并重建。
```

- [ ] **Step 3: Update current status**

In `E:/admin_go/docs/migration/current-status.md`, update the `profile / account security / avatar upload` row remaining-risk text by adding:

```text
address dict now uses Redis permanent cache-aside with MySQL fallback; cache invalidation is manual until a Go address CRUD/import slice exists
```

- [ ] **Step 4: Update backend architecture Redis section**

In `E:/admin_go/admin_back_go/docs/architecture.md`, under Redis platform baseline, add:

````markdown
### Address dict cache

`address` 表仍是行政区划真相源。`user` module 只缓存派生结构：

```text
key: admin_go:dict:address:v1
ttl: none
payload: AddressDictSnapshot { tree, path_by_id, row_count, source_max_updated }
```

读取策略：

```text
Redis hit -> return cached tree/path_by_id
Redis miss -> query MySQL address -> rebuild snapshot -> SET key without expiration
Redis corrupt payload -> DEL key best-effort -> query MySQL
Redis connection error -> query MySQL
```

失效策略：

```powershell
redis-cli DEL admin_go:dict:address:v1
```

如果未来新增 Go address CRUD/import，写入成功后必须删除该 key。
````

- [ ] **Step 5: Scan docs for placeholder text**

Run:

```powershell
cd E:/admin_go
Select-String -Path 'docs/contracts/admin-api-v1.md','docs/migration/current-status.md','admin_back_go/docs/architecture.md' -Pattern ('TO'+'DO|TB'+'D|待'+'定|占'+'位') -CaseSensitive:$false
```

Expected:

```text
No matches for the newly edited sections.
```

- [ ] **Step 6: Commit docs**

Run:

```powershell
cd E:/admin_go
git add docs/contracts/admin-api-v1.md docs/migration/current-status.md admin_back_go/docs/architecture.md
git commit -m "docs: document address dict redis cache"
```

Expected:

```text
[branch <sha>] docs: document address dict redis cache
```

---

## Task 6: Verification Gates

**Files:**

- Verify code in `E:/admin_go/admin_back_go`
- Verify smoke scripts in `E:/admin_go/admin_back_go/scripts`

- [ ] **Step 1: Run focused Go tests**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/user ./internal/bootstrap ./internal/server -count=1
```

Expected:

```text
ok  	admin_back_go/internal/module/user
ok  	admin_back_go/internal/bootstrap
ok  	admin_back_go/internal/server
```

- [ ] **Step 2: Run race detector for user module**

Run:

```powershell
cd E:/admin_go/admin_back_go
go test -race ./internal/module/user -count=1
```

Expected:

```text
ok  	admin_back_go/internal/module/user
```

- [ ] **Step 3: Run go vet**

Run:

```powershell
cd E:/admin_go/admin_back_go
go vet ./internal/module/user ./internal/bootstrap ./internal/server
```

Expected:

```text
No output and exit code 0.
```

- [ ] **Step 4: Run golangci-lint when installed**

Run:

```powershell
cd E:/admin_go/admin_back_go
golangci-lint run ./internal/module/user ./internal/bootstrap ./internal/server
```

Expected when installed:

```text
No output and exit code 0.
```

Expected when not installed:

```text
CommandNotFoundException or executable not found. Record this as environment missing, not code failure.
```

- [ ] **Step 5: Run basic smoke**

Run:

```powershell
cd E:/admin_go/admin_back_go
./scripts/basic-admin-smoke.ps1
```

Expected:

```text
Smoke exits 0.
users_address_tree_count is greater than 0.
```

- [ ] **Step 6: Verify Redis key manually**

After smoke or one authenticated profile/page-init request, run:

```powershell
redis-cli EXISTS admin_go:dict:address:v1
redis-cli TTL admin_go:dict:address:v1
```

Expected:

```text
EXISTS returns 1.
TTL returns -1.
```

- [ ] **Step 7: Verify rebuild after delete**

Run:

```powershell
redis-cli DEL admin_go:dict:address:v1
cd E:/admin_go/admin_back_go
./scripts/basic-admin-smoke.ps1
redis-cli EXISTS admin_go:dict:address:v1
redis-cli TTL admin_go:dict:address:v1
```

Expected:

```text
DEL returns 1 or 0.
Smoke exits 0.
EXISTS returns 1.
TTL returns -1.
```

- [ ] **Step 8: Final diff review**

Run:

```powershell
cd E:/admin_go/admin_back_go
git diff --stat HEAD
git diff -- internal/module/user internal/bootstrap

cd E:/admin_go
git diff --stat HEAD
git diff -- docs/contracts/admin-api-v1.md docs/migration/current-status.md admin_back_go/docs/architecture.md
```

Expected:

```text
Only address dict cache code, bootstrap wiring, tests, and documentation changed.
No frontend files changed.
```

---

## Self-Review Checklist

Spec coverage:

```text
Redis permanent key: Task 1 Set(ctx, key, payload, 0), Task 6 TTL verification.
MySQL truth source: Task 2 loader rebuilds from repository.ActiveAddresses.
No frontend change: File Structure and Task 6 final diff review.
Existing response shape: Task 3 preserves auth_address_tree in PageInit/Profile.
List address_show path: Task 3 PathByID flow.
Redis error fallback: Task 2 tests and loader behavior.
Corrupt cache delete: Task 2 tests and loader behavior.
Docs sync: Task 5.
```

Placeholder scan target:

```powershell
cd E:/admin_go
Select-String -Path 'docs/superpowers/plans/2026-05-11-address-dict-redis-cache-implementation.md' -Pattern ('TO'+'DO|TB'+'D|待'+'定|占'+'位|Similar'+' to|appropriate'+' error handling') -CaseSensitive:$false
```

Expected:

```text
No matches.
```

Type consistency:

```text
AddressDictCache.Get returns (AddressDictSnapshot, bool, error) in Task 1 and all fakes.
WithAddressDictCache appears in Task 2 tests and implementation.
loadAddressDict returns *AddressDictSnapshot and is used by PageInit/Profile/List.
PathByID is map[int64][]string in cache payload, tests, and List formatting.
```

