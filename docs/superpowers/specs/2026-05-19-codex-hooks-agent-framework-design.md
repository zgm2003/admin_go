# Codex Hooks Agent Framework Design

状态：设计已获用户认可，待实施计划。

范围：`E:\admin_go` 总控仓库的 Codex-first agent 框架、Codex lifecycle hooks、Superpowers 默认流程、TDD 约束、注释规则和 AI 自主解题规则。本文只设计治理层，不修改 Go/Vue runtime。

官方依据：

- OpenAI Codex Hooks: https://developers.openai.com/codex/hooks
- OpenAI Codex config reference: https://developers.openai.com/codex/config-reference#configtoml

## 1. 背景

当前项目已经有三层治理：

```text
AGENTS.md / docs/README.md        # 冷启动入口
docs/architecture/02-agent-framework.md
agents/*.md                       # 项目 agent 分工
scripts/check-agent-governance.ps1 + .githooks/pre-push
```

这些规则解决了“进仓库后该读什么、谁负责什么、push 前怎么轻量检查”的问题，但还缺一个 Codex 运行时层：

```text
Codex 正在对话、准备执行工具、准备结束回答时，项目规则不能只靠模型记忆。
```

之前项目用 Git pre-push hook 和手写治理脚本兜底。现在 Codex 已经有官方 lifecycle hooks，应该把“对话内提醒、上下文注入、明显越界阻断”交给 Codex hooks，把 Git pre-push 保留为提交前守门。

## 2. Linus 三问

### 2.1 这是个真问题吗？

是。重复摩擦已经出现：

- AI 容易跳过需求理解，直接改代码。
- AI 容易写完再补测试，而不是 TDD。
- AI 容易忘记项目 agent 角色边界。
- AI 容易把 Git pre-push hook 当成唯一治理层。
- AI 写注释时要么不写关键原因，要么写复述代码的噪音。
- 用户希望 AI 在证据足够时自己解决问题，而不是频繁把选择题丢回给用户。

### 2.2 有更简单的做法吗？

有。不要重写一个自研 hook 框架，也不要把 pre-push 做成重型 CI。

第一版只做：

```text
Codex lifecycle hooks 负责过程内提醒/软阻断
Git pre-push hook 负责提交前轻量检查
Superpowers 负责需求、spec、plan、TDD 工作法
项目 agents 负责角色边界
```

### 2.3 会破坏已有前端、接口、登录和权限吗？

不会。这个切片只改 root docs 和 Codex hook 配置/脚本，不修改：

```text
admin_back_go runtime
admin_front_ts runtime
DB schema
API contract
RBAC seed
smoke runtime
```

## 3. 目标

第一版完成后，一个新 Codex 进入 `E:\admin_go` 应该默认知道：

1. 先用 Superpowers 理解需求，不急着改代码。
2. 实现或修 bug 前默认 TDD。
3. 项目 agent 角色是边界，不允许“全能 agent”乱改。
4. Codex hooks 是对话内治理，Git pre-push 是提交前治理。
5. AI 应该主动查证、主动解题，只在真实不可逆选择或缺凭据时问用户。
6. 注释要解释业务约束、运行时边界和非显然原因，不复述代码。

## 4. 非目标

第一版不做：

```text
不替换 scripts/check-agent-governance.ps1
不删除 .githooks/pre-push
不默认跑 full smoke
不做自动修复 hook
不让 hook 改业务代码或自动改文档
不做插件发布
不要求 backend/frontend/DB/Redis 在线
不把 hook 当安全边界
```

Codex hooks 是工程治理辅助，不是权限系统。明显危险动作可以阻断，但不能假装覆盖所有工具路径。

## 5. 分层设计

### 5.1 Superpowers 层

定位：任务方法论。

规则：

```text
需求不清、涉及新行为、修改行为、创建功能 -> 先 brainstorming
设计获认可 -> 写 spec
用户认可 spec -> 写 plan
实现 feature / bugfix / refactor -> 默认 TDD
```

项目文档要把 `$superpowers` 写成默认路径，而不是可选插件：

```text
Superpowers = 怎么推进任务
agents/     = 谁负责什么
Codex hooks = 对话内提醒/阻断
Git hooks   = 提交前守门
```

### 5.2 项目 agents 层

定位：职责边界。

现有角色保留：

```text
architect
api-contract
backend-worker
frontend-adapter
reviewer
```

本切片只强化规则，不新增角色。

强化点：

- 任何任务只能选一个主角色。
- 跨领域任务必须拆顺序，不允许一个 agent 全包。
- agent 输出必须包含证据、文件、验证、下一步。
- 修改 docs/agent/hook 时，主角色默认是 `architect` 或 `reviewer`。

### 5.3 Codex lifecycle hooks 层

定位：对话内治理。

建议新增：

```text
.codex/hooks.json
.codex/hooks/session_start.ps1
.codex/hooks/user_prompt_submit.ps1
.codex/hooks/pre_tool_use.ps1
.codex/hooks/post_tool_use.ps1
.codex/hooks/stop_review.ps1
```

第一版 hook 行为：

| Event | 作用 | 默认行为 |
| --- | --- | --- |
| `SessionStart` | 冷启动上下文 | 注入当前项目阅读顺序、Superpowers/TDD、agent 边界 |
| `UserPromptSubmit` | 用户请求进入模型前 | 对“改/修/新增/实现/继续/写 plan”等请求追加流程提醒 |
| `PreToolUse` | 工具执行前 | 阻断明显越界/破坏性命令；提醒使用 git-root 解析路径 |
| `PostToolUse` | 工具执行后 | 对 docs/agents/hooks 改动提示治理检查；对失败命令追加复盘上下文 |
| `Stop` | 回答结束前 | 如果声称完成但没有验证证据，要求继续补验证或明确未验证 |

第一版只使用 `type: "command"`。不使用当前会被解析但跳过的 `prompt` / `agent` hook。

### 5.4 Git pre-push 层

定位：提交前轻量守门。

现有 `.githooks/pre-push` 保留：

```text
scripts/check-agent-governance.ps1 -Mode range
```

文档要明确：

```text
Codex hooks 不能替代 pre-push
pre-push 不能替代 smoke
smoke 必须按任务显式运行并报告
```

## 6. Codex hooks 细节

### 6.1 `.codex/hooks.json`

使用 repo-local hooks。Codex 官方说明 project-local hooks 只有在项目 `.codex/` layer 被信任时加载，因此文档要提醒用户可用 `/hooks` 查看、信任或禁用非 managed hooks。

命令路径要从 git root 解析，不依赖当前 cwd。

Windows 第一版使用 PowerShell：

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear",
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"$(git rev-parse --show-toplevel)/.codex/hooks/session_start.ps1\"",
            "timeout": 10,
            "statusMessage": "Loading admin_go agent rules"
          }
        ]
      }
    ]
  }
}
```

实施时要验证该命令在当前 Codex Windows shell 下是否能正确解析。若 `$(...)` 在 JSON command 中跨 shell 表现不稳定，改成一个更稳的 wrapper 命令或使用绝对 repo-root 写入方式。

### 6.2 `SessionStart`

输出 JSON，追加 developer context：

```text
本仓库是 E:\admin_go，总控 repo。
先读 AGENTS.md / docs/status/current-status.md / docs/architecture/02-agent-framework.md。
默认使用 Superpowers：需求设计先 brainstorming，实现前 TDD。
只选一个项目 agent 角色，不做全能 agent。
docs 与 runtime 冲突时按 documentation governance 的 truth-source order。
```

### 6.3 `UserPromptSubmit`

读取 stdin JSON 的 `prompt`。如果 prompt 命中实现类意图：

```text
改|修|新增|实现|继续|写吧|写plan|计划|重构|优化|接入|落地
```

追加上下文：

```text
如果这是新行为或行为变更，先用 Superpowers brainstorming。
如果进入实现，必须 TDD：先写失败测试，再写生产代码。
不要停在理论；先查当前 repo truth source。
```

如果 prompt 命中 docs/agent/hook 方向：

```text
文档治理改动优先 root docs，不改 runtime。
验证至少跑 git diff --check 和 scripts/check-agent-governance.ps1。
```

### 6.4 `PreToolUse`

第一版只阻断低争议风险：

- `git reset --hard`
- `git clean -fdx`
- `Remove-Item -Recurse` 指向 repo root 或不明确路径
- 删除 `.git`
- 删除 `admin_back_go` / `admin_front_ts` 整仓目录
- 在未获明确指令时跨 repo `git push --force`
- 修改用户目录 credential/secret store 的命令

对普通读取、rg、git diff、targeted tests 不阻断。

### 6.5 `PostToolUse`

如果 Bash/apply_patch 触碰这些路径：

```text
AGENTS.md
agents/**
docs/architecture/**
docs/testing/**
scripts/check-agent-governance.ps1
scripts/install-git-hooks.ps1
.githooks/**
.codex/**
```

追加上下文提醒：

```text
这是治理层改动。完成前至少跑 git diff --check 和 check-agent-governance.ps1。
如果新增 .codex/hooks，需要提醒用户在 Codex /hooks 中 review/trust。
```

如果工具失败，提醒回到最早不确定证据，而不是盲目扩大范围。

### 6.6 `Stop`

如果 `last_assistant_message` 声称：

```text
完成|已完成|修好了|通过|验证通过|可以 push|已落地
```

但没有出现：

```text
git diff --check
check-agent-governance.ps1
go test
npm run
vue-tsc
smoke
未验证
```

则让 Codex 继续一轮，提示：

```text
你刚才声称完成但没有验证证据。请补充可运行验证；如果当前只完成设计或未验证，请明确写出来。
```

Stop hook 不应无限循环。需要利用 `stop_hook_active` 避免重复继续。

## 7. AI 自主解题规则

新增一条 agent 默认规则：

```text
AI 默认自己解决问题：先查 docs/status、contracts、runtime docs、git diff、tests、logs、官方文档；能基于证据选择安全默认值就直接推进。
```

需要问用户的情况：

```text
真实不可逆业务选择
需要生产凭据/账号/支付/第三方后台操作
会删除数据或改变线上状态
多个方案的产品取舍无法从现有规则推出
用户明确要求先确认
```

不需要问用户的情况：

```text
文档归属
路径命名
轻量验证命令
是否先读 current-status
是否先查官方 Codex/OpenAI docs
是否遵守 TDD
是否补必要注释
```

## 8. 注释规则

新增“积极写注释，但不制造噪音”的规则。

应该写注释：

```text
非显然业务约束
事务、幂等、重试、队列、cron、WebSocket、AI provider 边界
安全、权限、跨仓、部署、运行时假设
为什么不能用更简单/更常见做法
临时兼容的退出条件和证据来源
```

不应该写注释：

```text
复述代码能直接看出的内容
没有 owner / 没有退出条件的 TODO
用注释掩盖坏命名
注释与 current-status / contract / runtime 不一致
把注释当测试或契约
```

验收口径：

```text
注释解释 why，不解释肉眼能看到的 what。
复杂边界没有注释是问题；无意义注释也是问题。
```

## 9. 文档改动范围

实施计划应更新：

```text
AGENTS.md
docs/README.md
docs/architecture/02-agent-framework.md
docs/architecture/05-development-quality-rules.md
docs/architecture/07-documentation-governance.md
docs/testing/pre-push-gates.md
agents/README.md
agents/architect.md
agents/backend-worker.md
agents/frontend-adapter.md
agents/reviewer.md
```

可新增：

```text
docs/architecture/08-codex-hooks.md
.codex/hooks.json
.codex/hooks/*.ps1
```

是否新增 `08-codex-hooks.md` 由实施计划决定。若 `02-agent-framework.md` 内容会膨胀，优先新增独立文档并在冷启动入口链接。

## 10. 验证设计

docs-only 第一版至少验证：

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

如果新增 `.codex/hooks.json` 和 hook 脚本，还要验证：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\.codex\hooks\session_start.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\.codex\hooks\user_prompt_submit.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\.codex\hooks\pre_tool_use.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\.codex\hooks\post_tool_use.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\.codex\hooks\stop_review.ps1
```

每个 hook 脚本需要可接受 stdin JSON，并在空 stdin 或未知字段时安全退出。

最终报告必须说明：

```text
是否只改治理层
是否新增 Codex hooks
是否需要用户在 /hooks 中 review/trust
跑过哪些命令
哪些 runtime 未验证，因为本切片不改 runtime
```

## 11. 风险与处理

### 11.1 Hook 误伤

处理：第一版默认软提醒，硬阻断只覆盖低争议危险命令。

### 11.2 Hook 路径不稳定

处理：命令从 git root 解析；实施时用实际 Codex/PowerShell 行为验证。

### 11.3 Agent 把 hooks 当成安全边界

处理：文档明确 hooks 是工程治理辅助，不覆盖所有工具路径。

### 11.4 文档过度膨胀

处理：`02-agent-framework.md` 保持总览；细节放 `08-codex-hooks.md` 或 hook README。

### 11.5 TDD 过度阻塞 docs-only 工作

处理：docs-only 改动不强行写代码测试，但必须跑文档/治理验证。实现 feature 或 bugfix 时默认 TDD。

## 12. 成功标准

第一版成功标准：

```text
冷启动文档能解释 Superpowers / agents / Codex hooks / Git hooks 的关系。
默认规则明确要求 Superpowers 需求理解和 TDD。
AI 自主解题规则明确，减少不必要询问。
注释规则明确，鼓励解释 why，拒绝噪音。
Codex hooks 的职责、事件、风险和验证方式写清楚。
实施计划可以按 docs-only + optional .codex hooks 落地。
```

## 13. Spec 自审

占位检查：无未解决占位；`TODO` 只出现在“坏注释”反例中，不代表待办事项。

一致性检查：本文只设计治理层；不声称 runtime 已变更；Codex hooks 与 Git pre-push 分工一致。

范围检查：单一实施计划可以完成；不需要拆成多个产品模块。

歧义检查：第一版 hook 以软提醒为主，硬阻断只覆盖低争议危险命令；TDD 适用于实现/bugfix/refactor，不强行套 docs-only 文档改动。
