# Agent Framework Governance Design

日期：2026-05-15  
状态：draft for review  
范围：`E:\admin_go` 总控仓库的 agent 框架、冷启动文档、文档真相源、验证矩阵、pre-push 轻量 gate 设计。本文只定义治理骨架，不修改 Go/Vue 业务 runtime。

## 1. 结论

应该先维护 agent 框架。

这不是为了搞仪式感，也不是为了造一个“大而全 AI 平台”。这个项目已经进入 Go/Vue active runtime 阶段，后端、前端、合同、smoke、部署和历史 spec/plan 同时存在；如果没有一个可执行的治理骨架，后续每个模块都会重复出现同一类烂问题：

```text
代码改了，contract 没改
contract 改了，current-status 没改
文档写了 implemented，但没有验证证据
后端改了接口，前端靠猜字段适配
前端改了页面，RBAC/menu/smoke 没同步
旧 plan/spec 被误当成当前事实源
push 前不知道该跑哪组检查
```

第一版 agent framework governance 要做的是：

```text
冷启动入口
agent 角色边界
文档真相源分层
改动类型 -> 文档同步矩阵
改动类型 -> 验证命令矩阵
轻量 pre-push gate
交付报告模板
历史 spec/plan 归档规则
多仓库状态提示
```

不做：

```text
不做 AI agent runtime
不做任务编排平台
不做自动改文档机器人
不做全量 CI 替代品
不在 pre-push 默认跑 full smoke
不碰 admin_back_go / admin_front_ts 的业务 runtime
```

一句话：**把项目规则变成可读、可执行、可检查的最小治理层。**

## 2. Linus 三问

### 2.1 这是真问题吗？

是。

当前项目已经不是空仓，也不是 PHP 迁移尾巴。它有：

```text
root meta repo
admin_back_go 独立 Go 后端仓库
admin_front_ts 独立 Vue 前端仓库
docs/status/current-status.md 当前事实源
docs/contracts/*.md API / realtime contract
docs/testing/*.md smoke / test matrix
docs/superpowers/specs/*.md 新功能设计
docs/superpowers/plans/*.md 实施计划
agents/*.md 项目 agent 分工
```

这种结构如果只靠“记得更新文档”，必然漂。

### 2.2 有更简单的方法吗？

有。

不要造平台，不要造复杂 workflow engine。第一版只做三件事：

```text
1. 统一文档入口和事实源
2. 明确 agent 角色和交付物
3. 写一个轻量 check 脚本，后续再挂 pre-push hook
```

脚本只做提醒和阻断明显坏味道，不自动修复、不猜业务含义。

### 2.3 会破坏什么吗？

第一版不能破坏任何业务 runtime。

不能碰：

```text
admin_back_go runtime behavior
admin_front_ts runtime behavior
数据库 schema
菜单和 RBAC
API contract 内容本身
现有 smoke 脚本语义
当前未完成业务分支的脏改动
```

允许新增或调整：

```text
root docs/architecture 文档
root docs/testing 文档
root scripts/check-agent-governance.ps1
root scripts/install-git-hooks.ps1
root .githooks/pre-push
agents/*.md 的职责说明
docs/README.md 的冷启动索引
```

所有检查默认只读。hook 不应该改文件。

## 3. 当前事实源

现有规则已经有基础，但还没有形成可执行闭环。

### 3.1 已有基础

`AGENTS.md` 已经定义：

```text
Phase 0: Agent framework and rules
代码质量、架构质量、文档真实性优先
Agent 分工优先于“全能 AI”
默认必读文档
```

`docs/README.md` 已经定义：

```text
Codex 冷启动入口
冷启动阅读顺序
文档与运行时冲突时的优先级
常用验证命令
结束任务时必须更新的文档
```

`docs/architecture/02-agent-framework.md` 已经定义：

```text
Superpowers = 怎么推进任务
agents/ = 谁负责什么、不能做什么、必须产出什么
docs/superpowers = spec/plan 总入口
禁止全能 agent
```

`docs/architecture/05-development-quality-rules.md` 已经定义：

```text
禁止兜底字段
RESTful API 规则
TypeScript 规则
Go 后端规则
Queue / Scheduler 规则
```

### 3.2 当前缺口

现在缺的是执行层：

```text
1. 没有一张改动类型到文档同步的矩阵。
2. 没有一张改动类型到验证命令的矩阵。
3. 没有 pre-push 轻量 gate 的边界。
4. 没有 hook 安装和跳过规则。
5. 没有多仓库状态检查规则。
6. 没有 spec/plan 命名和归档检查。
7. agent 输出模板存在，但没有被 check 脚本提醒。
```

这就是第一版要补的东西。

## 4. 设计目标

### 4.1 必须做到

```text
1. 新 agent 进仓库后，5 分钟内能判断项目当前事实源。
2. 任意模块改动前，能知道自己属于哪个 agent 角色。
3. 任意 runtime 改动后，能知道必须同步哪些 docs。
4. 任意 push 前，能跑一个轻量检查发现明显遗漏。
5. 检查失败时，错误信息必须告诉人该补哪个文档或跑哪个命令。
6. root / backend / frontend 多仓库状态必须被明确提示。
7. 历史 spec/plan 不能覆盖 current-status。
```

### 4.2 必须避免

```text
1. 不能把 pre-push 做成 CI 全量替代品。
2. 不能默认跑 full smoke，太慢会逼人绕过。
3. 不能让 hook 自动改文档，自动修复会制造假事实。
4. 不能为了“框架完整”新增无用 agent 角色。
5. 不能把 planned 写成 implemented。
6. 不能让脚本依赖数据库、Redis、后端服务必须在线。
7. 不能把业务模块规则塞进 agent framework，业务规则归对应 spec/contract。
```

## 5. 文档架构

### 5.1 文档分层

第一版文档架构固定如下：

```text
docs/README.md
  冷启动入口，只放导航和总规则，不放模块细节。

docs/status/current-status.md
  当前 Go/Vue runtime 事实源。只记录 verified implemented / partially implemented / planned。

docs/architecture/*.md
  架构规则、agent framework、技术取舍、质量规则、治理规则。

docs/contracts/*.md
  REST / realtime / response / endpoint / DTO contract。

docs/testing/*.md
  test strategy、smoke matrix、pre-push gates、验证命令选择。

docs/deployment/*.md
  本地、生产、分布式 readiness、运行边界。

docs/superpowers/specs/*.md
  新功能设计。状态可以是 draft / approved / implemented，但不能覆盖 current-status。

docs/superpowers/plans/*.md
  实施计划。只描述怎么做，不替代 contract。

docs/superpowers/archive/**
  历史归档。只在考古时读取，不作为当前事实源。

agents/*.md
  项目 agent 角色职责、允许范围、禁止事项、输出格式。
```

### 5.2 真相源优先级

文档冲突时按这个顺序：

```text
1. live runtime behavior
2. smoke / tests output
3. served API / WebSocket behavior
4. process config / route registration / migration state
5. docs/status/current-status.md
6. docs/contracts/*.md
7. docs/architecture/*.md
8. docs/superpowers/specs/*.md
9. docs/superpowers/plans/*.md
10. comments / stale historical docs
```

`current-status.md` 是文档层最高事实源，但不能压过 runtime。

### 5.3 文档状态口径

固定三类：

```text
implemented
  有代码、合同、验证证据。

partially implemented
  有骨架或部分链路，必须写清缺口。

planned
  只有设计或计划。不能在汇报里说成完成。
```

禁止使用模糊状态：

```text
basically done
almost finished
should work
ready maybe
大概完成
基本完成
```

## 6. Agent 角色模型

### 6.1 当前保留角色

第一版不新增角色，先收紧现有角色。

```text
architect
  负责开源调研、架构取舍、阶段边界。

api-contract
  负责 REST/realtime contract、DTO、错误场景、legacy mapping。

backend-worker
  负责 Go 后端实现和后端测试。

frontend-adapter
  负责 Vue 前端 API 适配、页面接线、前端验证。

reviewer
  负责越界、坏味道、验证缺失、文档漂移检查。
```

### 6.2 主角色规则

每个任务只能有一个主角色。

跨领域任务不等于一个 agent 全包。正确顺序是：

```text
architect 定边界
api-contract 定接口
backend-worker 实现后端
frontend-adapter 适配前端
reviewer 收口检查
```

如果用户要求“一次做完”，也必须在内部保持这个顺序，不能让 backend-worker 自己发明接口。

### 6.3 角色进入条件

```text
architect
  可以在需求模糊、范围不清、涉及新模块/新依赖/新架构时进入。

api-contract
  必须在任何新 endpoint、DTO、WebSocket event、分页/状态枚举变化前进入。

backend-worker
  只能在 contract 或现有 runtime 事实清楚后进入。

frontend-adapter
  只能在 API contract 或 backend shape 清楚后进入。

reviewer
  在提交前、push 前、或者用户要求质量审查时进入。
```

### 6.4 角色输出

所有 agent 输出必须包含：

```text
Outcome
Changed files
Key evidence
Verification
Known risks
Next step
```

不同角色加自己的专用输出：

```text
architect:
  research source
  adopted / rejected options
  stage boundary

api-contract:
  endpoint list
  request schema
  response schema
  error cases
  frontend impact

backend-worker:
  handler/service/repository/model boundary
  test result
  contract sync

frontend-adapter:
  affected pages
  API client impact
  typecheck/lint/test result

reviewer:
  blocking issues
  non-blocking issues
  required fix
```

## 7. 改动类型到文档同步矩阵

这是 governance 的核心。

### 7.1 后端 API 改动

触发条件：

```text
admin_back_go/internal/server
admin_back_go/internal/module/**/route.go
admin_back_go/internal/module/**/handler*.go
admin_back_go/internal/module/**/request*.go
admin_back_go/internal/module/**/dto*.go
admin_back_go/internal/module/**/response*.go
```

必须检查：

```text
docs/contracts/admin-api-v1.md
docs/status/current-status.md
docs/testing/smoke-matrix.md
admin_back_go/docs/architecture.md
```

如果没有修改这些文档，提交说明或 agent 报告必须解释为什么不需要。

### 7.2 Realtime / WebSocket 改动

触发条件：

```text
admin_back_go/internal/platform/realtime/**
admin_back_go/internal/module/realtime/**
admin_front_ts/src/**/realtime*
admin_front_ts/src/hooks/useWebSocket.ts
WebSocket event envelope / topic / auth / origin policy
```

必须检查：

```text
docs/contracts/admin-realtime-v1.md
docs/contracts/admin-api-v1.md
docs/status/current-status.md
docs/testing/smoke-matrix.md
admin_back_go/docs/architecture.md
```

### 7.3 DB / migration 改动

触发条件：

```text
admin_back_go/database/migrations/**
admin_back_go/internal/module/**/model*.go
admin.sql
```

必须检查：

```text
docs/status/current-status.md
docs/contracts/admin-api-v1.md
docs/testing/smoke-matrix.md
admin_back_go/docs/architecture.md
```

如果是新模块，还必须有：

```text
docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md
docs/superpowers/plans/YYYY-MM-DD-<topic>.md
```

### 7.4 前端 API / 页面改动

触发条件：

```text
admin_front_ts/src/api/**
admin_front_ts/src/views/**
admin_front_ts/src/router/**
admin_front_ts/src/stores/**
```

必须检查：

```text
docs/contracts/admin-api-v1.md
docs/status/current-status.md
docs/testing/smoke-matrix.md
```

如果涉及 realtime，再加：

```text
docs/contracts/admin-realtime-v1.md
```

### 7.5 权限 / 菜单 / 路由改动

触发条件：

```text
route_meta.go
permission seed
menu path
component / view_key
button code
frontend route path
```

必须检查：

```text
docs/contracts/admin-api-v1.md
docs/status/current-status.md
docs/testing/smoke-matrix.md
```

报告中必须明确：

```text
path
component
permission code
button code
是否需要清 RBAC cache
```

### 7.6 异步任务 / cron / queue 改动

触发条件：

```text
admin_back_go/internal/jobs/**
admin_back_go/internal/platform/taskqueue/**
admin_back_go/internal/platform/scheduler/**
cron task registry
Asynq task type
```

必须检查：

```text
docs/contracts/admin-api-v1.md
docs/status/current-status.md
docs/testing/smoke-matrix.md
admin_back_go/docs/architecture.md
docs/deployment/local.md
docs/deployment/production.md
```

报告中必须说明：

```text
task type
queue name
retry / timeout
idempotency
worker requirement
smoke 是否只读
```

### 7.7 配置 / 环境变量改动

触发条件：

```text
config struct
.env.example
deployment docs
APP_SECRET / Redis / DB / COS / AI / payment / realtime config
```

必须检查：

```text
docs/deployment/local.md
docs/deployment/production.md
docs/deployment/distributed-readiness.md
docs/status/current-status.md
admin_back_go/docs/architecture.md
```

### 7.8 纯文档改动

触发条件：

```text
docs/**
agents/**
AGENTS.md
```

必须检查：

```text
是否把 planned 写成 implemented
是否覆盖 current-status
是否引用了 stale historical plan
是否使用了正确路径格式
是否和 docs/README.md 的入口关系一致
```

## 8. 验证矩阵

### 8.1 轻量默认检查

这些适合 pre-push 默认跑：

```powershell
git diff --check
scripts/check-agent-governance.ps1
```

如果后端仓库有改动，提示但不默认强制跑：

```powershell
cd E:\admin_go\admin_back_go
$env:GOMAXPROCS='2'
go test -p=1 ./...
go vet -p=1 ./...
powershell -ExecutionPolicy Bypass -File .\scripts\check-contract.ps1
```

如果前端仓库有改动，提示但不默认强制跑：

```powershell
cd E:\admin_go\admin_front_ts
$env:NODE_OPTIONS='--max-old-space-size=2048'
npx vue-tsc -b --pretty false
npx eslint <touched-files>
npx vitest run <target-test>
```

### 8.2 发布前或模块完成检查

这些不放进默认 pre-push：

```powershell
admin_back_go/scripts/basic-admin-smoke.ps1
admin_back_go/scripts/full-admin-smoke.ps1
frontend full build
真实 provider / COS / payment / mail / SMS 手动 smoke
```

原因很简单：默认 pre-push 太慢，开发者会绕过。重检查必须作为完成模块或发布前 gate。

### 8.3 验证结果写法

最终报告不能写：

```text
测试应该能过
没时间跑
看起来没问题
```

必须写：

```text
command
working directory
result
失败原因或跳过原因
```

跳过允许，但必须说清：

```text
skipped because no runtime code changed
skipped because service credentials unavailable
skipped because unrelated dirty workspace
```

## 9. Pre-push gate 设计

### 9.1 第一版边界

第一版 pre-push 只做轻量检查：

```text
1. git diff --check
2. 检查 spec/plan 文件命名
3. 检查 docs/superpowers 归属
4. 检查 current-status 中 planned/implemented 高危词
5. 检查 touched runtime 文件是否需要 docs sync
6. 检查 root/backend/frontend 仓库脏状态
7. 输出建议验证命令
```

它不做：

```text
不自动改文件
不连接 DB
不连接 Redis
不启动后端
不跑 full smoke
不跑 frontend build
不扫描 node_modules
不读取用户个人目录
```

### 9.2 脚本入口

建议新增：

```text
scripts/check-agent-governance.ps1
```

参数：

```powershell
-Mode staged|working|range
  staged: 检查 staged diff，适合 pre-commit
  working: 检查 working tree，适合手动
  range: 检查 upstream..HEAD，适合 pre-push

-Base <ref>
  range 模式的 base ref，默认 origin/<current-branch>

-Strict
  严格模式。模块完成或发布前使用。
```

第一版可以只实现：

```powershell
scripts/check-agent-governance.ps1 -Mode working
scripts/check-agent-governance.ps1 -Mode range
```

### 9.3 Hook 安装

建议新增：

```text
scripts/install-git-hooks.ps1
.githooks/pre-push
```

安装逻辑：

```powershell
git config core.hooksPath .githooks
```

不默认写入子仓库 hook。子仓库 hook 第二阶段再做，避免一次改太多。

### 9.4 Hook 跳过规则

允许显式跳过，但要让人知道自己在绕过：

```powershell
$env:SKIP_AGENT_GOVERNANCE_CHECK='1'
git push
```

hook 输出必须包含：

```text
SKIP_AGENT_GOVERNANCE_CHECK is set; governance check skipped by user.
```

不能隐藏跳过。

### 9.5 错误分级

Blocking：

```text
docs/superpowers spec/plan 放错仓库
spec/plan 命名不符合 YYYY-MM-DD-<topic>
current-status 新增明显 planned/implemented 矛盾词
runtime API 改动但完全没有 contract/current-status/smoke 触碰，也没有 ignore 说明
git diff --check 失败
```

Warning：

```text
后端改动但没有检测到 go test 证据
前端改动但没有检测到 vue-tsc/lint 证据
root/subrepo 有 unrelated dirty files
新增 migration 但 admin.sql 未同步或未说明
```

Info：

```text
建议运行的命令
受影响的文档
当前 agent 角色建议
```

## 10. 多仓库治理

### 10.1 仓库事实

`E:\admin_go` 是总控 meta repo。真实业务仓库是：

```text
admin_back_go
admin_front_ts
```

第一版 governance check 必须输出三段状态：

```text
root repo status
admin_back_go repo status
admin_front_ts repo status
```

### 10.2 提交策略

不要把三个仓库混成一个假原子提交。

推荐顺序：

```text
1. backend runtime commit
2. frontend runtime commit
3. root docs / contract / smoke matrix commit
```

如果一个任务只改 root governance 文档，就只提交 root。

### 10.3 脏工作区处理

脚本不应该因为 unrelated dirty files 就盲目失败。

规则：

```text
当前任务相关文件脏：必须处理或说明。
其他 agent / 用户留下的脏文件：warning，不自动回滚、不自动格式化、不自动 stage。
```

## 11. Spec / Plan 规则

### 11.1 命名

固定格式：

```text
docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md
docs/superpowers/plans/YYYY-MM-DD-<topic>.md
```

示例：

```text
docs/superpowers/specs/2026-05-15-agent-framework-governance-design.md
docs/superpowers/plans/2026-05-15-agent-framework-governance.md
```

### 11.2 状态

spec 状态允许：

```text
draft for review
approved
implemented
archived
```

plan 状态允许：

```text
draft
in progress
implemented and verified
archived
```

状态只描述该 spec/plan 自己，不替代 current-status。

### 11.3 归档

历史 spec/plan 归档到：

```text
docs/superpowers/archive/<topic>/**
```

归档后：

```text
不从 docs/README.md 主入口直接引导为当前任务
不覆盖 docs/status/current-status.md
只在考古、复盘、迁移来源说明时读取
```

## 12. Check 脚本规则

### 12.1 检查项目

`scripts/check-agent-governance.ps1` 第一版检查：

```text
1. root docs/superpowers/specs 命名。
2. root docs/superpowers/plans 命名。
3. admin_back_go/docs/superpowers 不再出现新的 active spec/plan。
4. diff 中出现 admin_back_go/internal/module 或 route 改动时，提示 contract/current-status/smoke matrix。
5. diff 中出现 admin_front_ts/src/api 或 views 改动时，提示 contract/current-status/smoke matrix。
6. diff 中出现 database/migrations 或 admin.sql 改动时，提示 schema/current-status/architecture/smoke。
7. diff 中出现 realtime 关键词时，提示 admin-realtime-v1。
8. diff 中出现 queue/cron/job 关键词时，提示 queue/scheduler docs。
9. 检查 staged/working/range 目标中是否包含 node_modules，避免误扫。
10. 输出 root/backend/frontend git status 摘要。
```

### 12.2 不检查项目

第一版不做：

```text
不解析 Markdown AST
不跑 OpenAPI generator
不检查所有链接有效性
不连接数据库确认 migration
不运行 Go/Vue 测试
不读 node_modules
不扫历史 archive 全量内容
```

### 12.3 Ignore 机制

允许在提交说明或报告中解释为什么某个 docs sync 不需要，但脚本第一版不要解析 commit message。

第一版采用文件级 ignore：

```text
docs/governance/ignore-rules.md
```

但不建议第一阶段就实现复杂 ignore。更简单做法是：脚本只 warning，Strict 模式再 blocking。

## 13. 冷启动文档设计

### 13.1 docs/README.md 应该回答的问题

```text
1. 项目现在是什么？
2. 当前 active runtime 是什么？
3. root/backend/frontend 仓库边界是什么？
4. 第一批必读文档是什么？
5. current-status 在哪里？
6. contract 在哪里？
7. smoke matrix 在哪里？
8. superpowers spec/plan 在哪里？
9. 结束任务前必须检查什么？
```

### 13.2 AGENTS.md 应该回答的问题

```text
1. Linus 三问是什么？
2. 不可协商原则是什么？
3. agent 分工在哪里？
4. 默认必读文档是什么？
5. 路径输出格式是什么？
```

### 13.3 02-agent-framework 应该回答的问题

```text
1. Superpowers 和项目 agents 的关系。
2. agent 角色列表。
3. 角色进入条件。
4. 角色禁止事项。
5. 输出模板。
6. 任务生命周期。
```

### 13.4 新增 governance 文档

建议新增：

```text
docs/architecture/06-documentation-governance.md
docs/testing/pre-push-gates.md
```

职责：

```text
06-documentation-governance.md
  文档真相源、状态口径、改动到 docs sync 矩阵、归档规则。

pre-push-gates.md
  轻量 gate、Strict gate、跳过规则、手动验证命令。
```

## 14. 任务生命周期

第一版标准生命周期：

```text
1. Intake
   读 AGENTS.md / docs/README.md / current-status。

2. Role pick
   选择一个主 agent 角色。

3. Scope lock
   明确 In scope / Out of scope / 不破坏什么。

4. Spec
   新功能或架构变化必须写 design spec。

5. Plan
   approved spec 后写 implementation plan。

6. Implementation
   按角色和边界改代码。

7. Verification
   按改动类型跑 targeted tests / smoke / contract。

8. Docs sync
   current-status / contract / smoke matrix / architecture 同步。

9. Review
   reviewer 查越界、坏味道、验证缺失。

10. Push gate
   轻量 governance check + 必要验证证据。
```

小修也要过最小流程，但 spec/plan 可以按规模裁剪。

## 15. 第一版实施边界

第一版推荐只做这些文件：

```text
docs/superpowers/specs/2026-05-15-agent-framework-governance-design.md
docs/superpowers/plans/2026-05-15-agent-framework-governance.md
docs/architecture/02-agent-framework.md
docs/architecture/06-documentation-governance.md
docs/testing/pre-push-gates.md
scripts/check-agent-governance.ps1
scripts/install-git-hooks.ps1
.githooks/pre-push
```

可选更新：

```text
AGENTS.md
docs/README.md
agents/README.md
agents/*.md
```

明确不碰：

```text
admin_back_go/internal/**
admin_front_ts/src/**
database/migrations/**
admin.sql
```

## 16. 分阶段落地

### Phase A：设计和文档

```text
1. 写本 design spec。
2. 用户 review。
3. 写 implementation plan。
4. 更新 02-agent-framework。
5. 新增 documentation governance 文档。
6. 新增 pre-push gates 文档。
```

### Phase B：手动 check 脚本

```text
1. 新增 scripts/check-agent-governance.ps1。
2. 支持 working / range 模式。
3. 输出 root/backend/frontend 状态。
4. 实现 spec/plan 命名检查。
5. 实现 touched file -> docs sync warning。
6. 实现 Strict 模式 blocking。
```

### Phase C：Hook 安装

```text
1. 新增 .githooks/pre-push。
2. 新增 scripts/install-git-hooks.ps1。
3. 默认只挂 root hook。
4. 明确 SKIP_AGENT_GOVERNANCE_CHECK 跳过规则。
```

### Phase D：收口验证

```text
1. 手动运行 check-agent-governance.ps1。
2. 安装 hook 后做 dry-run。
3. 故意制造命名错误，确认能报错。
4. 故意触碰 backend route 文件，确认能提示 docs sync。
5. 不触碰业务 runtime。
```

## 17. 验收标准

本治理切片完成必须满足：

```text
1. 新 agent 能从 docs/README.md 找到 agent framework、docs governance、pre-push gate。
2. 02-agent-framework 明确角色进入条件和输出模板。
3. documentation governance 明确文档真相源和 sync matrix。
4. pre-push gates 明确轻量/严格检查边界。
5. check-agent-governance.ps1 能在当前 root 仓库运行。
6. check 脚本不扫描 node_modules。
7. check 脚本不要求 DB/Redis/backend/frontend 服务在线。
8. hook 可安装、可跳过、可解释。
9. 当前业务 runtime 文件没有被修改。
10. 最终报告包含 Outcome / Changed files / Verification / Known risks / Next step。
```

## 18. 风险和处理

### 18.1 风险：hook 太严格影响开发

处理：

```text
默认 warning，Strict 模式才 blocking。
full smoke 不进默认 pre-push。
允许显式环境变量跳过。
```

### 18.2 风险：文档越来越多，入口更乱

处理：

```text
docs/README.md 只做入口。
current-status 只写当前事实。
contract 只写 API/realtime。
architecture 只写规则和边界。
spec/plan 只写当前任务设计和执行。
```

### 18.3 风险：脚本变成业务规则垃圾桶

处理：

```text
脚本只检查通用治理规则。
业务模块规则写在对应 spec / contract / smoke matrix。
```

### 18.4 风险：多仓库提交顺序混乱

处理：

```text
check 脚本只提示三仓状态。
不自动 stage。
不自动 commit。
报告必须写清哪个仓库改了什么。
```

### 18.5 风险：current-status 被滥用

处理：

```text
只允许写 verified runtime facts。
planned 写 planned，partial 写 gap。
spec/plan 完成不等于 runtime implemented。
```

## 19. 推荐下一步

本 spec review 通过后，再写 implementation plan：

```text
docs/superpowers/plans/2026-05-15-agent-framework-governance.md
```

计划应按这个顺序拆：

```text
1. 文档治理更新
2. pre-push gate 文档
3. check-agent-governance.ps1
4. hook installer
5. dry-run 验证
```

不要先写 hook。先把文档和手动 check 跑通，再挂 hook。
