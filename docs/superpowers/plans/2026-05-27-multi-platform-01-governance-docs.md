# Plan 01: Multi-platform Governance Docs

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write the multi-platform architecture rules (R1-R8), the `platform / module / transport / shared / infra` vocabulary, and the "capability is not platform-bound" principle into root governance docs. This plan touches **zero Go code**. It can run in parallel with `plan-02-auth-transport.md` and `plan-04-frontend-legacy-cleanup.md`.

**Source spec:** `docs/superpowers/specs/2026-05-27-multi-platform-backend-boundary-design.md` §3.2 (R1-R8) + §0.4 (infra vs adapter) + §1.3 (反目标).

**Tech Stack:** Markdown, `rg`, `scripts/check-agent-governance.ps1`.

---

## Scope Check

This plan executes:

```text
1. Create docs/architecture/00-platform-and-module-rules.md with R1-R8.
2. Update docs/architecture/04-go-backend-framework.md to drop api/domain/shared/platform 4-layer target and adopt module/transport/shared/infra.
3. Update docs/architecture/05-development-quality-rules.md multi-platform decision table.
4. Update AGENTS.md vocabulary (platform / transport / shared / infra).
5. Update docs/status/current-status.md to record the architecture pivot without claiming code work is done.
6. Update admin_back_go/docs/architecture.md to remove legacy/compat sections.
```

This plan does **not** touch any `.go` file. It does **not** claim that auth transport or module consolidation is done.

**Parallel siblings:** `plan-02-auth-transport.md`, `plan-04-frontend-legacy-cleanup.md`.
**Blocks:** none.

---

## File Structure

- Create: `docs/architecture/00-platform-and-module-rules.md`
- Modify: `AGENTS.md`
- Modify: `docs/architecture/04-go-backend-framework.md`
- Modify: `docs/architecture/05-development-quality-rules.md`
- Modify: `docs/status/current-status.md`
- Modify: `admin_back_go/docs/architecture.md`

---

## Task 1: Create R1-R8 governance doc

**Files:**

- Create: `docs/architecture/00-platform-and-module-rules.md`

- [ ] **Step 1: Write the R1-R8 rules verbatim from spec §3.2**

Create `docs/architecture/00-platform-and-module-rules.md` with content:

```markdown
# 多平台架构硬规则（R1-R8）

源 spec：`docs/superpowers/specs/2026-05-27-multi-platform-backend-boundary-design.md`

本文件是项目级硬规则。违反任一条视为架构缺陷，PR 不予合并。

## 词汇

- **platform**：业务平台，仅指 admin / app / openapi / merchant / miniapp 等业务入口
- **module**：业务能力，位于 `internal/module/{capability}/`
- **transport**：能力对某平台的 HTTP 表面，位于 `internal/module/{capability}/transport/{platform}/`
- **shared**：跨能力公共服务，位于 `internal/shared/`（dict / enum / validate / i18n / response / apperror / pagination / setting）
- **infra**：运行时技术资源层，位于 `internal/infra/`（DB / Redis / Queue / SDK / Logging）
- **adapter**：infra 内多供应商实现的角色名（如 `infra/payment/alipay`），不是层名

## R1. capability 命名

一个业务能力 = 一个 `internal/module/{capability}/` 目录。
capability 名只描述能力本身，永不带平台前缀。
小写下划线、单数。

## R2. 路由位置

所有对外 HTTP 路由必须位于 `internal/module/{capability}/transport/{platform}/`。
禁止 module 根目录直接出现 `route.go` / `handler.go`。
禁止"裸 transport"（`transport/route.go` 没有 platform 子目录）。
禁止同包内用 `platform_*.go` / `app_*.go` 文件前缀代替目录分层。

## R3. capability 不绑定平台

即使某能力当前只暴露一个平台入口，也必须显式放在 `transport/{platform}/` 下。
当前只有 admin 入口 **不等于** admin-only；这只是当前先实现的暴露面。

## R4. 新增平台

新增平台 = 在每个相关 module 加 `transport/{new_platform}/` + bootstrap 加一行 Register 调用。
禁止为新平台新建 `module/{platform}{capability}/`。

## R5. service 跨平台

service / repository 不依赖 `gin.Context`。
平台信息通过显式 `Platform` 入参传入 service。
service 持有的状态不区分平台。

## R6. dict 边界

模块不直接读 `internal/enum` 拼 option 数组。
模块在 bootstrap 时向 `shared/dict.Service` 注册自己的 provider。
page-init 一律通过 `dict.PageInit(ctx, names...)` 组装。

## R7. setting 边界

模块不直接读 `system_settings` 表。
通过 `shared/setting` 边界读取，强类型 key，含默认值与缓存。

## R8. 无 legacy 框架概念

项目无 legacy / compat / fallback 框架性概念。
旧 `/api/Users/*` 类 POST 路由直接删除，前端跟着改。
architecture.md 不再保留 "legacy adapter" "fallback bridge" 等段落。

## infra vs adapter 命名协议

- `infra/` 是层名，描述事实（运行时技术资源）
- `adapter` 是 infra 内某些实现的角色名，仅用于多供应商场景

例：
```text
infra/database          GORM wrapper（不是 adapter）
infra/redis             Redis client（不是 adapter）
infra/payment/alipay    Alipay adapter（多供应商，是 adapter 角色）
infra/storage/cos       COS adapter（同上）
```

详见 spec §0.4 与 §8。
```

- [ ] **Step 2: Verify the new file**

```powershell
cd E:\admin_go
Test-Path .\docs\architecture\00-platform-and-module-rules.md
rg -n "R1\.|R2\.|R3\.|R8\.|infra vs adapter" docs\architecture\00-platform-and-module-rules.md
```

Expected: `True` + 5 matches.

---

## Task 2: Update AGENTS.md vocabulary

**Files:**

- Modify: `AGENTS.md`

- [ ] **Step 1: Locate the architecture vocabulary section in AGENTS.md**

```powershell
cd E:\admin_go
rg -n "platform|infra|adapter|module|transport" AGENTS.md
```

- [ ] **Step 2: Ensure AGENTS.md contains the canonical vocabulary block**

The block (insert or rewrite the existing one):

```markdown
## 架构词汇（与 docs/architecture/00-platform-and-module-rules.md 对齐）

- `platform` 仅指业务平台：admin / app / openapi / merchant / miniapp
- `module` 业务能力归属：`internal/module/{capability}/`
- `transport` 能力对某平台的 HTTP 表面：`internal/module/{capability}/transport/{platform}/`
- `shared` 跨领域公共服务：dict / enum / validate / i18n / response / apperror / pagination / setting
- `infra` 运行时技术资源层：DB / Redis / Queue / Storage / SDK / Logging
- `adapter` infra 内多供应商实现的角色名，不是层名

不再使用：
- `internal/platform/` 作为外部资源目录名（与业务 platform 撞车，迁至 `internal/infra/`）
- `api/{platform}/` 顶层分包（弃用 DDD 风格四层）
- "admin only" 作为能力定义（当前 admin 入口 ≠ admin-only）
```

- [ ] **Step 3: Verify**

```powershell
cd E:\admin_go
rg -n "infra 运行时技术资源|adapter infra 内多供应商" AGENTS.md
rg -n "internal/platform/|api/\{platform\}/" AGENTS.md
```

Expected: first command matches; second command — if any matches, ensure they appear only in the "不再使用" deprecation block, not in active rules.

---

## Task 3: Rewrite `docs/architecture/04-go-backend-framework.md` target line

**Files:**

- Modify: `docs/architecture/04-go-backend-framework.md`

- [ ] **Step 1: Replace the conclusion target**

Find the line near the top:

```text
cmd -> bootstrap -> api -> domain -> shared -> platform
```

Replace with:

```text
cmd -> bootstrap -> server -> module/{capability}/transport/{platform} -> module service -> shared / infra
```

- [ ] **Step 2: Remove or rewrite the long-term layered target section**

Search for and rewrite the section that describes `internal/api/admin/`, `internal/domain/user/`, etc. as the long-term target. The new section should say:

```markdown
## 长期目标分层

```text
internal/module/{capability}/                     业务能力归属（auth/user/payment/ai/...）
internal/module/{capability}/transport/{platform}/  能力对某平台的 HTTP 表面
internal/shared/                                  跨能力公共服务
internal/infra/                                   运行时技术资源层（原 internal/platform/）
```

不采用 `internal/api/{admin,app,...}` + `internal/domain/{capability}/` 的 4 层切分。
理由：service 已经天然跨平台（入参带 platform），抽 domain 是空抽象；
跨平台字段改动高频的项目，HTTP 与业务分大目录会让日常修改成本变高。
```

- [ ] **Step 3: Remove "禁止" block that lists adminauth / appauth and replace with R-rule reference**

Replace the existing "禁止" enumeration with:

```markdown
## 多平台规则

参见 `docs/architecture/00-platform-and-module-rules.md`（R1-R8）。
```

- [ ] **Step 4: Verify**

```powershell
cd E:\admin_go
rg -n "api -> domain|internal/api/\{admin|internal/domain/" docs\architecture\04-go-backend-framework.md
rg -n "transport/\{platform\}|internal/infra|00-platform-and-module-rules" docs\architecture\04-go-backend-framework.md
```

Expected: first command no matches; second command at least 2 matches.

---

## Task 4: Update `05-development-quality-rules.md` decision table

**Files:**

- Modify: `docs/architecture/05-development-quality-rules.md`

- [ ] **Step 1: Find and rewrite the multi-platform decision table**

Locate the section that decides "what kind of difference goes where" and rewrite as:

```text
| 差异类型 | 落位 |
|---|---|
| route prefix 不同 | transport/{platform} 的 route.go |
| 请求字段不同 | transport/{platform} 的 request.go |
| 返回字段不同 | transport/{platform} 的 presenter.go |
| 认证/会话策略不同 | auth 模块策略 + auth_platforms 表 |
| 业务规则不同 | module service 显式 policy/input |
| 跨领域公共数据 | shared/dict 或 shared/setting |
| 外部 SDK/技术资源差异 | infra |
```

- [ ] **Step 2: Verify**

```powershell
cd E:\admin_go
rg -n "transport/\{platform\}|外部 SDK/技术资源差异" docs\architecture\05-development-quality-rules.md
```

Expected: at least 2 matches.

---

## Task 5: Update `docs/status/current-status.md` honestly

**Files:**

- Modify: `docs/status/current-status.md`

- [ ] **Step 1: Add architecture pivot entry**

Append (do not overwrite) a dated entry:

```markdown
## 2026-05-27 架构方向更新

- 多平台后端架构原则 R1-R8 落地为 `docs/architecture/00-platform-and-module-rules.md`
- `platform` 词汇收紧：仅指业务平台 admin / app / openapi / merchant
- 技术资源目录从 `internal/platform/` 改名为 `internal/infra/`（迁移由独立 plan 执行）
- 顶层目标分层从 `api/domain/shared/platform` 四层改为 `module/{capability}/transport/{platform}` + shared + infra
- `internal/module/` 当前 36 个 module 将聚合至约 19 个（含新增 profile）
- 上述变化按多刀迁移路线执行；本次 doc 更新不代表代码已完成

参见：
- spec：`docs/superpowers/specs/2026-05-27-multi-platform-backend-boundary-design.md`
- plans：`docs/superpowers/plans/2026-05-27-multi-platform-{01..04}-*.md`
```

- [ ] **Step 2: Verify**

```powershell
cd E:\admin_go
rg -n "2026-05-27 架构方向更新|内 36 个 module 将聚合至约 19 个" docs\status\current-status.md
```

Expected: 1-2 matches.

---

## Task 6: Clean `admin_back_go/docs/architecture.md` legacy sections

**Files:**

- Modify: `admin_back_go/docs/architecture.md`

- [ ] **Step 1: Find legacy / compat / fallback sections**

```powershell
cd E:\admin_go\admin_back_go
rg -n "legacy adapter|compat adapter|fallback bridge|legacy POST|/api/Users" docs\architecture.md
```

- [ ] **Step 2: Delete those sections (do not rewrite or wrap them in markers)**

Per spec §1.3, no legacy/compat sections survive. Delete the section content. If a section is purely about legacy, delete the section header too. Do not leave "TODO: deprecated" stubs.

- [ ] **Step 3: Verify clean**

```powershell
cd E:\admin_go\admin_back_go
rg -n "legacy adapter|compat adapter|fallback bridge" docs\architecture.md
```

Expected: no matches.

---

## Task 7: Final governance verification

**Files:**

- Validate only.

- [ ] **Step 1: Cross-doc consistency**

```powershell
cd E:\admin_go
rg -n "internal/adapter/" AGENTS.md docs admin_back_go\docs
rg -n "api/domain/shared/platform" AGENTS.md docs admin_back_go\docs
```

Expected: both commands no matches. (`internal/adapter/` is now `internal/infra/` per spec §0.4; 4-layer target is dropped.)

- [ ] **Step 2: Required wording exists**

```powershell
cd E:\admin_go
rg -n "module/\{capability\}/transport/\{platform\}|internal/infra/" AGENTS.md docs\architecture
rg -n "R1\.|R2\.|R8\." docs\architecture\00-platform-and-module-rules.md
```

Expected: first command matches in multiple files; second command matches at least 3 rules.

- [ ] **Step 3: Run governance gate**

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected: `git diff --check` exits 0; governance checker passes.

- [ ] **Step 4: Final handoff text**

Use exactly:

```text
Completed in plan-01: R1-R8 governance docs, AGENTS.md vocabulary, architecture 04/05 multi-platform sections, current-status pivot entry, admin_back_go architecture legacy purge.
Not executed in plan-01: any .go code change. See plan-02 (auth transport), plan-03 (module merge), plan-04 (frontend legacy cleanup).
```

---

## Plan self-review

- Source: spec §3.2 R1-R8, §0.4 infra/adapter, §1.3 反目标.
- Scope discipline: zero `.go` files touched. Build can never break from this plan.
- Parallelism: can run alongside plan-02 and plan-04 without file conflict.
- Idempotency: re-running the rg verifications is safe.
- Honesty: status doc explicitly marks code work as not done in this plan.
