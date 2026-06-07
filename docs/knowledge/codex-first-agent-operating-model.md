# Codex-first Agent Operating Model

更新时间：2026-06-07

目标：让 Codex 进 `E:\admin_go` 后，不靠聊天记录，也能按项目真实边界做事。

## Linus 四问

每个任务开始先问：

```text
1. 这是真问题还是臆想？
2. 能不能用更简单的数据结构/契约消灭特殊情况？
3. 会破坏现有前端、接口、登录、权限、DB 数据吗？
4. 这个 null / empty / missing / fallback 状态为什么会出现？
```

答不清楚就查证。不要写兜底。

## Task classification

每轮只选一个主类：

| Type | Meaning | Default owner | Output |
| --- | --- | --- | --- |
| `docs drift` | 文档与 runtime / config / tests 冲突 | `architect` or `reviewer` | patch + diff/governance |
| `code bug` | 测试或 runtime 暴露真实缺陷 | matching worker | RED evidence + fix + GREEN evidence |
| `runtime deploy` | env、Docker、domain、smoke、DB/Redis | `backend-worker` + `reviewer` | exact command/output |
| `governance` | agents、hooks、pre-push、knowledge docs | `architect` + `reviewer` | rule update + governance check |

不要把四类混成一次“大扫除”。

## Role routing

| Need | Use role | Do not do |
| --- | --- | --- |
| 架构边界、开源取舍、阶段拆分 | `agents/architect.md` | 不直接写业务代码 |
| REST/API/current-user/realtime contract | `agents/api-contract.md` | 不让前端反向定义后端 |
| Go backend service/repository/transport/jobs | `agents/backend-worker.md` | 不让 handler 查 DB/Redis |
| Vue admin adapter/page/API/i18n/layout | `agents/frontend-adapter.md` | 不重做 UI，不手写标准 CRUD |
| 越界、验证、docs truth | `agents/reviewer.md` | 不泛泛建议 |

跨角色任务先由 `architect` 或 `api-contract` 定边界，再交 worker。

## Evidence matrix

| Claim | Minimum evidence |
| --- | --- |
| 表结构最新版 | live MySQL `information_schema` + `COUNT(*)` + `mysqldump --no-data` artifact |
| Go backend contract没破 | targeted `go test` + route/contract doc sync；大范围改动再跑 smoke |
| Vue admin没破 | targeted Vitest + `npx vue-tsc -b --pretty false` |
| Canvas Next没破 | targeted Vitest + `npm run typecheck`; release-like 改动跑 `npm run build` |
| docs-only 完成 | `git diff --check` + `scripts/check-runtime-doc-facts.ps1` + `scripts/check-agent-governance.ps1 -Mode working` |
| verified status | current-status 有命令、日期、范围，不用 “should/probably” |

## MySQL schema workflow

需要表结构时：

```powershell
cd E:\admin_go
powershell -ExecutionPolicy Bypass -File .\scripts\export-live-mysql-schema.ps1
```

规则：

```text
迁移文件说明历史，不证明 live schema。
ORM model 说明代码期望，不证明 live schema。
文档里引用表字段时，优先链接 docs/db/mysql-live-schema-YYYY-MM-DD.md。
发现 schema 与代码不一致时，先写 verification gap，不要猜。
```

知识库事实同步检查：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
```

默认检查不连接 DB，保护 manifest/source route/schema artifact 与知识库的 cheap drift；`-LiveSchema` 才重新查当前 MySQL。

## Superpowers in this project

| Situation | Skill path |
| --- | --- |
| 新行为、行为变更、质量 hardening | brainstorming -> spec -> plan |
| 实现 feature/bugfix/refactor | test-driven-development |
| 多个互不重叠子问题 | dispatching-parallel-agents |
| 执行既有计划 | subagent-driven-development or executing-plans |
| 收尾前 | verification-before-completion |

项目允许用户明确跳过冗长问答，但不能跳过证据。

## Code quality gates

### Go

```text
service/repository 不依赖 gin.Context
blocking operation 带 context.Context
goroutine 必须有生命周期和取消路径
错误用 fmt.Errorf("%w") 包裹，正常业务错误不用 panic
新增/触碰 response msg 要 i18n key
```

### Vue admin

```text
Composition API + <script setup lang="ts">
状态最小化，派生值用 computed，副作用用 watch
props down / events up；v-model 只给真正双向契约
标准 CRUD 使用 Search/AppTable/AppDialog/useCrudTable
```

### Next Canvas

```text
避免请求瀑布；独立请求 Promise.all
避免大型 barrel imports
RSC/SSR 不放 request-specific module mutable state
客户端状态按页面/组件边界收敛，不让全局 store 触发无关重渲染
```

## Completion rule

没有 fresh verification，不准说完成。

最终汇报必须有：

```text
Outcome
Changed files
Key evidence
Verification
Known risks
Next step
```

如果目标很大但本轮只是推进一批，明确说“本轮完成了什么，完整目标仍未闭环”。
