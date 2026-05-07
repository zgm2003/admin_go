# User Session Read-only List Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the user session management page's read-only `page-init`, `list`, and `stats` flow from PHP legacy adapters to Go REST without touching kick-offline mutations.

**Architecture:** Add a dedicated Go admin read module under `internal/module/usersession` instead of polluting the existing token/auth `internal/module/session` package. The module reads `user_sessions` joined with `users`, derives status from `revoked_at` and `refresh_expires_at`, and exposes REST endpoints consumed by the existing Vue page. Kick and batch kick stay on legacy endpoints in this slice so Redis token deletion, current-session protection, and OperationLog can be handled as a separate write slice.

**Tech Stack:** Go 1.26.1, Gin, GORM, MySQL, existing `response` / `apperror` / `enum` / `dict` helpers, Vue 3, TypeScript, Vitest.

---

## Execution Status

状态：implemented and verified on 2026-05-08.

本计划只做 read-only；`docs/migration/current-status.md` 不要写成 fully implemented。

验证结果：

```powershell
cd E:\admin_go\admin_back_go
go test ./...
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456

cd E:\admin_go\admin_front_ts
npm test -- tests/shared/user/users-api.test.ts
npm run build:check
```

注意：`kick` / `batchKick` 仍是 legacy PHP，本计划没有迁 Go write path。

---

## Evidence and Current Facts

```text
Frontend still uses PHP legacy:
admin_front_ts/src/api/user/users.ts
  UserSessionApi.list  -> /api/admin/UserSession/list
  UserSessionApi.stats -> /api/admin/UserSession/stats
  UserSessionApi.kick  -> /api/admin/UserSession/kick

Frontend page calls:
admin_front_ts/src/views/Main/user/userManager/components/SessionList/index.vue
  onMounted -> init + loadStats + getList

Legacy business truth:
E:/admin/admin_back/app/module/User/UserSessionModule.php
E:/admin/admin_back/app/dep/User/UserSessionsDep.php
E:/admin/admin_back/app/validate/User/UserSessionValidate.php

Go auth/session core already exists:
admin_back_go/internal/module/session/model.go
admin_back_go/internal/module/session/repository.go
admin_back_go/internal/module/session/service.go
```

Live DB check at planning time:

```text
user_sessions total = 734
active = 5
expired = 10
revoked = 719
active platform distribution:
  admin = 2
  app = 3
```

This is a real feature, not imaginary architecture work.

---

## Scope

Implement now:

```text
GET /api/admin/v1/user-sessions/page-init
GET /api/admin/v1/user-sessions
GET /api/admin/v1/user-sessions/stats
```

Keep legacy for now:

```text
POST /api/admin/UserSession/kick
POST /api/admin/UserSession/batchKick
```

Do not implement now:

```text
PATCH /api/admin/v1/user-sessions/:id/kick
PATCH /api/admin/v1/user-sessions/kick
Redis token-key deletion for admin kick
current-session anti-kick guard
OperationLog for kick
permission route metadata for kick
```

---

## Non-negotiable Rules

```text
1. Do not put admin management HTTP list code into internal/module/session.
2. Do not return access_token_hash or refresh_token_hash.
3. Do not copy PHP POST-style /api/admin/UserSession/list into the Go REST contract.
4. Do not add a new framework, cache layer, queue job, or DB migration for this read-only slice.
5. Do not change the SessionList UI layout.
6. Do not silently convert kick/batchKick to Go in the same commit.
7. Do not write current-status as fully implemented; it is read-only / partially implemented.
```

Linus check:

```text
True problem: yes, frontend page still calls PHP while Go owns auth/session.
Simpler way: read directly from existing user_sessions; no cache, no new table.
What breaks: kick stays legacy, so no token Redis behavior is changed in this slice.
```

---

## API Contract

### `GET /api/admin/v1/user-sessions/page-init`

Auth:

```text
Bearer token only.
No extra route permission in this slice.
No OperationLog.
```

Response:

```ts
interface UserSessionPageInitResponse {
  dict: {
    platformArr: Array<{ label: string; value: string }>
    statusArr: Array<{ label: string; value: 'active' | 'expired' | 'revoked' }>
  }
}
```

### `GET /api/admin/v1/user-sessions`

Auth:

```text
Bearer token only.
No extra route permission in this slice.
No OperationLog.
```

Query:

```ts
interface UserSessionListParams {
  page_size: number
  current_page: number
  username?: string
  platform?: string
  status?: 'active' | 'expired' | 'revoked'
}
```

Response:

```ts
interface UserSessionItem {
  id: number
  user_id: number
  username: string
  platform: string
  platform_name: string
  device_id: string
  ip: string
  ua: string
  last_seen_at: string
  created_at: string
  expires_at: string
  refresh_expires_at: string
  revoked_at: string | null
  status: 'active' | 'expired' | 'revoked'
}

interface UserSessionListResponse {
  list: UserSessionItem[]
  page: {
    page_size: number
    current_page: number
    total_page: number
    total: number
  }
}
```

Rules:

```text
is_del = 2
username filter: users.username LIKE '<username>%'
platform filter: exact match; only admin/app accepted when non-empty
status active: revoked_at IS NULL AND refresh_expires_at > now
status expired: revoked_at IS NULL AND refresh_expires_at <= now
status revoked: revoked_at IS NOT NULL
sort: active -> expired -> revoked, then last_seen_at DESC
page_size default: 20
page_size max: enum.PageSizeMax
current_page default: 1
```

### `GET /api/admin/v1/user-sessions/stats`

Auth:

```text
Bearer token only.
No extra route permission in this slice.
No OperationLog.
```

Response:

```ts
interface UserSessionStats {
  total_active: number
  platform_distribution: Record<string, number> & {
    admin: number
    app: number
  }
}
```

Rules:

```text
active stats use refresh_expires_at, not access expires_at.
Always include admin and app keys even when count is zero.
No cache in this Go slice; correctness beats stale 5-minute legacy cache.
```

---

## Files

Create:

```text
admin_back_go/internal/module/usersession/dto.go
admin_back_go/internal/module/usersession/request.go
admin_back_go/internal/module/usersession/repository.go
admin_back_go/internal/module/usersession/service.go
admin_back_go/internal/module/usersession/handler.go
admin_back_go/internal/module/usersession/route.go
admin_back_go/internal/module/usersession/service_test.go
admin_back_go/internal/module/usersession/handler_test.go
```

Modify:

```text
admin_back_go/internal/server/router.go
admin_back_go/internal/server/router_test.go
admin_back_go/internal/bootstrap/app.go
admin_front_ts/src/types/user.ts
admin_front_ts/src/api/user/users.ts
admin_front_ts/src/views/Main/user/userManager/components/SessionList/index.vue
admin_front_ts/tests/shared/user/users-api.test.ts
docs/contracts/admin-api-v1.md
docs/migration/current-status.md
docs/testing/smoke-matrix.md
admin_back_go/scripts/full-admin-smoke.ps1
```

Do not modify:

```text
admin_back_go/internal/module/session/*
admin_back_go/database/migrations/*
admin_front_ts UI styles for SessionList
```

---

## Task 1: Backend service contract tests

**Files:**

```text
Create: admin_back_go/internal/module/usersession/service_test.go
Create later in Task 2: admin_back_go/internal/module/usersession/dto.go
Create later in Task 2: admin_back_go/internal/module/usersession/service.go
```

- [ ] Create `admin_back_go/internal/module/usersession/service_test.go` with tests for status derivation, query normalization, list response, and stats response.

Use this concrete test shape:

```go
package usersession

import (
	"context"
	"testing"
	"time"
)

type fakeRepository struct {
	listQuery  ListQuery
	listRows   []ListRow
	listTotal  int64
	statsRows  []StatsRow
	listErr    error
	statsErr   error
}

func (f *fakeRepository) List(ctx context.Context, query ListQuery) ([]ListRow, int64, error) {
	f.listQuery = query
	return f.listRows, f.listTotal, f.listErr
}

func (f *fakeRepository) Stats(ctx context.Context, now time.Time) ([]StatsRow, error) {
	return f.statsRows, f.statsErr
}

func TestListNormalizesQueryAndDerivesStatus(t *testing.T) {
	now := time.Date(2026, 5, 8, 10, 0, 0, 0, time.Local)
	expiredAt := now.Add(-time.Minute)
	activeAt := now.Add(time.Hour)
	revokedAt := now.Add(-2 * time.Hour)
	repo := &fakeRepository{
		listTotal: 3,
		listRows: []ListRow{
			{ID: 1, UserID: 11, Username: "active-user", Platform: "admin", DeviceID: "dev-1", IP: "127.0.0.1", UserAgent: "ua-1", LastSeenAt: now, ExpiresAt: now.Add(30 * time.Minute), RefreshExpiresAt: activeAt, CreatedAt: now.Add(-24 * time.Hour)},
			{ID: 2, UserID: 12, Username: "expired-user", Platform: "app", DeviceID: "dev-2", IP: "127.0.0.2", UserAgent: "ua-2", LastSeenAt: now.Add(-time.Hour), ExpiresAt: expiredAt, RefreshExpiresAt: expiredAt, CreatedAt: now.Add(-48 * time.Hour)},
			{ID: 3, UserID: 13, Username: "revoked-user", Platform: "admin", DeviceID: "dev-3", IP: "::1", UserAgent: "ua-3", LastSeenAt: now.Add(-2 * time.Hour), ExpiresAt: activeAt, RefreshExpiresAt: activeAt, RevokedAt: &revokedAt, CreatedAt: now.Add(-72 * time.Hour)},
		},
	}
	service := NewService(repo, WithNow(func() time.Time { return now }))

	got, appErr := service.List(context.Background(), ListQuery{
		CurrentPage: -1,
		PageSize:    999,
		Username:    " active-user ",
		Platform:    "admin",
		Status:      "active",
	})
	if appErr != nil {
		t.Fatalf("expected list to succeed, got %v", appErr)
	}
	if repo.listQuery.CurrentPage != 1 || repo.listQuery.PageSize != 50 {
		t.Fatalf("query was not normalized: %#v", repo.listQuery)
	}
	if repo.listQuery.Username != "active-user" || repo.listQuery.Platform != "admin" || repo.listQuery.Status != "active" {
		t.Fatalf("query filters mismatch: %#v", repo.listQuery)
	}
	if got.Page.Total != 3 || got.Page.TotalPage != 1 {
		t.Fatalf("page mismatch: %#v", got.Page)
	}
	if got.List[0].Status != SessionStatusActive || got.List[1].Status != SessionStatusExpired || got.List[2].Status != SessionStatusRevoked {
		t.Fatalf("status mismatch: %#v", got.List)
	}
	if got.List[0].PlatformName != "admin" || got.List[1].PlatformName != "app" {
		t.Fatalf("platform name mismatch: %#v", got.List)
	}
}

func TestListRejectsInvalidStatusAndPlatform(t *testing.T) {
	service := NewService(&fakeRepository{}, WithNow(func() time.Time {
		return time.Date(2026, 5, 8, 10, 0, 0, 0, time.Local)
	}))

	if _, appErr := service.List(context.Background(), ListQuery{CurrentPage: 1, PageSize: 20, Status: "bad"}); appErr == nil {
		t.Fatalf("expected invalid status to fail")
	}
	if _, appErr := service.List(context.Background(), ListQuery{CurrentPage: 1, PageSize: 20, Platform: "mini"}); appErr == nil {
		t.Fatalf("expected invalid platform to fail")
	}
}

func TestStatsAlwaysReturnsAdminAndAppKeys(t *testing.T) {
	now := time.Date(2026, 5, 8, 10, 0, 0, 0, time.Local)
	repo := &fakeRepository{statsRows: []StatsRow{
		{Platform: "admin", Total: 2},
	}}
	service := NewService(repo, WithNow(func() time.Time { return now }))

	got, appErr := service.Stats(context.Background())
	if appErr != nil {
		t.Fatalf("expected stats to succeed, got %v", appErr)
	}
	if got.TotalActive != 2 {
		t.Fatalf("total_active mismatch: %d", got.TotalActive)
	}
	if got.PlatformDistribution["admin"] != 2 || got.PlatformDistribution["app"] != 0 {
		t.Fatalf("platform_distribution mismatch: %#v", got.PlatformDistribution)
	}
}
```

- [ ] Run the failing test:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/usersession -run 'Test(List|Stats)' -count=1
```

Expected:

```text
FAIL
package admin_back_go/internal/module/usersession is not in std
```

or compile failure for missing `ListQuery`, `NewService`, and DTO types.

---

## Task 2: Backend usersession module implementation

**Files:**

```text
Create: admin_back_go/internal/module/usersession/dto.go
Create: admin_back_go/internal/module/usersession/request.go
Create: admin_back_go/internal/module/usersession/repository.go
Create: admin_back_go/internal/module/usersession/service.go
```

- [ ] Create `dto.go` with the exact public DTO surface:

```go
package usersession

import "time"

const (
	SessionStatusActive  = "active"
	SessionStatusExpired = "expired"
	SessionStatusRevoked = "revoked"
)

type Option[T string] struct {
	Label string `json:"label"`
	Value T      `json:"value"`
}

type PageInitResponse struct {
	Dict PageInitDict `json:"dict"`
}

type PageInitDict struct {
	PlatformArr []Option[string] `json:"platformArr"`
	StatusArr   []Option[string] `json:"statusArr"`
}

type ListQuery struct {
	CurrentPage int
	PageSize    int
	Username    string
	Platform    string
	Status      string
}

type Page struct {
	PageSize    int   `json:"page_size"`
	CurrentPage int   `json:"current_page"`
	TotalPage   int   `json:"total_page"`
	Total       int64 `json:"total"`
}

type ListResponse struct {
	List []ListItem `json:"list"`
	Page Page       `json:"page"`
}

type ListItem struct {
	ID               int64   `json:"id"`
	UserID           int64   `json:"user_id"`
	Username         string  `json:"username"`
	Platform         string  `json:"platform"`
	PlatformName     string  `json:"platform_name"`
	DeviceID         string  `json:"device_id"`
	IP               string  `json:"ip"`
	UserAgent        string  `json:"ua"`
	LastSeenAt       string  `json:"last_seen_at"`
	CreatedAt        string  `json:"created_at"`
	ExpiresAt        string  `json:"expires_at"`
	RefreshExpiresAt string  `json:"refresh_expires_at"`
	RevokedAt        *string `json:"revoked_at"`
	Status           string  `json:"status"`
}

type ListRow struct {
	ID               int64
	UserID           int64
	Username         string
	Platform         string
	DeviceID         string
	IP               string
	UserAgent        string
	LastSeenAt       time.Time
	CreatedAt        time.Time
	ExpiresAt        time.Time
	RefreshExpiresAt time.Time
	RevokedAt        *time.Time
}

type StatsResponse struct {
	TotalActive          int64            `json:"total_active"`
	PlatformDistribution map[string]int64 `json:"platform_distribution"`
}

type StatsRow struct {
	Platform string
	Total    int64
}
```

- [ ] Create `request.go`:

```go
package usersession

type listRequest struct {
	CurrentPage int    `form:"current_page"`
	PageSize    int    `form:"page_size"`
	Username    string `form:"username"`
	Platform    string `form:"platform"`
	Status      string `form:"status"`
}
```

- [ ] Create `repository.go` with a GORM implementation:

```go
package usersession

import (
	"context"
	"errors"
	"strings"
	"time"

	"admin_back_go/internal/enum"
	"admin_back_go/internal/platform/database"

	"gorm.io/gorm"
)

var ErrRepositoryNotConfigured = errors.New("user session repository is not configured")

type Repository interface {
	List(ctx context.Context, query ListQuery) ([]ListRow, int64, error)
	Stats(ctx context.Context, now time.Time) ([]StatsRow, error)
}

type GormRepository struct {
	db *gorm.DB
}

func NewGormRepository(client *database.Client) *GormRepository {
	if client == nil || client.Gorm == nil {
		return nil
	}
	return &GormRepository{db: client.Gorm}
}

func (r *GormRepository) List(ctx context.Context, query ListQuery) ([]ListRow, int64, error) {
	if r == nil || r.db == nil {
		return nil, 0, ErrRepositoryNotConfigured
	}
	db := r.baseListQuery(ctx, query)

	var total int64
	if err := db.Count(&total).Error; err != nil {
		return nil, 0, err
	}

	var rows []ListRow
	now := time.Now()
	err := db.Select(`
			us.id,
			us.user_id,
			COALESCE(u.username, '') AS username,
			us.platform,
			us.device_id,
			us.ip,
			COALESCE(us.ua, '') AS user_agent,
			us.last_seen_at,
			us.created_at,
			us.expires_at,
			us.refresh_expires_at,
			us.revoked_at
		`).
		Order(`
			CASE
				WHEN us.revoked_at IS NULL AND us.refresh_expires_at > ? THEN 1
				WHEN us.revoked_at IS NULL AND us.refresh_expires_at <= ? THEN 2
				ELSE 3
			END ASC
		`, now, now).
		Order("us.last_seen_at DESC").
		Limit(query.PageSize).
		Offset((query.CurrentPage - 1) * query.PageSize).
		Scan(&rows).Error
	if err != nil {
		return nil, 0, err
	}
	return rows, total, nil
}

func (r *GormRepository) Stats(ctx context.Context, now time.Time) ([]StatsRow, error) {
	if r == nil || r.db == nil {
		return nil, ErrRepositoryNotConfigured
	}
	var rows []StatsRow
	err := r.db.WithContext(ctx).
		Table("user_sessions AS us").
		Where("us.is_del = ?", enum.CommonNo).
		Where("us.revoked_at IS NULL").
		Where("us.refresh_expires_at > ?", now).
		Select("us.platform, COUNT(*) AS total").
		Group("us.platform").
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	return rows, nil
}

func (r *GormRepository) baseListQuery(ctx context.Context, query ListQuery) *gorm.DB {
	db := r.db.WithContext(ctx).
		Table("user_sessions AS us").
		Joins("LEFT JOIN users AS u ON u.id = us.user_id").
		Where("us.is_del = ?", enum.CommonNo)

	if query.Username != "" {
		db = db.Where("u.username LIKE ?", strings.TrimSpace(query.Username)+"%")
	}
	if query.Platform != "" {
		db = db.Where("us.platform = ?", query.Platform)
	}
	if query.Status != "" {
		now := time.Now()
		switch query.Status {
		case SessionStatusActive:
			db = db.Where("us.revoked_at IS NULL").Where("us.refresh_expires_at > ?", now)
		case SessionStatusExpired:
			db = db.Where("us.revoked_at IS NULL").Where("us.refresh_expires_at <= ?", now)
		case SessionStatusRevoked:
			db = db.Where("us.revoked_at IS NOT NULL")
		}
	}
	return db
}
```

Then immediately fix the two `time.Now()` calls in repository to receive the already-normalized `query.Now` only if you add `Now time.Time` to `ListQuery`. Do not leave multiple clocks inside one request. The clean version is:

```go
type ListQuery struct {
	CurrentPage int
	PageSize    int
	Username    string
	Platform    string
	Status      string
	Now         time.Time
}
```

and repository uses `query.Now` in filter and sort. This avoids a dumb boundary bug around exact expiry time.

- [ ] Create `service.go`:

```go
package usersession

import (
	"context"
	"math"
	"strings"
	"time"

	"admin_back_go/internal/apperror"
	"admin_back_go/internal/dict"
	"admin_back_go/internal/enum"
)

const timeLayout = "2006-01-02 15:04:05"

type HTTPService interface {
	PageInit(ctx context.Context) (*PageInitResponse, *apperror.Error)
	List(ctx context.Context, query ListQuery) (*ListResponse, *apperror.Error)
	Stats(ctx context.Context) (*StatsResponse, *apperror.Error)
}

type OptionFunc func(*Service)

type Service struct {
	repository Repository
	now        func() time.Time
}

func NewService(repository Repository, opts ...OptionFunc) *Service {
	service := &Service{
		repository: repository,
		now:        time.Now,
	}
	for _, opt := range opts {
		if opt != nil {
			opt(service)
		}
	}
	return service
}

func WithNow(now func() time.Time) OptionFunc {
	return func(s *Service) {
		if now != nil {
			s.now = now
		}
	}
}

func (s *Service) PageInit(ctx context.Context) (*PageInitResponse, *apperror.Error) {
	return &PageInitResponse{Dict: PageInitDict{
		PlatformArr: []Option[string]{
			{Label: enum.PlatformAdmin, Value: enum.PlatformAdmin},
			{Label: enum.PlatformApp, Value: enum.PlatformApp},
		},
		StatusArr: []Option[string]{
			{Label: "在线", Value: SessionStatusActive},
			{Label: "已过期", Value: SessionStatusExpired},
			{Label: "已下线", Value: SessionStatusRevoked},
		},
	}}, nil
}

func (s *Service) List(ctx context.Context, query ListQuery) (*ListResponse, *apperror.Error) {
	repo, appErr := s.requireRepository()
	if appErr != nil {
		return nil, appErr
	}
	query, appErr = s.normalizeListQuery(query)
	if appErr != nil {
		return nil, appErr
	}
	rows, total, err := repo.List(ctx, query)
	if err != nil {
		return nil, apperror.Wrap(apperror.CodeInternal, 500, "查询用户会话失败", err)
	}
	list := make([]ListItem, 0, len(rows))
	for _, row := range rows {
		list = append(list, listItem(row, query.Now))
	}
	return &ListResponse{
		List: list,
		Page: Page{PageSize: query.PageSize, CurrentPage: query.CurrentPage, TotalPage: totalPage(total, query.PageSize), Total: total},
	}, nil
}

func (s *Service) Stats(ctx context.Context) (*StatsResponse, *apperror.Error) {
	repo, appErr := s.requireRepository()
	if appErr != nil {
		return nil, appErr
	}
	rows, err := repo.Stats(ctx, s.now())
	if err != nil {
		return nil, apperror.Wrap(apperror.CodeInternal, 500, "查询用户会话统计失败", err)
	}
	dist := map[string]int64{
		enum.PlatformAdmin: 0,
		enum.PlatformApp:   0,
	}
	var total int64
	for _, row := range rows {
		if row.Platform == "" {
			continue
		}
		dist[row.Platform] = row.Total
		total += row.Total
	}
	return &StatsResponse{TotalActive: total, PlatformDistribution: dist}, nil
}

func (s *Service) requireRepository() (Repository, *apperror.Error) {
	if s == nil || s.repository == nil {
		return nil, apperror.Internal("用户会话仓储未配置")
	}
	return s.repository, nil
}

func (s *Service) normalizeListQuery(query ListQuery) (ListQuery, *apperror.Error) {
	if query.CurrentPage <= 0 {
		query.CurrentPage = 1
	}
	if query.PageSize <= 0 {
		query.PageSize = 20
	}
	if query.PageSize > enum.PageSizeMax {
		query.PageSize = enum.PageSizeMax
	}
	query.Username = strings.TrimSpace(query.Username)
	query.Platform = strings.TrimSpace(query.Platform)
	query.Status = strings.TrimSpace(query.Status)
	if query.Platform != "" && !enum.IsPlatform(query.Platform) {
		return query, apperror.BadRequest("无效的平台标识")
	}
	if query.Status != "" && !isSessionStatus(query.Status) {
		return query, apperror.BadRequest("无效的会话状态")
	}
	query.Now = s.now()
	return query, nil
}

func isSessionStatus(value string) bool {
	return value == SessionStatusActive || value == SessionStatusExpired || value == SessionStatusRevoked
}

func listItem(row ListRow, now time.Time) ListItem {
	revokedAt := formatOptionalTime(row.RevokedAt)
	return ListItem{
		ID: row.ID, UserID: row.UserID, Username: row.Username,
		Platform: row.Platform, PlatformName: platformName(row.Platform),
		DeviceID: row.DeviceID, IP: row.IP, UserAgent: row.UserAgent,
		LastSeenAt: formatTime(row.LastSeenAt), CreatedAt: formatTime(row.CreatedAt),
		ExpiresAt: formatTime(row.ExpiresAt), RefreshExpiresAt: formatTime(row.RefreshExpiresAt),
		RevokedAt: revokedAt, Status: sessionStatus(row, now),
	}
}

func sessionStatus(row ListRow, now time.Time) string {
	if row.RevokedAt != nil {
		return SessionStatusRevoked
	}
	if !row.RefreshExpiresAt.After(now) {
		return SessionStatusExpired
	}
	return SessionStatusActive
}

func platformName(platform string) string {
	for _, item := range dict.PlatformOptions() {
		if item.Value == platform {
			return item.Label
		}
	}
	return platform
}

func formatOptionalTime(value *time.Time) *string {
	if value == nil || value.IsZero() {
		return nil
	}
	formatted := value.Format(timeLayout)
	return &formatted
}

func formatTime(value time.Time) string {
	if value.IsZero() {
		return ""
	}
	return value.Format(timeLayout)
}

func totalPage(total int64, pageSize int) int {
	if total <= 0 || pageSize <= 0 {
		return 0
	}
	return int(math.Ceil(float64(total) / float64(pageSize)))
}
```

- [ ] Run module tests:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/usersession -count=1
```

Expected:

```text
ok  	admin_back_go/internal/module/usersession
```

---

## Task 3: Backend HTTP handler and routes

**Files:**

```text
Create: admin_back_go/internal/module/usersession/handler.go
Create: admin_back_go/internal/module/usersession/route.go
Create: admin_back_go/internal/module/usersession/handler_test.go
```

- [ ] Create `handler_test.go` before the handler implementation. Cover all three routes and invalid query binding.

Use this concrete fake service shape:

```go
package usersession

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"admin_back_go/internal/apperror"

	"github.com/gin-gonic/gin"
)

type fakeHTTPService struct {
	pageInitResult *PageInitResponse
	listQuery      ListQuery
	listResult     *ListResponse
	statsResult    *StatsResponse
	err            *apperror.Error
}

func (f *fakeHTTPService) PageInit(ctx context.Context) (*PageInitResponse, *apperror.Error) {
	return f.pageInitResult, f.err
}

func (f *fakeHTTPService) List(ctx context.Context, query ListQuery) (*ListResponse, *apperror.Error) {
	f.listQuery = query
	return f.listResult, f.err
}

func (f *fakeHTTPService) Stats(ctx context.Context) (*StatsResponse, *apperror.Error) {
	return f.statsResult, f.err
}

func TestHandlerRoutesUserSessionReadOnlyEndpoints(t *testing.T) {
	gin.SetMode(gin.TestMode)
	service := &fakeHTTPService{
		pageInitResult: &PageInitResponse{},
		listResult: &ListResponse{Page: Page{PageSize: 30, CurrentPage: 2, Total: 1, TotalPage: 1}},
		statsResult: &StatsResponse{TotalActive: 1, PlatformDistribution: map[string]int64{"admin": 1, "app": 0}},
	}
	router := gin.New()
	RegisterRoutes(router, service)

	req := httptest.NewRequest(http.MethodGet, "/api/admin/v1/user-sessions?current_page=2&page_size=30&username=test&platform=admin&status=active", nil)
	resp := httptest.NewRecorder()
	router.ServeHTTP(resp, req)
	if resp.Code != http.StatusOK {
		t.Fatalf("list status=%d body=%s", resp.Code, resp.Body.String())
	}
	if service.listQuery.CurrentPage != 2 || service.listQuery.PageSize != 30 || service.listQuery.Username != "test" || service.listQuery.Platform != "admin" || service.listQuery.Status != "active" {
		t.Fatalf("list query mismatch: %#v", service.listQuery)
	}

	for _, path := range []string{"/api/admin/v1/user-sessions/page-init", "/api/admin/v1/user-sessions/stats"} {
		req = httptest.NewRequest(http.MethodGet, path, nil)
		resp = httptest.NewRecorder()
		router.ServeHTTP(resp, req)
		if resp.Code != http.StatusOK {
			t.Fatalf("%s status=%d body=%s", path, resp.Code, resp.Body.String())
		}
		var envelope map[string]any
		if err := json.Unmarshal(resp.Body.Bytes(), &envelope); err != nil {
			t.Fatalf("decode response: %v", err)
		}
	}
}
```

- [ ] Run failing handler test:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/usersession -run TestHandlerRoutesUserSessionReadOnlyEndpoints -count=1
```

Expected: fail because `RegisterRoutes` / handler do not exist.

- [ ] Create `handler.go`:

```go
package usersession

import (
	"context"

	"admin_back_go/internal/apperror"
	"admin_back_go/internal/response"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	service HTTPService
}

func NewHandler(service HTTPService) *Handler {
	return &Handler{service: service}
}

func (h *Handler) PageInit(c *gin.Context) {
	result, appErr := h.requireService().PageInit(c.Request.Context())
	writeResult(c, result, appErr)
}

func (h *Handler) List(c *gin.Context) {
	var req listRequest
	if err := c.ShouldBindQuery(&req); err != nil {
		response.Error(c, apperror.BadRequest("用户会话列表参数错误"))
		return
	}
	result, appErr := h.requireService().List(c.Request.Context(), ListQuery{
		CurrentPage: req.CurrentPage,
		PageSize:    req.PageSize,
		Username:    req.Username,
		Platform:    req.Platform,
		Status:      req.Status,
	})
	writeResult(c, result, appErr)
}

func (h *Handler) Stats(c *gin.Context) {
	result, appErr := h.requireService().Stats(c.Request.Context())
	writeResult(c, result, appErr)
}

func (h *Handler) requireService() HTTPService {
	if h == nil || h.service == nil {
		return nilHTTPService{}
	}
	return h.service
}

func writeResult(c *gin.Context, result any, appErr *apperror.Error) {
	if appErr != nil {
		response.Error(c, appErr)
		return
	}
	response.OK(c, result)
}

type nilHTTPService struct{}

func (nilHTTPService) PageInit(ctx context.Context) (*PageInitResponse, *apperror.Error) {
	return nil, apperror.Internal("用户会话服务未配置")
}

func (nilHTTPService) List(ctx context.Context, query ListQuery) (*ListResponse, *apperror.Error) {
	return nil, apperror.Internal("用户会话服务未配置")
}

func (nilHTTPService) Stats(ctx context.Context) (*StatsResponse, *apperror.Error) {
	return nil, apperror.Internal("用户会话服务未配置")
}
```

- [ ] Create `route.go`:

```go
package usersession

import (
	"admin_back_go/internal/validate"

	"github.com/gin-gonic/gin"
)

func RegisterRoutes(router *gin.Engine, service HTTPService) {
	validate.MustRegister()
	handler := NewHandler(service)

	group := router.Group("/api/admin/v1/user-sessions")
	group.GET("/page-init", handler.PageInit)
	group.GET("/stats", handler.Stats)
	group.GET("", handler.List)
}
```

- [ ] Run handler tests:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/usersession -run TestHandler -count=1
```

Expected:

```text
ok  	admin_back_go/internal/module/usersession
```

---

## Task 4: Wire backend router and bootstrap

**Files:**

```text
Modify: admin_back_go/internal/server/router.go
Modify: admin_back_go/internal/server/router_test.go
Modify: admin_back_go/internal/bootstrap/app.go
```

- [ ] Add `usersession` import and dependency in `server/router.go`.

Expected changes:

```go
import (
	// existing imports
	"admin_back_go/internal/module/usersession"
)

type Dependencies struct {
	// existing fields
	UserSessionService usersession.HTTPService
}

func NewRouter(deps Dependencies) *gin.Engine {
	// existing route registrations
	usersession.RegisterRoutes(router, deps.UserSessionService)
	return router
}
```

Place `usersession.RegisterRoutes` near `user.RegisterRoutes`, not in pay/system areas.

- [ ] Add a router test before wiring if there is no existing generic route coverage.

Append a focused test to `admin_back_go/internal/server/router_test.go` using the existing test helpers in that file. If no helper matches cleanly, use a tiny fake service:

```go
type fakeUserSessionService struct{}

func (fakeUserSessionService) PageInit(ctx context.Context) (*usersession.PageInitResponse, *apperror.Error) {
	return &usersession.PageInitResponse{}, nil
}

func (fakeUserSessionService) List(ctx context.Context, query usersession.ListQuery) (*usersession.ListResponse, *apperror.Error) {
	return &usersession.ListResponse{Page: usersession.Page{PageSize: query.PageSize, CurrentPage: query.CurrentPage}}, nil
}

func (fakeUserSessionService) Stats(ctx context.Context) (*usersession.StatsResponse, *apperror.Error) {
	return &usersession.StatsResponse{TotalActive: 0, PlatformDistribution: map[string]int64{"admin": 0, "app": 0}}, nil
}
```

The route test must request:

```text
GET /api/admin/v1/user-sessions/page-init
GET /api/admin/v1/user-sessions?current_page=1&page_size=20
GET /api/admin/v1/user-sessions/stats
```

Expected: all return 200 when AuthToken middleware is skipped or test authenticator passes, following the existing router test style.

- [ ] Wire bootstrap in `admin_back_go/internal/bootstrap/app.go`.

Expected service creation:

```go
userSessionService := usersession.NewService(usersession.NewGormRepository(resources.DB))
```

Expected router dependency:

```go
UserSessionService: userSessionService,
```

- [ ] Do not add route metadata in `route_meta.go` for the three read-only endpoints. This is deliberate: legacy list/stats had no `@Permission`; this slice is bearer-token only.

- [ ] Run backend routing checks:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/usersession ./internal/server ./internal/bootstrap -count=1
```

Expected:

```text
ok  	admin_back_go/internal/module/usersession
ok  	admin_back_go/internal/server
ok  	admin_back_go/internal/bootstrap
```

---

## Task 5: Admin API contract docs

**Files:**

```text
Modify: docs/contracts/admin-api-v1.md
```

- [ ] Add `user-sessions` to the auth/permission summary near users management:

```text
| user session read-only | `GET /api/admin/v1/user-sessions/page-init`, `GET /api/admin/v1/user-sessions`, `GET /api/admin/v1/user-sessions/stats` | bearer token |
```

- [ ] Add a `## User Sessions Read-only` section after `## Users Management`.

Use this exact contract text:

```markdown
## User Sessions Read-only

Purpose: read existing login sessions from `user_sessions` for the admin user-session page. This slice is read-only. Kick-offline mutations remain legacy until the separate write contract is implemented.

### Page init

`GET /api/admin/v1/user-sessions/page-init`

Auth: bearer token.

Response:

```ts
interface UserSessionPageInitResponse {
  dict: {
    platformArr: Array<{ label: string; value: 'admin' | 'app' }>
    statusArr: Array<{ label: string; value: 'active' | 'expired' | 'revoked' }>
  }
}
```

### List

`GET /api/admin/v1/user-sessions`

Auth: bearer token.

Query:

```ts
interface UserSessionListParams {
  current_page: number
  page_size: number
  username?: string
  platform?: 'admin' | 'app'
  status?: 'active' | 'expired' | 'revoked'
}
```

Response:

```ts
interface UserSessionListResponse {
  list: UserSessionItem[]
  page: { page_size: number; current_page: number; total_page: number; total: number }
}
```

Rules:

```text
is_del = 2
status active = revoked_at IS NULL AND refresh_expires_at > now
status expired = revoked_at IS NULL AND refresh_expires_at <= now
status revoked = revoked_at IS NOT NULL
sort = active -> expired -> revoked, then last_seen_at desc
access_token_hash and refresh_token_hash are never returned
```

### Stats

`GET /api/admin/v1/user-sessions/stats`

Auth: bearer token.

Response:

```ts
interface UserSessionStats {
  total_active: number
  platform_distribution: Record<string, number> & { admin: number; app: number }
}
```
```

- [ ] Check the contract does not claim kick is Go-backed.

Run:

```powershell
cd E:\admin_go
rg -n "user-sessions|UserSession|kick" docs/contracts/admin-api-v1.md
```

Expected:

```text
The read-only user-sessions endpoints exist.
No Go kick endpoint is documented in this section.
```

---

## Task 6: Frontend API adapter and types

**Files:**

```text
Modify: admin_front_ts/src/types/user.ts
Modify: admin_front_ts/src/api/user/users.ts
Modify: admin_front_ts/src/views/Main/user/userManager/components/SessionList/index.vue
Modify: admin_front_ts/tests/shared/user/users-api.test.ts
```

- [ ] Update `admin_front_ts/src/types/user.ts`.

Add:

```ts
export interface UserSessionPageInitResponse {
  dict: {
    platformArr: DictOption<string>[]
    statusArr: DictOption<UserSessionStatus>[]
  }
}
```

Keep existing:

```ts
export interface UserSessionListParams
export interface UserSessionItem
export interface UserSessionStats
export interface UserSessionKickParams
export interface UserSessionBatchKickParams
export type UserSessionListResponse = PaginatedResponse<UserSessionItem>
```

- [ ] Update imports in `admin_front_ts/src/api/user/users.ts`:

```ts
import type {
  // existing types
  UserSessionPageInitResponse,
} from '@/types/user'
```

- [ ] Change `UserSessionApi` read methods only:

```ts
function normalizeUserSessionListParams(params: UserSessionListParams) {
  const query: UserSessionListParams = {
    current_page: params.current_page,
    page_size: params.page_size,
  }

  const username = params.username?.trim()
  if (username) {
    query.username = username
  }
  if (params.platform) {
    query.platform = params.platform
  }
  if (params.status) {
    query.status = params.status
  }
  return query
}

export const UserSessionApi = {
  pageInit: () =>
    request.get<UserSessionPageInitResponse>(`${ADMIN_API_PREFIX}/user-sessions/page-init`),

  list: (params: UserSessionListParams) =>
    request.get<UserSessionListResponse>(`${ADMIN_API_PREFIX}/user-sessions`, { params: normalizeUserSessionListParams(params) }),

  stats: () =>
    request.get<UserSessionStats>(`${ADMIN_API_PREFIX}/user-sessions/stats`),

  kick: (params: UserSessionKickParams) =>
    legacyRequest.post<void>('/api/admin/UserSession/kick', params),

  batchKick: (params: UserSessionBatchKickParams) =>
    legacyRequest.post<{ count: number }>('/api/admin/UserSession/batchKick', params),
}
```

- [ ] Update `SessionList/index.vue` so `init` uses the new page-init instead of the broad users page-init:

```ts
const init = async () => {
  try {
    const data = await UserSessionApi.pageInit()
    platformArr.value = data.dict.platformArr || []
  } catch {
    // request interceptor handles notification
  }
}
```

Do not change the table columns, cards, buttons, CSS, or i18n in this slice.

- [ ] Extend `admin_front_ts/tests/shared/user/users-api.test.ts` with a read-only contract test:

```ts
it('uses Go REST for user session read-only APIs and keeps kick legacy for now', () => {
  const source = readUsersApiSource()

  expect(source).toContain('request.get<UserSessionPageInitResponse>(`${ADMIN_API_PREFIX}/user-sessions/page-init`)')
  expect(source).toContain('request.get<UserSessionListResponse>(`${ADMIN_API_PREFIX}/user-sessions`, { params: normalizeUserSessionListParams(params) })')
  expect(source).toContain('request.get<UserSessionStats>(`${ADMIN_API_PREFIX}/user-sessions/stats`)')
  expect(source).not.toContain("legacyRequest.post<UserSessionListResponse>('/api/admin/UserSession/list', params)")
  expect(source).not.toContain("legacyRequest.post<UserSessionStats>('/api/admin/UserSession/stats')")
  expect(source).toContain("legacyRequest.post<void>('/api/admin/UserSession/kick', params)")
  expect(source).toContain("legacyRequest.post<{ count: number }>('/api/admin/UserSession/batchKick', params)")
})
```

- [ ] Run frontend focused test:

```powershell
cd E:\admin_go\admin_front_ts
npm test -- tests/shared/user/users-api.test.ts
```

Expected:

```text
PASS  tests/shared/user/users-api.test.ts
```

---

## Task 7: Smoke script read-only probes

**Files:**

```text
Modify: admin_back_go/scripts/full-admin-smoke.ps1
Modify: docs/testing/smoke-matrix.md
```

- [ ] Add full-smoke probes after users page-init/list smoke, because UserSession is part of user management but read-only in this slice.

Probe these endpoints with the current login token:

```text
GET /api/admin/v1/user-sessions/page-init
GET /api/admin/v1/user-sessions?current_page=1&page_size=10
GET /api/admin/v1/user-sessions/stats
```

Assertions:

```text
page-init response has dict.platformArr and dict.statusArr
list response has list array and page object
list item, when present, must not contain access_token_hash
list item, when present, must not contain refresh_token_hash
stats response has total_active and platform_distribution.admin/app
```

Do not add kick smoke in this slice.

- [ ] Add a row in `docs/testing/smoke-matrix.md`:

```text
| user session read-only | no | yes | `GET /api/admin/v1/user-sessions/page-init`, list, stats | read-only | n/a | Proves Go owns session list/stats shape and does not leak token hashes; kick remains legacy until write slice |
```

- [ ] Run the smoke only after the backend is running:

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected:

```text
summary includes user session page-init/list/stats as passed
no token hash leakage assertion fails
```

---

## Task 8: Migration status docs

**Files:**

```text
Modify: docs/migration/current-status.md
```

- [ ] Add a new current-status row near users management:

```markdown
| user session read-only | partially implemented: `GET /api/admin/v1/user-sessions/page-init`, list, and stats read existing `user_sessions` without token hash leakage; kick/batch kick remain legacy until write slice | adapted for read-only list/stats/page-init; kick buttons still call legacy endpoints | `internal/module/usersession`, router/bootstrap tests, frontend users-api Vitest | full smoke read-only probes page-init/list/stats | admin API contract + smoke matrix | no Go kick yet; Redis token deletion/current-session anti-kick/OperationLog are next slice |
```

- [ ] Do not edit the existing `auth login/session` row to imply session management UI is fully migrated.

- [ ] Run a residue check:

```powershell
cd E:\admin_go
rg -n "UserSession/list|UserSession/stats|user-sessions|kick" docs admin_front_ts/src/api/user/users.ts
```

Expected:

```text
legacy UserSession/list and UserSession/stats no longer appear in frontend API.
legacy UserSession/kick and UserSession/batchKick still appear in frontend API.
docs mention user-sessions read-only endpoints.
docs do not claim Go kick is implemented.
```

---

## Task 9: Final verification

**Files:** no new file changes unless a verification failure points to a concrete bug.

- [ ] Run backend full tests:

```powershell
cd E:\admin_go\admin_back_go
go test ./...
```

Expected:

```text
PASS for all packages
```

- [ ] Run frontend focused contract test:

```powershell
cd E:\admin_go\admin_front_ts
npm test -- tests/shared/user/users-api.test.ts
```

Expected:

```text
PASS
```

- [ ] Run frontend type/build gate if dependencies are healthy:

```powershell
cd E:\admin_go\admin_front_ts
npm run build:check
```

Expected:

```text
vue-tsc and vite build succeed
```

If this fails due to unrelated existing frontend warnings or dependency corruption, capture the exact error and do not hide it.

- [ ] Run full smoke with the Go backend running:

```powershell
cd E:\admin_go\admin_back_go
powershell -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1 -Account 15671628271 -Password 123456
```

Expected:

```text
user session page-init/list/stats probes pass
no access_token_hash or refresh_token_hash appears in user-session list response
existing login/users/RBAC smoke remains green
```

- [ ] Check git status in both subrepos:

```powershell
cd E:\admin_go
git -C admin_back_go status --short
git -C admin_front_ts status --short
git status --short
```

Expected:

```text
Only planned files changed.
No runtime temp files, certs, build outputs, node_modules, or smoke artifacts are staged.
```

---

## Commit Plan

Use small commits if the user asks to commit:

```powershell
cd E:\admin_go
git add docs/contracts/admin-api-v1.md docs/migration/current-status.md docs/testing/smoke-matrix.md docs/superpowers/plans/2026-05-08-user-session-readonly-list.md
git commit -m "docs: plan user session read-only migration"
```

After implementation, use separate subrepo commits:

```powershell
cd E:\admin_go\admin_back_go
git add internal/module/usersession internal/server/router.go internal/server/router_test.go internal/bootstrap/app.go scripts/full-admin-smoke.ps1
git commit -m "feat: add user session read-only api"

cd E:\admin_go\admin_front_ts
git add src/types/user.ts src/api/user/users.ts src/views/Main/user/userManager/components/SessionList/index.vue tests/shared/user/users-api.test.ts
git commit -m "feat: use go user session read APIs"
```

Only commit after verification passes or after documenting any unrelated blocker.

---

## Self-review Checklist

Spec coverage:

```text
page-init: Task 3/4/5/6/7
list: Task 1/2/3/4/5/6/7
stats: Task 1/2/3/4/5/6/7
frontend legacy removal for read-only: Task 6
kick stays legacy: Scope + Task 6 + Task 8
docs/status/smoke: Task 5/7/8
verification: Task 9
```

Bad smell scan:

```text
No new dependency.
No DB migration.
No token hash response.
No service depending on gin.Context.
No handler DB access.
No repository business decision beyond SQL filtering/sorting.
No vague compatibility fallback.
```

Next slice after this plan:

```text
UserSession kick/batchKick Go write contract:
PATCH /api/admin/v1/user-sessions/:id/kick
PATCH /api/admin/v1/user-sessions/kick
```

That write slice must handle:

```text
user_userManager_kick permission
OperationLog metadata
current session cannot kick itself
batch excludes current session or rejects empty effective ids
DB revoke and token Redis key deletion
single-session pointer cleanup
stats consistency after revoke
```
