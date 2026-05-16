# Agent Framework Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把项目的 agent 规则做成可执行治理层：冷启动入口清楚、角色边界清楚、文档真相源清楚、pre-push 轻量 gate 清楚，并且不碰任何 Go/Vue 业务 runtime。

**Architecture:** 只做治理，不做业务。第一层是 root onboarding 文档（`AGENTS.md`、`docs/README.md`、`docs/architecture/02-agent-framework.md`、`agents/README.md`），第二层是治理说明文档（`docs/architecture/07-documentation-governance.md`、`docs/testing/pre-push-gates.md`），第三层是在本治理切片完成后具备的可执行检查脚本和 git hook（Task 3 will create `scripts/check-agent-governance.ps1`; Task 4 will create `scripts/install-git-hooks.ps1` and `.githooks/pre-push`）。检查只读、离线、轻量，默认不跑 full smoke，不依赖 DB/Redis/后端/前端服务。

**Tech Stack:** Markdown, PowerShell, Git hooks, `git diff --check`, existing repo docs. No backend/frontend runtime dependency.

---

## Scope Lock

Spec source:

```text
docs/superpowers/specs/2026-05-15-agent-framework-governance-design.md
```

只做：

```text
冷启动入口和 agent 框架文档收口
文档真相源、状态口径、同步矩阵
pre-push 轻量 gate 文档
check-agent-governance.ps1 (Task 3 will create)
install-git-hooks.ps1 (Task 4 will create)
.githooks/pre-push (Task 4 will create)
docs/README.md / AGENTS.md / agents/README.md / 02-agent-framework.md 的治理入口更新
```

不做：

```text
admin_back_go runtime 代码
admin_front_ts runtime 代码
数据库迁移
current-status 伪装成 runtime 事实
全量 CI 替代品
full smoke 默认化
自动改文档机器人
新增 agent 角色
```

Linus check:

```text
True problem: yes. 现在的项目已经有多仓库、契约、smoke、历史 spec/plan，靠人记规则必漂。
Simpler way: 先把治理规则写进文档，再用一个轻量脚本和 hook 做最低限度阻断。
What breaks: 不能碰 admin_back_go / admin_front_ts 业务链路，不能把 pre-push 变成 full smoke。
```

---

## File Map

### Create

```text
docs/architecture/07-documentation-governance.md
docs/testing/pre-push-gates.md
scripts/check-agent-governance.ps1
scripts/install-git-hooks.ps1
.githooks/pre-push
```

### Modify

```text
AGENTS.md
docs/README.md
docs/architecture/02-agent-framework.md
docs/testing/test-strategy.md
agents/README.md
```

### Do not touch

```text
admin_back_go/**
admin_front_ts/**
docs/status/current-status.md
docs/contracts/*.md
docs/testing/smoke-matrix.md
```

---

### Task 1: Teach the repo where governance lives

**Files:**
- Modify: `AGENTS.md`
- Modify: `docs/README.md`
- Modify: `docs/architecture/02-agent-framework.md`
- Modify: `docs/testing/test-strategy.md`
- Modify: `agents/README.md`

- [ ] **Step 1: Prove the governance docs are currently undiscoverable**

Run:

```powershell
Select-String -Path AGENTS.md,docs/README.md,docs/architecture/02-agent-framework.md,docs/testing/test-strategy.md,agents/README.md -Pattern 'documentation-governance|pre-push-gates'
```

Expected: no matches before implementation.

- [ ] **Step 2: Update the cold-start sequence and agent framework pointers**

Make these exact structural changes:

```text
AGENTS.md
  - add docs/architecture/07-documentation-governance.md to the default read list
  - add docs/testing/pre-push-gates.md to the default read list
  - keep the rest of the order unchanged

docs/README.md
  - insert docs/architecture/07-documentation-governance.md after docs/architecture/05-development-quality-rules.md
  - insert docs/testing/pre-push-gates.md after docs/testing/test-strategy.md and before docs/testing/smoke-matrix.md
  - keep the existing cold-start intent: read order first, task-specific docs second

docs/architecture/02-agent-framework.md
  - add a section that says documentation governance lives in docs/architecture/07-documentation-governance.md
  - add a section that says pre-push gate rules live in docs/testing/pre-push-gates.md
  - keep the one-agent-one-role rule and the output template

docs/testing/test-strategy.md
  - add a short pointer that smoke is not pre-push
  - point readers to docs/testing/pre-push-gates.md for the lightweight hook gate

agents/README.md
  - add the governance docs to the onboarding sequence
  - keep the one-role rule
```

- [ ] **Step 3: Re-run discovery and diff sanity**

Run:

```powershell
Select-String -Path AGENTS.md,docs/README.md,docs/architecture/02-agent-framework.md,docs/testing/test-strategy.md,agents/README.md -Pattern 'documentation-governance|pre-push-gates'
git diff --check
```

Expected:

```text
new governance paths are visible
git diff --check returns clean
```

---

### Task 2: Write the governance documents themselves

**Files:**
- Create: `docs/architecture/07-documentation-governance.md`
- Create: `docs/testing/pre-push-gates.md`

- [ ] **Step 1: Write the failing skeleton in your head, then commit the real doc content**

`docs/architecture/07-documentation-governance.md` must contain these sections:

```text
Purpose
Truth-source order
Status taxonomy
Docs sync matrix
Verification matrix
Archive policy
Multi-repo rules
What this doc does not control
```

It must say explicitly:

```text
live runtime > smoke / test output > served API > process config > docs/status/current-status.md > docs/contracts > architecture docs > spec/plan docs > comments
```

It must also say:

```text
current-status is for verified runtime facts only
planned is not implemented
hook and checker do not auto-fix files
spec/plan history does not override current-status
```

`docs/testing/pre-push-gates.md` must contain these sections:

```text
Default gate
Strict gate
Skip rule
Output format
Examples
Why this is not smoke
```

It must say explicitly:

```text
default gate = git diff --check + governance check only
strict gate = heavier checks for release or module finish
pre-push must not require DB/Redis/backend/frontend to be online
pre-push must not run full smoke by default
```

- [ ] **Step 2: Write concrete command examples**

Use exact examples like these in the new doc, but label the checker commands as available after Task 3 creates `scripts/check-agent-governance.ps1`:

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode range
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode range -Base origin/master -Strict
```

Explain in the doc what each mode means:

```text
working = current workspace
range = staged or push range
Strict = blocking mode for release or module completion
```

- [ ] **Step 3: Re-run Markdown sanity**

Run:

```powershell
git diff --check
```

Expected: clean.

---

### Task 3: Implement the governance checker

**Files:**
- Create: `scripts/check-agent-governance.ps1`

- [ ] **Step 1: Add parameter parsing and repo-root detection**

The script must accept:

```powershell
-Mode working|range
-Base <ref>
-Strict
```

It must:

```text
detect repo root
work from the root, not from current directory assumptions
print which repo is being checked
return non-zero on blocking issues
```

- [ ] **Step 2: Implement the actual checks**

The script must check these rules:

```text
1. git diff --check must be clean.
2. docs/superpowers/specs and docs/superpowers/plans names must match YYYY-MM-DD-<topic>.md.
3. docs/superpowers/archive must remain archive-only.
4. touched admin_back_go runtime files must print docs sync reminders for contract/current-status/smoke/architecture.
5. touched admin_front_ts runtime files must print docs sync reminders for contract/current-status/smoke.
6. touched database/admin.sql files must print schema/current-status/architecture reminders.
7. touched realtime files must print admin-realtime-v1 reminder.
8. touched queue/cron/job files must print queue/scheduler reminder.
9. root/admin_back_go/admin_front_ts status summaries must be printed.
10. SKIP_AGENT_GOVERNANCE_CHECK=1 must skip the check and print a visible skip message.
```

Blocking cases for the first version:

```text
bad spec/plan filename
new active spec/plan file under the wrong directory
obvious docs path drift for touched runtime files when Strict is set
git diff --check failure
```

Warning-only cases:

```text
unrelated dirty files in other repos
suggested validation commands not yet run
runtime touch without docs changes in non-Strict mode
```

- [ ] **Step 3: Add the output format**

The script output must have these sections:

```text
Outcome
Changed files
Key evidence
Verification
Known risks
Next step
```

For a clean run, `Verification` should explicitly say:

```text
git diff --check passed
no blocking governance violations found
```

- [ ] **Step 4: Verify the positive path**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected:

```text
clean working tree or only warning-level notes
no blocking issues
exit code 0
```

- [ ] **Step 5: Verify one blocking path in a throwaway worktree**

Use a disposable worktree under `.tmp` and make one known-bad rename or path drift, then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working -Strict
```

Expected:

```text
checker fails
error names the exact broken rule
the disposable worktree can be deleted afterwards
```

Do not run this negative test in the main workspace.

---

### Task 4: Wire the hook and installer

**Files:**
- Create: `scripts/install-git-hooks.ps1`
- Create: `.githooks/pre-push`

- [x] **Step 1: Install hook path through a dedicated script**

`scripts/install-git-hooks.ps1` must:

```text
set core.hooksPath to .githooks
print the final hooks path
refuse to silently succeed if git config fails
```

The command it must run is:

```powershell
git config core.hooksPath .githooks
```

- [x] **Step 2: Add the pre-push wrapper**

`.githooks/pre-push` must:

```text
honor SKIP_AGENT_GOVERNANCE_CHECK=1
print the explicit skip message
call scripts/check-agent-governance.ps1 in range mode
avoid DB/Redis/backend/frontend runtime dependencies
```

The wrapper should keep the logic thin. The checker stays in `scripts/check-agent-governance.ps1`.

- [x] **Step 3: Verify hook registration**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-git-hooks.ps1
git config --get core.hooksPath
```

Expected:

```text
.githooks
```

- [x] **Step 4: Verify the hook path actually executes the checker**

Run:

```powershell
git push --dry-run
```

Expected:

```text
pre-push hook invokes check-agent-governance
governance check output is visible before any network push completes
```

If the repo has no remote configured, invoke the wrapper in the same shell session and document that exception.

- [x] **Step 5: Verify the skip path**

Run:

```powershell
$env:SKIP_AGENT_GOVERNANCE_CHECK='1'
git push --dry-run
Remove-Item Env:SKIP_AGENT_GOVERNANCE_CHECK
```

Expected:

```text
hook prints the explicit skip message
checker is not run
skip is visible to the user
```

---

### Task 5: Final governance handoff

**Files:**
- None expected beyond the files above

- [ ] **Step 1: Re-check the workspace for accidental runtime drift**

Run:

```powershell
git status --short
git -C admin_back_go status --short
git -C admin_front_ts status --short
```

Expected:

```text
only governance docs / scripts changed in the root repo
no admin_back_go or admin_front_ts runtime files touched
```

- [ ] **Step 2: Re-run the final repo hygiene check**

Run:

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected:

```text
both commands succeed
```

- [ ] **Step 3: Commit the governance slice**

Use a commit message that names the actual work, for example:

```bash
git add AGENTS.md docs/README.md docs/architecture/02-agent-framework.md docs/testing/test-strategy.md agents/README.md docs/architecture/07-documentation-governance.md docs/testing/pre-push-gates.md scripts/check-agent-governance.ps1 scripts/install-git-hooks.ps1 .githooks/pre-push
git commit -m "docs: add agent governance framework and pre-push gate"
```

Do not add any runtime files to this commit.
