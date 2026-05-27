# 兼容路由命名与模块边界治理 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 active code 里的裸 `legacy` 路由命名收口成明确的 `compat` 语义，并用文档和架构测试固定“module 是业务能力边界，platform/compat/legacy 都不是 module”。

**Architecture:** 不改公开 URL、不改 handler 行为、不改 service 逻辑，只治理命名、文档和架构守卫。`/api/Users/*` 继续作为兼容入口存在，但当前职责命名为 `*Compat`；`legacy` 只保留为历史来源描述，不作为 active code owner。`internal/module` 继续保留 capability module 模式，但明确模块内部文件是“最多集合”，不是每个模块必须凑满五层。

**Tech Stack:** Go 1.26、Gin、Go test、PowerShell、项目自有架构文档与 governance hook。

---

## 设计输入

Spec：`docs/superpowers/specs/2026-05-27-compat-route-naming-and-module-boundary-design.md`

当前事实：

```text
admin_back_go/internal/module/auth/route.go 存在 legacy := router.Group("/api/Users")
admin_back_go/internal/module/user/route.go 存在 legacy := router.Group("/api/Users")
admin_back_go/internal/architecture/platform_scope_test.go 已阻止平台命名 auth module 回潮
```

本计划只做治理第一刀：命名 + 架构守卫 + 文档，不做 URL 删除和目录大迁移。

## 文件结构

新增：

- `admin_back_go/internal/architecture/compat_route_naming_test.go`：扫描 `internal/module` 下非测试 Go 文件，阻止裸 `legacy := router.Group(...)` 回潮。

修改：

- `admin_back_go/internal/module/auth/route.go`：把 `v1` 改成 `adminAuth`，把 `legacy` 改成 `usersAuthCompat`。
- `admin_back_go/internal/module/user/route.go`：把 `legacy` 改成 `usersCompat`。
- `docs/architecture/04-go-backend-framework.md`：把“旧接口与新接口”章节收口为 compat adapter 语义，补充 active code 命名规则。
- `docs/architecture/05-development-quality-rules.md`：把允许项里的 `legacy adapter` 改为 `compat adapter`，补充 `legacy` 只表示历史来源。
- `admin_back_go/internal/module/README.md`：强调 module 是 capability boundary，内部文件是最多集合，不是强制层级。

不修改：

- 不改任何 `router.Group(...)` 的 URL 字符串。
- 不改任何 handler/service/repository/model。
- 不改前端 API。
- 不改 DB migration。

---

## Task 1: 写架构守卫 RED 测试，证明裸 `legacy` 路由命名当前会失败

**Files:**

- Create: `admin_back_go/internal/architecture/compat_route_naming_test.go`

- [ ] **Step 1: 写失败测试**

创建 `admin_back_go/internal/architecture/compat_route_naming_test.go`：

```go
package architecture_test

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestCompatRoutesDoNotUseBareLegacyVariable(t *testing.T) {
	moduleRoot := filepath.Clean("../module")
	var offenders []string

	err := filepath.WalkDir(moduleRoot, func(path string, entry os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if entry.IsDir() {
			return nil
		}
		if !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return nil
		}

		content, readErr := os.ReadFile(path)
		if readErr != nil {
			return readErr
		}
		text := string(content)
		if strings.Contains(text, "legacy := router.Group(") || strings.Contains(text, "legacy:=router.Group(") {
			offenders = append(offenders, filepath.ToSlash(path))
		}
		return nil
	})
	if err != nil {
		t.Fatalf("scan module routes: %v", err)
	}
	if len(offenders) > 0 {
		t.Fatalf("compat routes must use explicit *Compat variable names, not bare legacy: %s", strings.Join(offenders, ", "))
	}
}
```

- [ ] **Step 2: 运行测试确认 RED**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture -count=1
```

Expected:

```text
FAIL: TestCompatRoutesDoNotUseBareLegacyVariable
compat routes must use explicit *Compat variable names, not bare legacy: ../module/auth/route.go, ../module/user/route.go
```

如果只列出其中一个文件，也仍然是正确 RED；说明当前至少有一个裸 `legacy` 命名需要治理。

- [ ] **Step 3: 暂不提交**

本 task 只建立 RED。下一 task 做最小生产代码改名后再一起提交。

---

## Task 2: 最小改名，不改变任何路由行为

**Files:**

- Modify: `admin_back_go/internal/module/auth/route.go`
- Modify: `admin_back_go/internal/module/user/route.go`
- Test: `admin_back_go/internal/architecture/compat_route_naming_test.go`

- [ ] **Step 1: 修改 auth 路由变量名**

把 `admin_back_go/internal/module/auth/route.go` 改成：

```go
package auth

import (
	"admin_back_go/internal/validate"

	"github.com/gin-gonic/gin"
)

func RegisterRoutes(router *gin.Engine, service SessionService) {
	validate.MustRegister()
	handler := NewHandler(service)

	adminAuth := router.Group("/api/admin/v1/auth")
	adminAuth.GET("/login-config", handler.LoginConfig)
	adminAuth.POST("/send-code", handler.SendCode)
	adminAuth.POST("/forgot-password", handler.ForgetPassword)
	adminAuth.POST("/login", handler.Login)
	adminAuth.POST("/refresh", handler.Refresh)
	adminAuth.POST("/logout", handler.Logout)

	usersAuthCompat := router.Group("/api/Users")
	usersAuthCompat.POST("/getLoginConfig", handler.LoginConfig)
	usersAuthCompat.POST("/sendCode", handler.SendCode)
	usersAuthCompat.POST("/login", handler.Login)
	usersAuthCompat.POST("/refresh", handler.Refresh)
	usersAuthCompat.POST("/logout", handler.Logout)
}
```

- [ ] **Step 2: 修改 user 路由变量名**

把 `admin_back_go/internal/module/user/route.go` 改成：

```go
package user

import (
	"admin_back_go/internal/validate"

	"github.com/gin-gonic/gin"
)

func RegisterRoutes(router *gin.Engine, service HTTPService) {
	validate.MustRegister()
	handler := NewHandler(service)

	usersCompat := router.Group("/api/Users")
	usersCompat.POST("/init", handler.Init)

	users := router.Group("/api/admin/v1/users")
	users.GET("/init", handler.Init)
	users.GET("/me", handler.Me)
	users.GET("/page-init", handler.PageInit)
	users.GET("/:id/profile", handler.UserProfile)
	users.GET("", handler.List)
	users.POST("/export", handler.Export)
	users.PUT("/:id", handler.Update)
	users.PATCH("/:id/status", handler.ChangeStatus)
	users.PATCH("", handler.BatchUpdateProfile)
	users.DELETE("/:id", handler.DeleteOne)
	users.DELETE("", handler.DeleteBatch)

	profile := router.Group("/api/admin/v1/profile")
	profile.GET("", handler.CurrentProfile)
	profile.PUT("", handler.UpdateCurrentProfile)
	profile.PUT("/security/password", handler.UpdatePassword)
	profile.PUT("/security/email", handler.UpdateEmail)
	profile.PUT("/security/phone", handler.UpdatePhone)

	appUsers := router.Group("/api/app/v1/users")
	appUsers.GET("/me", handler.AppMe)

	appProfile := router.Group("/api/app/v1/profile")
	appProfile.GET("", handler.AppProfile)
	appProfile.PUT("", handler.AppUpdateProfile)
}
```

- [ ] **Step 3: gofmt**

Run:

```powershell
cd E:\admin_go\admin_back_go
gofmt -w internal\architecture\compat_route_naming_test.go internal\module\auth\route.go internal\module\user\route.go
```

Expected: command exits 0 and prints no output.

- [ ] **Step 4: 运行 targeted tests 确认 GREEN**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture ./internal/module/auth ./internal/module/user ./internal/server -count=1
```

Expected:

```text
ok  	admin_back_go/internal/architecture
ok  	admin_back_go/internal/module/auth
ok  	admin_back_go/internal/module/user
ok  	admin_back_go/internal/server
```

- [ ] **Step 5: 检查行为没有变化**

Run:

```powershell
cd E:\admin_go\admin_back_go
git diff -- internal\module\auth\route.go internal\module\user\route.go
```

Expected: diff 只包含变量名变化，不包含 URL 字符串变化，不包含 handler 绑定变化。

- [ ] **Step 6: 提交本 task**

```powershell
cd E:\admin_go
git add admin_back_go\internal\architecture\compat_route_naming_test.go admin_back_go\internal\module\auth\route.go admin_back_go\internal\module\user\route.go
git commit -m "refactor: clarify compat route naming"
```

---

## Task 3: 收口 backend 架构文档里的 compat/legacy 语义

**Files:**

- Modify: `docs/architecture/04-go-backend-framework.md`
- Modify: `docs/architecture/05-development-quality-rules.md`
- Modify: `admin_back_go/internal/module/README.md`

- [ ] **Step 1: 修改 `docs/architecture/04-go-backend-framework.md` 的旧接口章节**

把 `## 旧接口与新接口` 章节替换为：

```markdown
## 兼容入口与新接口

为了不破坏仍未完全收口的调用，允许存在边界明确的 compatibility adapter：

```text
/api/Users/init
/api/Users/login
/api/admin/Permission/list
```

这里的当前职责叫 `compat adapter`。`legacy` 只能描述历史来源，例如“这个 URL 来源于旧 PHP 系统”，不能作为 active code 的变量名、包名或长期架构区域。

兼容入口不能污染新模块内部。做法是：

```text
compat route adapter -> module handler/service -> repository
```

新接口另走：

```text
/api/{scope}/v1/...
当前 admin = /api/admin/v1/...
当前 app   = /api/app/v1/...
```

旧接口兼容层不是新世界规则。新增接口不得继续发明 `/api/admin/Xxx/list`、`/add`、`/edit`、`/del` 这类 action path。

active Go code 命名规则：

```text
adminAuth        # /api/admin/v1/auth
appAuth          # /api/app/v1/auth
usersAuthCompat  # /api/Users 下兼容 auth 行为
usersCompat      # /api/Users 下兼容 user 行为
```

禁止：

```text
legacy := router.Group(...)
legacy2 := router.Group(...)
old := router.Group(...)
internal/module/legacyauth
internal/module/appauth
```
```

- [ ] **Step 2: 修改 `docs/architecture/05-development-quality-rules.md` 的兼容规则**

将允许项里的：

```text
显式 legacy adapter，例如 /api/Users/init -> service -> repository
```

替换为：

```text
显式 compat adapter，例如 /api/Users/init -> handler/service -> repository；legacy 只描述历史来源
```

将 RESTful API 规则里的：

```text
旧 action POST 接口只能作为 legacy mapping 文档或显式 adapter，不能污染新 REST 设计。
```

替换为：

```text
旧 action POST 接口只能作为 legacy provenance 文档或显式 compat adapter，不能污染新 REST 设计。
```

在这句话后面追加：

```markdown
active code 不准用裸 `legacy` 表示当前职责。兼容旧 URL、旧字段、旧响应时，变量/文件/测试名使用 `compat`；文档可以用 `legacy` 说明历史来源。
```

- [ ] **Step 3: 修改 `admin_back_go/internal/module/README.md` 的模块文件规则**

把 `## 模块文件规则` 到 `## 每层职责` 之前的内容替换为：

```markdown
## 模块文件规则

module 是 capability boundary，不是平台、旧接口、供应商品牌或运行方式。

一个模块最多包含：

```text
route.go
handler.go
request.go
service.go
repository.go
model.go
dto.go
errors.go
```

“最多”不是“必须”。少一层是一层：

```text
没有 DB 就不要 repository.go
没有表就不要 model.go
没有复杂响应差异就不要 presenter.go
没有平台差异就不要 platform_handler.go
没有旧入口兼容就不要 compat_route.go
```

禁止因为这些原因新增 module：

```text
只是 URL prefix 不同
只是 admin/app 平台不同
只是兼容旧接口
只是 provider 品牌不同
只是队列优先级不同
```
```

- [ ] **Step 4: 文档自查**

Run:

```powershell
cd E:\admin_go
rg -n "legacy := router.Group|legacy2|internal/module/appauth|平台不是 module|compat adapter" docs\architecture admin_back_go\internal\module\README.md
```

Expected:

```text
compat adapter 至少在 04/05 文档中出现
平台不是 module 规则仍然存在
legacy := router.Group 不在 docs 的推荐代码块中出现
```

- [ ] **Step 5: 提交本 task**

```powershell
cd E:\admin_go
git add docs\architecture\04-go-backend-framework.md docs\architecture\05-development-quality-rules.md admin_back_go\internal\module\README.md
git commit -m "docs: define compat route and module boundaries"
```

---

## Task 4: 最终验证门禁

**Files:**

- Validate only; no file changes expected.

- [ ] **Step 1: 查看工作区，确认没有误碰无关文件**

Run:

```powershell
cd E:\admin_go
git status --short
```

Expected: 只看到本计划相关文件，或工作区干净；如果还有用户先前未提交文件，不要擅自修改或删除。

- [ ] **Step 2: backend targeted tests**

Run:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/architecture ./internal/module/auth ./internal/module/user ./internal/server -count=1
```

Expected: all packages `ok`。

- [ ] **Step 3: whitespace diff check**

Run:

```powershell
cd E:\admin_go
git diff --check
```

Expected: no output, exit code 0。

- [ ] **Step 4: governance check**

Run:

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: exit code 0；如输出 warning，按 warning 指向的文档或路径修正后重跑。

- [ ] **Step 5: 最终 diff 人工确认**

Run:

```powershell
cd E:\admin_go
git diff --stat
git diff -- admin_back_go\internal\module\auth\route.go admin_back_go\internal\module\user\route.go
```

Expected:

```text
route.go diff 只包含变量名变化
/api/admin/v1/auth 不变
/api/Users 不变
/api/admin/v1/users 不变
/api/app/v1/users 不变
/api/app/v1/profile 不变
```

---

## Self-review checklist

- [ ] Spec 覆盖：本 plan 覆盖命名、文档、架构守卫、module 文件分层口径。
- [ ] 未删除任何兼容 URL。
- [ ] 未改 handler/service/repository/model。
- [ ] TDD 顺序明确：先 RED 架构测试，再最小改名 GREEN。
- [ ] 文档只把 active code 职责改成 compat，没有禁止文档继续用 legacy 表示历史来源。
- [ ] 验证命令包含 `git diff --check` 和 governance check。

## 执行建议

推荐用 subagent-driven 执行：

```text
Task 1 + Task 2 一个实现 subagent
Task 3 一个文档 subagent
Task 4 当前主 agent 验证
```

如果 inline 执行，也必须严格按 RED -> GREEN -> docs -> gates 的顺序，不要一上来批量改文档和代码。
