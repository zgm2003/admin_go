# Pre-push Gates

## Default gate

Default gate = whitespace checks + agent governance check only.

The default pre-push gate is intentionally light:

```text
1. run the agent governance checker in `-Mode range`
2. collect committed range paths from the root repo plus `admin_back_go` and `admin_front_ts`
3. inside the checker, run root/subrepo range `git diff --check`, plus root working and cached `git diff --check`
4. run non-live runtime documentation fact checks for selected manifests/routes/schema artifacts
5. print changed files, evidence, risks, and next step
```

Pre-push must not require DB/Redis/backend/frontend to be online. Pre-push must not run full smoke by default. Runtime documentation fact checks in the default gate are non-live; run `scripts/check-runtime-doc-facts.ps1 -LiveSchema` explicitly when table truth must be rechecked against MySQL.

Default gate catches whitespace drift and obvious governance/path drift. It does not prove the application works.

`PASS_WITH_WARNINGS` 不是干净闭环。比如 runtime path touched without docs 在非 Strict 模式下只警告、不阻断；提交或汇报前仍必须人工判断是否需要同步 contracts/status/testing/architecture 文档，不能把 warning 当成验证通过。

## Codex hooks versus Git pre-push

Codex lifecycle hooks and Git pre-push hooks are different layers:

```text
Codex hooks       = during the Codex conversation
Git pre-push hook = before pushing Git commits
Smoke/tests       = task-specific runtime proof
```

Codex hooks can remind or block during a turn, but they do not prove the final diff is valid. The Git pre-push hook still runs `scripts/check-agent-governance.ps1 -Mode range`.

## Strict gate

Strict gate = blocking docs-sync/path governance for release or module finish.

Use Strict when a module is being closed, a release is being prepared, or a reviewer explicitly asks for blocking governance checks.

Strict makes docs-sync/path drift blocking instead of warning-only. It still does not run DB/Redis/backend/frontend tests, contract checks, or smoke by itself; those remain task-specific commands chosen and reported outside the pre-push checker. Strict is not the default hook behavior.

## Skip rule

The explicit skip variable is:

```powershell
$env:SKIP_AGENT_GOVERNANCE_CHECK='1'
```

For POSIX shells:

```sh
SKIP_AGENT_GOVERNANCE_CHECK=1 git push
```

When `SKIP_AGENT_GOVERNANCE_CHECK=1` is set, the hook/checker must print a visible skip message. Skipping is allowed for emergencies or broken local tooling, but the final report must say it was skipped.

## Output format

Gate output should use this shape:

```text
Outcome
Working changed files or Range changed files
Working dirty files when Mode=range and the workspace is dirty
Key evidence
Verification
Known risks
Next step
```

For a clean range/default gate, `Verification` should explicitly say:

```text
range diff check passed
subrepo range diff check passed when the subrepo exists and has the resolved base
working diff check passed
cached diff check passed
runtime documentation fact check passed
no blocking governance violations found
```

For `-Mode working`, there is no range diff check.

## Examples

Run the whitespace gate directly:

```powershell
git diff --check
```

Run the governance checker against the current workspace:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Run the knowledge/runtime manifest fact checker directly:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
```

Run the governance checker for the committed diff from the resolved base to `HEAD`. The committed diff includes root plus `admin_back_go` and `admin_front_ts` when those subrepos exist and have the resolved base. Dirty/staged files are reported separately; cached and working whitespace is still checked:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode range
```

Run the blocking release/module-finish version:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode range -Base origin/master -Strict
```

Mode meanings:

```text
working = current workspace
range = committed diff from resolved base to HEAD across root plus known subrepos; dirty/staged files are reported separately, and cached/working whitespace is still checked
Strict = blocking mode for release or module completion
```

Install the lightweight root hook:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-git-hooks.ps1
git config --get core.hooksPath
```

Expected hook path:

```text
.githooks
```

## Why this is not smoke

Smoke proves a real runtime chain with real dependencies. Pre-push only protects the repo from cheap, local mistakes.

Therefore:

```text
pre-push must not require DB/Redis/backend/frontend to be online
pre-push must not run full smoke by default
pre-push must not pretend a runtime path is verified
pre-push can remind the worker which smoke or tests are still needed
```

If a task needs smoke, run the smoke command explicitly and report the result. A passing pre-push gate is not a smoke pass.
