# Codex Hooks Agent Framework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `E:\admin_go` 的 Codex-first agent 框架升级成 Superpowers + project agents + Codex lifecycle hooks + Git pre-push 四层治理。

**Architecture:** 保留现有 Git pre-push 轻量 gate，新增 repo-local Codex lifecycle hooks 做对话内提醒和低误伤阻断。文档层把 Superpowers/TDD、AI 自主解题、注释规范和 agent 边界写进冷启动入口；hook 脚本只输出 Codex 支持的 JSON，不自动改文件。

**Tech Stack:** Markdown, PowerShell 5+/PowerShell Core compatible scripts, Codex `hooks.json`, existing `scripts/check-agent-governance.ps1`, Git.

---

## Scope Check

本计划只覆盖一个治理子系统：`E:\admin_go` root agent framework and Codex hooks governance。

不改：

```text
admin_back_go runtime
admin_front_ts runtime
DB schema
API contract behavior
RBAC seed
smoke runtime
```

## File Structure

Create:

- `docs/architecture/08-codex-hooks.md` — Codex lifecycle hooks 的项目级说明和运维边界。
- `.codex/hooks.json` — repo-local Codex hook 配置。
- `.codex/hooks/lib/AdminGoHookCommon.ps1` — hook 脚本共享 JSON/stdin 输出工具。
- `.codex/hooks/session_start.ps1` — `SessionStart` 追加项目冷启动上下文。
- `.codex/hooks/user_prompt_submit.ps1` — `UserPromptSubmit` 追加 Superpowers/TDD/docs-governance 上下文。
- `.codex/hooks/pre_tool_use.ps1` — `PreToolUse` 阻断低争议危险命令。
- `.codex/hooks/post_tool_use.ps1` — `PostToolUse` 对治理文件变更和失败命令追加复盘上下文。
- `.codex/hooks/stop_review.ps1` — `Stop` 阻止“声称完成但无验证证据”的回答结束。
- `scripts/test-codex-hooks.ps1` — hook 行为的本地 PowerShell 测试。

Modify:

- `AGENTS.md` — 冷启动硬规则加入四层治理、Superpowers/TDD、AI 自主解题、注释规则入口。
- `docs/README.md` — 冷启动顺序加入 `08-codex-hooks.md`，说明 `.codex/hooks` 和 `/hooks` review。
- `docs/architecture/02-agent-framework.md` — 四层模型、当前执行规则和 hook 分工。
- `docs/architecture/05-development-quality-rules.md` — TDD 默认规则、AI 自主解题规则、注释规则细则。
- `docs/architecture/07-documentation-governance.md` — Codex hooks 属于治理变更，不能替代 runtime truth。
- `docs/testing/pre-push-gates.md` — 明确 Codex hooks 与 Git pre-push 的分工。
- `agents/README.md` — agent 使用顺序加入 Superpowers/Codex hooks。
- `agents/architect.md` — docs/agent/hook 任务默认主角色规则。
- `agents/backend-worker.md` — 后端 worker 的 TDD、注释和自主查证规则。
- `agents/frontend-adapter.md` — 前端 adapter 的 TDD、注释和自主查证规则。
- `agents/reviewer.md` — reviewer 增加 Superpowers/TDD/hooks/comment 审查项。

Source spec:

- `docs/superpowers/specs/2026-05-19-codex-hooks-agent-framework-design.md`

---

### Task 1: Update cold-start docs with the four-layer governance model

**Files:**

- Modify: `AGENTS.md`
- Modify: `docs/README.md`
- Modify: `docs/architecture/02-agent-framework.md`
- Modify: `agents/README.md`

- [ ] **Step 1: Prove the four-layer model is not yet discoverable**

Run:

```powershell
Select-String -Path AGENTS.md,docs/README.md,docs/architecture/02-agent-framework.md,agents/README.md -Pattern 'Codex lifecycle hooks|四层治理|AI 自主解题|TDD 默认|08-codex-hooks'
```

Expected before this task:

```text
No matches, or only historical/spec references outside the active cold-start docs.
```

- [ ] **Step 2: Update `AGENTS.md`**

Insert after `## 核心判断` or before `## Linus 三问`:

````markdown
## Codex-first 四层治理

本仓库默认是 Codex-first，但不是只靠提示词记忆。

```text
Superpowers      = 需求理解、spec、plan、TDD 工作法
agents/          = 项目角色边界，谁负责什么、不能做什么
Codex hooks      = 对话内提醒、上下文注入、低误伤阻断
Git pre-push hook = push 前轻量治理检查
```

默认顺序：

```text
1. 用 Superpowers 理解需求；新行为/行为变更先 brainstorming
2. 进入实现或 bugfix 前默认 TDD：先失败测试，再生产代码
3. 只选一个项目 agent 主角色，不做全能 agent
4. Codex hooks 只做过程治理，不替代 Git pre-push、smoke 或 runtime 验证
```
````

Add `docs/architecture/08-codex-hooks.md` to the default read list after `docs/architecture/07-documentation-governance.md`.

- [ ] **Step 3: Update `docs/README.md`**

In `冷启动阅读顺序`, insert:

```markdown
12. docs/architecture/08-codex-hooks.md
```

Renumber the following testing docs so the order stays continuous.

Add under repository boundaries or common verification commands:

```markdown
Codex hooks live under root `.codex/`. They are repo-local lifecycle hooks for Codex sessions only. Use `/hooks` inside Codex CLI to review/trust loaded hooks after this repo changes hook config.
```

- [ ] **Step 4: Update `docs/architecture/02-agent-framework.md`**

Replace the existing relationship block with:

````markdown
两者关系现在扩展为四层：

```text
Superpowers       = 怎么理解需求、写 spec/plan、执行 TDD
agents/           = 谁负责什么、不能做什么、必须产出什么
Codex hooks       = 对话内提醒、上下文注入、低误伤阻断
Git pre-push hook = push 前轻量治理检查
```

`Codex hooks` 不替代 `scripts/check-agent-governance.ps1`、smoke 或 runtime 证据。它只帮助 Codex 在对话过程中少忘规则。
````

Add a section after `Pre-push gate rules`:

````markdown
## Codex lifecycle hooks

Codex hooks 的项目级说明在：

```text
docs/architecture/08-codex-hooks.md
```

默认加载位置：

```text
.codex/hooks.json
.codex/hooks/*.ps1
```

项目 hooks 只做对话内治理：冷启动提示、Superpowers/TDD 提醒、危险命令低误伤阻断、完成前验证提醒。不要让 hooks 自动改业务代码、自动修文档或假装覆盖所有工具路径。
````

- [ ] **Step 5: Update `agents/README.md`**

In `使用顺序`, insert:

```markdown
8. Read docs/architecture/08-codex-hooks.md
9. Pick exactly one role below
```

Add:

```markdown
## Superpowers and hooks

新行为、行为变更、bugfix、refactor 默认先按 Superpowers 流程推进。实现阶段默认 TDD。

Codex hooks 是过程内辅助，不是角色本身。hooks 提醒了规则，不代表任务已经验证完成。
```

- [ ] **Step 6: Verify Task 1**

Run:

```powershell
Select-String -Path AGENTS.md,docs/README.md,docs/architecture/02-agent-framework.md,agents/README.md -Pattern 'Codex lifecycle hooks|四层治理|Superpowers|TDD|08-codex-hooks'
git diff --check
```

Expected:

```text
Each changed cold-start doc has at least one relevant match.
git diff --check prints no errors.
```

- [ ] **Step 7: Commit Task 1**

Run:

```powershell
git add AGENTS.md docs/README.md docs/architecture/02-agent-framework.md agents/README.md
git commit -m "docs: define codex-first four-layer governance"
```

Expected:

```text
Commit succeeds.
```

---

### Task 2: Add Codex hooks architecture guidance and update governance/pre-push docs

**Files:**

- Create: `docs/architecture/08-codex-hooks.md`
- Modify: `docs/architecture/07-documentation-governance.md`
- Modify: `docs/testing/pre-push-gates.md`

- [ ] **Step 1: Write `docs/architecture/08-codex-hooks.md`**

Create the file with this content:

````markdown
# Codex Lifecycle Hooks

## Purpose

Codex lifecycle hooks are the conversation-time governance layer for `E:\admin_go`.

They help Codex remember project rules while a turn is running:

```text
SessionStart      -> load cold-start context
UserPromptSubmit  -> remind Superpowers/TDD/docs-first rules
PreToolUse        -> block low-dispute dangerous commands
PostToolUse       -> remind verification after governance changes
Stop              -> prevent unsupported completion claims
```

Hooks do not replace runtime evidence, smoke, tests, or Git pre-push governance.

## Source of truth

Official behavior reference:

- https://developers.openai.com/codex/hooks
- https://developers.openai.com/codex/config-reference#configtoml

Current repo-local hook files:

```text
.codex/hooks.json
.codex/hooks/*.ps1
.codex/hooks/lib/AdminGoHookCommon.ps1
scripts/test-codex-hooks.ps1
```

## Loading and trust

Project-local hooks load only when Codex trusts the project config layer.

After hook files change, open Codex CLI and run:

```text
/hooks
```

Review the loaded hook sources and trust the repo-local hooks if they match the checked-in files.

## Event policy

| Event | Policy |
| --- | --- |
| `SessionStart` | Add cold-start context for `AGENTS.md`, `current-status`, Superpowers, TDD, and project agent roles. |
| `UserPromptSubmit` | Add context when the user asks to change behavior, implement, fix, continue, or write a plan. |
| `PreToolUse` | Deny low-dispute destructive commands such as hard reset, force clean, broad recursive delete, deleting `.git`, and force push without explicit instruction. |
| `PostToolUse` | Add verification reminders when governance files changed or a command failed. |
| `Stop` | Continue the turn when the final answer claims completion without verification evidence. |

## Hard limits

Hooks are engineering guardrails, not a security boundary.

```text
Do not rely on hooks to intercept every possible tool path.
Do not let hooks auto-edit files.
Do not let hooks auto-stage, auto-commit, auto-push, or auto-revert.
Do not treat hook pass as smoke or runtime verification.
```

## Verification

For hook script changes, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-codex-hooks.ps1
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

If a task changes backend/frontend runtime, run the task-specific tests separately. Hook tests only prove hook behavior.
````

- [ ] **Step 2: Update documentation governance**

In `docs/architecture/07-documentation-governance.md`, add a row to `Docs sync matrix` after `Governance or agent workflow`:

```markdown
| Codex lifecycle hook behavior | `docs/architecture/08-codex-hooks.md`, `.codex/hooks.json`, `.codex/hooks/*.ps1`, `scripts/test-codex-hooks.ps1`, `docs/testing/pre-push-gates.md` | Hooks are conversation-time governance only; they must not be documented as runtime proof or smoke evidence. |
```

Add to `Verification matrix`:

```markdown
| Codex hook behavior | `scripts/test-codex-hooks.ps1` output plus `/hooks` review/trust note when hook config changed. | Assuming Codex loaded changed hooks without review. |
```

- [ ] **Step 3: Update pre-push docs**

In `docs/testing/pre-push-gates.md`, add after the default gate section:

````markdown
## Codex hooks versus Git pre-push

Codex lifecycle hooks and Git pre-push hooks are different layers:

```text
Codex hooks       = during the Codex conversation
Git pre-push hook = before pushing Git commits
Smoke/tests       = task-specific runtime proof
```

Codex hooks can remind or block during a turn, but they do not prove the final diff is valid. The Git pre-push hook still runs `scripts/check-agent-governance.ps1 -Mode range`.
````

- [ ] **Step 4: Verify Task 2**

Run:

```powershell
Select-String -Path docs/architecture/08-codex-hooks.md,docs/architecture/07-documentation-governance.md,docs/testing/pre-push-gates.md -Pattern 'Codex hooks|lifecycle hooks|scripts/test-codex-hooks.ps1|/hooks|pre-push'
git diff --check
```

Expected:

```text
All three docs contain relevant matches.
git diff --check prints no errors.
```

- [ ] **Step 5: Commit Task 2**

Run:

```powershell
git add docs/architecture/08-codex-hooks.md docs/architecture/07-documentation-governance.md docs/testing/pre-push-gates.md
git commit -m "docs: add codex lifecycle hooks governance"
```

Expected:

```text
Commit succeeds.
```

---

### Task 3: Add Superpowers/TDD, AI autonomy, and comment quality rules

**Files:**

- Modify: `docs/architecture/05-development-quality-rules.md`
- Modify: `agents/architect.md`
- Modify: `agents/backend-worker.md`
- Modify: `agents/frontend-adapter.md`
- Modify: `agents/reviewer.md`

- [ ] **Step 1: Update `docs/architecture/05-development-quality-rules.md` with Superpowers/TDD**

Add after `## Linus 三问`:

````markdown
## Superpowers and TDD 默认规则

新行为、行为变更、bugfix、refactor 默认按 Superpowers 流程推进。

```text
需求不清或要设计新行为 -> brainstorming
设计认可后 -> spec
spec 认可后 -> implementation plan
进入实现 -> TDD
```

实现阶段默认 TDD：

```text
先写最小失败测试
确认失败原因正确
再写最小生产代码
确认测试通过
再重构
```

docs-only governance changes do not require backend/frontend runtime tests, but they still require `git diff --check` and governance checks.
````

- [ ] **Step 2: Add AI autonomy rules**

Add after the Superpowers/TDD section:

````markdown
## AI 自主解题规则

AI 默认自己解决问题，不把可以查证的事情抛回给用户。

默认先查：

```text
docs/status/current-status.md
docs/contracts/*
docs/architecture/*
runtime docs
git diff / git status
targeted tests
logs and smoke output
official vendor docs when the behavior is tool/provider-specific
```

需要问用户：

```text
真实不可逆业务选择
需要生产凭据、账号、支付后台或第三方控制台操作
会删除数据或改变线上状态
多个产品方案无法从现有规则推出
用户明确要求先确认
```

不需要问用户：

```text
文档归属
路径命名
轻量验证命令
是否先读 current-status
是否先查官方 Codex/OpenAI docs
是否遵守 TDD
是否补必要注释
```
````

- [ ] **Step 3: Add comment rules**

Add before `## Go 后端规则`:

````markdown
## 注释规则

AI 应该积极写有用注释，但不制造噪音。

应该写注释：

```text
非显然业务约束
事务、幂等、重试、队列、cron、WebSocket、AI provider 边界
安全、权限、跨仓、部署、运行时假设
为什么不能用更简单或更常见做法
临时兼容的退出条件和证据来源
```

不应该写注释：

```text
复述代码能直接看出的内容
没有 owner 或退出条件的待办注释
用注释掩盖坏命名
注释与 current-status / contract / runtime 不一致
把注释当测试或契约
```

验收口径：

```text
注释解释 why，不解释肉眼能看到的 what。
复杂边界没有注释是问题；无意义注释也是问题。
```
````

- [ ] **Step 4: Update agent role docs**

Add to `agents/architect.md` under `## 判断标准`:

```markdown
架构 agent 默认自己查项目 truth source 和官方工具文档。只有真实不可逆产品取舍才问用户。
```

Add to `agents/backend-worker.md` under `## 默认调用链` or after `## 默认 i18n 规则`:

```markdown
## 默认 TDD / 注释规则

后端 feature、bugfix、refactor 默认 TDD：先写失败测试，再改 service/repository/handler。

复杂业务边界必须写注释，尤其是事务、幂等、队列、cron、AI provider、权限和运行时假设。不要写复述代码的注释。
```

Add to `agents/frontend-adapter.md` under `## 默认实现规则`:

```markdown
TDD：
  前端行为变更默认先补 Vitest / vue-tsc 可验证的测试，再改组件或 composable。

注释：
  复杂 UI 状态机、权限判断、WebSocket/AI streaming、副作用和兼容边界要解释 why。
  不写复述模板结构的注释。
```

Add to `agents/reviewer.md` under `## 审查重点`:

```markdown
Superpowers/TDD：
  新行为或 bugfix 是否有先失败、后通过的测试证据。

Codex hooks：
  hooks 是否只做过程治理；是否避免自动改文件、自动提交、假装 smoke。

注释：
  复杂边界是否解释 why；是否存在复述代码或过期待办噪音。

AI 自主解题：
  是否把可查证问题抛给用户；是否缺少官方文档或 runtime evidence。
```

- [ ] **Step 5: Verify Task 3**

Run:

```powershell
Select-String -Path docs/architecture/05-development-quality-rules.md,agents/architect.md,agents/backend-worker.md,agents/frontend-adapter.md,agents/reviewer.md -Pattern 'TDD|AI 自主解题|注释|Codex hooks|Superpowers'
git diff --check
```

Expected:

```text
Each changed file contains relevant matches.
git diff --check prints no errors.
```

- [ ] **Step 6: Commit Task 3**

Run:

```powershell
git add docs/architecture/05-development-quality-rules.md agents/architect.md agents/backend-worker.md agents/frontend-adapter.md agents/reviewer.md
git commit -m "docs: add tdd autonomy and comment rules for agents"
```

Expected:

```text
Commit succeeds.
```

---

### Task 4: Write failing hook tests

**Files:**

- Create: `scripts/test-codex-hooks.ps1`
- Future implementation files covered by tests:
  - `.codex/hooks/session_start.ps1`
  - `.codex/hooks/user_prompt_submit.ps1`
  - `.codex/hooks/pre_tool_use.ps1`
  - `.codex/hooks/post_tool_use.ps1`
  - `.codex/hooks/stop_review.ps1`

- [ ] **Step 1: Create the failing test harness**

Create `scripts/test-codex-hooks.ps1`:

```powershell
$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    $scriptDir = Split-Path -Parent $MyInvocation.ScriptName
    $root = & git -C $scriptDir rev-parse --show-toplevel 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Cannot resolve repo root: $root"
    }
    return (($root | Select-Object -First 1).ToString()).Trim()
}

function Invoke-HookScript {
    param(
        [Parameter(Mandatory=$true)][string]$RepoRoot,
        [Parameter(Mandatory=$true)][string]$RelativePath,
        [Parameter(Mandatory=$true)][hashtable]$InputObject
    )

    $scriptPath = Join-Path $RepoRoot $RelativePath
    $inputJson = $InputObject | ConvertTo-Json -Depth 20 -Compress
    $output = $inputJson | powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath
    return ($output -join "`n")
}

function Convert-JsonOutput {
    param([string]$Output)
    if ([string]::IsNullOrWhiteSpace($Output)) {
        throw 'Expected JSON output, got empty output.'
    }
    return $Output | ConvertFrom-Json
}

function Assert-Contains {
    param(
        [Parameter(Mandatory=$true)][string]$Text,
        [Parameter(Mandatory=$true)][string]$Expected
    )
    if ($Text -notlike "*$Expected*") {
        throw "Expected text to contain '$Expected'. Actual: $Text"
    }
}

function Assert-Equals {
    param(
        [Parameter(Mandatory=$true)]$Actual,
        [Parameter(Mandatory=$true)]$Expected,
        [Parameter(Mandatory=$true)][string]$Message
    )
    if ($Actual -ne $Expected) {
        throw "$Message Expected '$Expected', got '$Actual'."
    }
}

$repoRoot = Resolve-RepoRoot

$sessionOutput = Invoke-HookScript -RepoRoot $repoRoot -RelativePath '.codex/hooks/session_start.ps1' -InputObject @{
    hook_event_name = 'SessionStart'
    source = 'startup'
    cwd = $repoRoot
    model = 'gpt-5.5'
}
$sessionJson = Convert-JsonOutput $sessionOutput
Assert-Equals $sessionJson.hookSpecificOutput.hookEventName 'SessionStart' 'SessionStart event mismatch.'
Assert-Contains $sessionJson.hookSpecificOutput.additionalContext 'Superpowers'
Assert-Contains $sessionJson.hookSpecificOutput.additionalContext 'TDD'
Assert-Contains $sessionJson.hookSpecificOutput.additionalContext 'agents/'

$promptOutput = Invoke-HookScript -RepoRoot $repoRoot -RelativePath '.codex/hooks/user_prompt_submit.ps1' -InputObject @{
    hook_event_name = 'UserPromptSubmit'
    prompt = '继续实现这个功能'
    cwd = $repoRoot
    model = 'gpt-5.5'
}
$promptJson = Convert-JsonOutput $promptOutput
Assert-Equals $promptJson.hookSpecificOutput.hookEventName 'UserPromptSubmit' 'UserPromptSubmit event mismatch.'
Assert-Contains $promptJson.hookSpecificOutput.additionalContext 'brainstorming'
Assert-Contains $promptJson.hookSpecificOutput.additionalContext 'TDD'

$preOutput = Invoke-HookScript -RepoRoot $repoRoot -RelativePath '.codex/hooks/pre_tool_use.ps1' -InputObject @{
    hook_event_name = 'PreToolUse'
    tool_name = 'Bash'
    cwd = $repoRoot
    model = 'gpt-5.5'
    tool_input = @{
        command = 'git reset --hard HEAD'
    }
}
$preJson = Convert-JsonOutput $preOutput
Assert-Equals $preJson.hookSpecificOutput.hookEventName 'PreToolUse' 'PreToolUse event mismatch.'
Assert-Equals $preJson.hookSpecificOutput.permissionDecision 'deny' 'Dangerous command should be denied.'

$postOutput = Invoke-HookScript -RepoRoot $repoRoot -RelativePath '.codex/hooks/post_tool_use.ps1' -InputObject @{
    hook_event_name = 'PostToolUse'
    tool_name = 'Bash'
    cwd = $repoRoot
    model = 'gpt-5.5'
    tool_input = @{
        command = 'git diff -- docs/architecture/02-agent-framework.md'
    }
    tool_response = @{
        exit_code = 0
    }
}
$postJson = Convert-JsonOutput $postOutput
Assert-Equals $postJson.hookSpecificOutput.hookEventName 'PostToolUse' 'PostToolUse event mismatch.'
Assert-Contains $postJson.hookSpecificOutput.additionalContext 'check-agent-governance.ps1'

$stopOutput = Invoke-HookScript -RepoRoot $repoRoot -RelativePath '.codex/hooks/stop_review.ps1' -InputObject @{
    hook_event_name = 'Stop'
    cwd = $repoRoot
    model = 'gpt-5.5'
    stop_hook_active = $false
    last_assistant_message = '已完成，修好了。'
}
$stopJson = Convert-JsonOutput $stopOutput
Assert-Equals $stopJson.decision 'block' 'Unverified completion should continue the turn.'
Assert-Contains $stopJson.reason '验证'

Write-Host 'PASS: Codex hook behavior tests passed.'
```

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-codex-hooks.ps1
```

Expected:

```text
The command fails because .codex/hooks/session_start.ps1 does not exist yet.
This is the correct RED state.
```

- [ ] **Step 3: Commit the failing tests**

Do not commit the RED test alone. Keep it staged or uncommitted until Task 5 turns it green.

Expected:

```text
No commit in this step.
```

---

### Task 5: Implement Codex hooks and make tests pass

**Files:**

- Create: `.codex/hooks.json`
- Create: `.codex/hooks/lib/AdminGoHookCommon.ps1`
- Create: `.codex/hooks/session_start.ps1`
- Create: `.codex/hooks/user_prompt_submit.ps1`
- Create: `.codex/hooks/pre_tool_use.ps1`
- Create: `.codex/hooks/post_tool_use.ps1`
- Create: `.codex/hooks/stop_review.ps1`
- Modify: `scripts/test-codex-hooks.ps1` only if a test assertion is wrong, not to weaken coverage.

- [ ] **Step 1: Create `.codex/hooks/lib/AdminGoHookCommon.ps1`**

```powershell
$ErrorActionPreference = 'Stop'

function Read-HookInput {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return [pscustomobject]@{}
    }
    return $raw | ConvertFrom-Json
}

function Write-HookContext {
    param(
        [Parameter(Mandatory=$true)][string]$EventName,
        [Parameter(Mandatory=$true)][string]$Context
    )

    @{
        hookSpecificOutput = @{
            hookEventName = $EventName
            additionalContext = $Context
        }
    } | ConvertTo-Json -Depth 20 -Compress
}

function Write-PreToolDeny {
    param([Parameter(Mandatory=$true)][string]$Reason)

    @{
        hookSpecificOutput = @{
            hookEventName = 'PreToolUse'
            permissionDecision = 'deny'
            permissionDecisionReason = $Reason
        }
    } | ConvertTo-Json -Depth 20 -Compress
}

function Write-StopBlock {
    param([Parameter(Mandatory=$true)][string]$Reason)

    @{
        decision = 'block'
        reason = $Reason
    } | ConvertTo-Json -Depth 20 -Compress
}

function Get-StringValue {
    param($Value)
    if ($null -eq $Value) { return '' }
    return $Value.ToString()
}
```

- [ ] **Step 2: Create `session_start.ps1`**

```powershell
$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'lib/AdminGoHookCommon.ps1')

[void](Read-HookInput)

$context = @'
admin_go Codex cold-start context:
- Treat E:\admin_go as the root governance repo; backend and frontend runtime repos are admin_back_go and admin_front_ts.
- Read AGENTS.md, docs/status/current-status.md, docs/architecture/02-agent-framework.md, docs/architecture/05-development-quality-rules.md, and docs/architecture/08-codex-hooks.md before editing.
- Default to Superpowers for requirement understanding, spec, plan, and TDD.
- Pick exactly one project agent role from agents/; do not act as an all-in-one agent.
- Codex hooks are conversation-time governance only. Git pre-push, tests, smoke, and runtime evidence are still required when relevant.
'@

Write-HookContext -EventName 'SessionStart' -Context $context
```

- [ ] **Step 3: Create `user_prompt_submit.ps1`**

```powershell
$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'lib/AdminGoHookCommon.ps1')

$inputObject = Read-HookInput
$prompt = Get-StringValue $inputObject.prompt

$implementationPattern = '改|修|新增|实现|继续|写吧|写plan|计划|重构|优化|接入|落地|fix|implement|continue|plan|refactor'
$governancePattern = '文档|agent|hooks|hook|Superpowers|TDD|治理|AGENTS\.md|codex'

if ($prompt -match $implementationPattern) {
    $context = @'
Project workflow reminder:
- If this request creates or changes behavior, use Superpowers brainstorming before implementation unless an approved spec already exists.
- Before feature, bugfix, or refactor implementation, use TDD: write the failing test, verify RED, implement minimal code, verify GREEN, then refactor.
- Start from current repo truth: current-status, contracts, architecture docs, git diff/status, targeted tests, logs, and official docs for tool-specific behavior.
'@
    Write-HookContext -EventName 'UserPromptSubmit' -Context $context
    exit 0
}

if ($prompt -match $governancePattern) {
    $context = @'
Governance reminder:
- Keep governance docs in the root repo.
- Codex hooks are conversation-time governance; Git pre-push remains the push-time gate.
- For docs-only governance changes, run git diff --check and scripts/check-agent-governance.ps1 before claiming completion.
'@
    Write-HookContext -EventName 'UserPromptSubmit' -Context $context
    exit 0
}
```

- [ ] **Step 4: Create `pre_tool_use.ps1`**

```powershell
$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'lib/AdminGoHookCommon.ps1')

$inputObject = Read-HookInput
$toolName = Get-StringValue $inputObject.tool_name
$command = Get-StringValue $inputObject.tool_input.command

if ($toolName -ne 'Bash' -and $toolName -ne 'shell_command') {
    exit 0
}

$dangerousPatterns = @(
    'git\s+reset\s+--hard\b',
    'git\s+clean\b[^\r\n]*(?:-fdx|-xdf|-fxd|-dfx)',
    'git\s+push\b[^\r\n]*(?:--force|-f)\b',
    'Remove-Item\b[^\r\n]*-Recurse[^\r\n]*(?:E:[\\/]+admin_go|admin_back_go|admin_front_ts|\.git)',
    'rm\s+-rf\b[^\r\n]*(?:E:[\\/]+admin_go|admin_back_go|admin_front_ts|\.git)'
)

foreach ($pattern in $dangerousPatterns) {
    if ($command -match $pattern) {
        Write-PreToolDeny -Reason "Blocked by admin_go Codex hook: low-dispute destructive command matched '$pattern'. Ask the user for an explicit narrow confirmation or use a reversible command."
        exit 0
    }
}
```

- [ ] **Step 5: Create `post_tool_use.ps1`**

```powershell
$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'lib/AdminGoHookCommon.ps1')

$inputObject = Read-HookInput
$command = Get-StringValue $inputObject.tool_input.command
$exitCode = Get-StringValue $inputObject.tool_response.exit_code

$governancePattern = 'AGENTS\.md|agents/|agents\\|docs/architecture/|docs\\architecture\\|docs/testing/|docs\\testing\\|scripts/check-agent-governance\.ps1|scripts/install-git-hooks\.ps1|\.githooks/|\.githooks\\|\.codex/|\.codex\\'

if ($command -match $governancePattern) {
    $context = @'
Governance file interaction detected:
- Before claiming completion, run git diff --check.
- Run powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working.
- If .codex/hooks.json or .codex/hooks/*.ps1 changed, tell the user to review/trust hooks with /hooks in Codex CLI.
'@
    Write-HookContext -EventName 'PostToolUse' -Context $context
    exit 0
}

if ($exitCode -ne '' -and $exitCode -ne '0') {
    $context = @'
The last tool command failed. Return to the earliest uncertain evidence, summarize the decisive error line, and avoid broadening the search blindly.
'@
    Write-HookContext -EventName 'PostToolUse' -Context $context
    exit 0
}
```

- [ ] **Step 6: Create `stop_review.ps1`**

```powershell
$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'lib/AdminGoHookCommon.ps1')

$inputObject = Read-HookInput

if ($inputObject.stop_hook_active -eq $true) {
    exit 0
}

$message = Get-StringValue $inputObject.last_assistant_message
if ([string]::IsNullOrWhiteSpace($message)) {
    exit 0
}

$claimPattern = '完成|已完成|修好了|通过|验证通过|可以 push|已落地|done|fixed|passed|complete'
$evidencePattern = 'git diff --check|check-agent-governance\.ps1|go test|npm run|vue-tsc|smoke|PASS|FAIL|未验证|not verified|验证'

if ($message -match $claimPattern -and $message -notmatch $evidencePattern) {
    Write-StopBlock -Reason '你刚才声称完成或通过，但最终回答里没有验证证据。请继续一轮：补充实际验证命令和结果；如果只是设计完成或尚未验证，请明确写“未验证”。'
    exit 0
}
```

- [ ] **Step 7: Create `.codex/hooks.json`**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -Command '$root = git rev-parse --show-toplevel; & (Join-Path $root \".codex/hooks/session_start.ps1\")'",
            "timeout": 10,
            "statusMessage": "Loading admin_go agent rules"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -Command '$root = git rev-parse --show-toplevel; & (Join-Path $root \".codex/hooks/user_prompt_submit.ps1\")'",
            "timeout": 10,
            "statusMessage": "Checking admin_go workflow rules"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash|shell_command",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -Command '$root = git rev-parse --show-toplevel; & (Join-Path $root \".codex/hooks/pre_tool_use.ps1\")'",
            "timeout": 10,
            "statusMessage": "Checking admin_go command policy"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash|shell_command|apply_patch|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -Command '$root = git rev-parse --show-toplevel; & (Join-Path $root \".codex/hooks/post_tool_use.ps1\")'",
            "timeout": 10,
            "statusMessage": "Reviewing admin_go tool result"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -Command '$root = git rev-parse --show-toplevel; & (Join-Path $root \".codex/hooks/stop_review.ps1\")'",
            "timeout": 10,
            "statusMessage": "Checking final response evidence"
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 8: Run hook tests and verify GREEN**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-codex-hooks.ps1
```

Expected:

```text
PASS: Codex hook behavior tests passed.
```

- [ ] **Step 9: Verify `.codex/hooks.json` is valid JSON**

Run:

```powershell
Get-Content .\.codex\hooks.json -Raw | ConvertFrom-Json | Out-Null
```

Expected:

```text
No output and exit code 0.
```

- [ ] **Step 10: Commit Task 4 and Task 5 together**

Run:

```powershell
git add .codex/hooks.json .codex/hooks scripts/test-codex-hooks.ps1
git commit -m "chore: add codex lifecycle hook guardrails"
```

Expected:

```text
Commit succeeds.
```

---

### Task 6: Final governance verification and handoff

**Files:**

- Modify only if verification finds a real issue:
  - `docs/architecture/08-codex-hooks.md`
  - `.codex/hooks.json`
  - `.codex/hooks/*.ps1`
  - `scripts/test-codex-hooks.ps1`
  - docs changed in Tasks 1-3

- [ ] **Step 1: Run docs and hook verification**

Run:

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\test-codex-hooks.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected:

```text
git diff --check has no output.
test-codex-hooks prints PASS: Codex hook behavior tests passed.
check-agent-governance prints PASS: no blocking governance violations found.
```

- [ ] **Step 2: Run range governance**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode range -Base master -Strict
```

If current branch is `master` and the previous command has no committed range, use:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode range -Base HEAD~3 -Strict
```

Expected:

```text
PASS: no blocking governance violations found.
```

- [ ] **Step 3: Verify status**

Run:

```powershell
git status --short
git log --oneline -5
```

Expected:

```text
git status --short is empty.
Recent commits include the docs and hook commits from this plan.
```

- [ ] **Step 4: Final report**

Report these points:

```text
Outcome: Codex-first four-layer governance is documented and hook skeleton is installed.
Evidence: list exact verification commands and PASS lines.
Hook trust note: user should run /hooks in Codex CLI to review/trust repo-local hooks.
Runtime boundary: admin_back_go/admin_front_ts runtime was not changed or smoke-tested because this was governance-only.
Next step: use the new framework on the next real runtime slice.
```

---

## Plan Self-Review

Spec coverage:

- Four-layer governance: Task 1.
- Codex hooks docs and official boundary: Task 2.
- Superpowers/TDD default: Task 1 and Task 3.
- AI autonomy: Task 3.
- Comment rules: Task 3.
- Repo-local hook config and scripts: Task 4 and Task 5.
- Verification and `/hooks` trust note: Task 2 and Task 6.

Placeholder scan:

- No unresolved placeholder markers.
- No step says to fill in missing details later.
- Code-bearing steps include concrete file contents or exact snippets.

Type/name consistency:

- Hook scripts use the same shared functions from `.codex/hooks/lib/AdminGoHookCommon.ps1`.
- Test paths match the hook paths in `.codex/hooks.json`.
- Verification commands match existing root governance script names.
