# AI runtime timeout env 收口设计

日期：2026-05-20
状态：draft
范围：`admin_back_go` AI 对话流式超时、AI run 残留清理窗口、Docker-first env 模板、相关契约文档和测试

## 目标

这次只做 **AI runtime timeout env cleanup**，不重做 AI provider、agent、chat、run monitor、tool、knowledge RAG，不改前端 AI 对话协议。

要达到的结果：

1. Docker-first env 删除 AI runtime timeout 三个策略项，让 env 更短。
2. `AI_CHAT_STREAM_MAX_DURATION`、`AI_CHAT_STREAM_IDLE_TIMEOUT`、`AI_RUN_STALE_TIMEOUT` 的默认值改为代码内置。
3. 不把这三个值导入 `system_settings`，避免后台用户误调运行时保护阈值。
4. 保持现有默认行为不变：单轮 AI 回复最长 `5m`、上游流式空闲超时 `60s`、残留 running run 清理窗口 `15m`。
5. 保持 `admin-api` 在线回复和 `admin-worker` stale-run sweeper 的职责边界不变。

## Linus 三问

1. 这是真问题吗？
   - 是。当前 Docker-first env 暴露三个 `AI_*TIMEOUT` 键，它们不是部署连接信息，也不是业务运营配置。普通部署用户看到后很难判断该不该改；改错可能导致 AI 回复被过早取消、上游卡死长时间占资源，或 stale run 太早/太晚被标记 timeout。
2. 有更简单的做法吗？
   - 有。把三个默认值收回代码常量；不新增后台配置、不新增 SQL、不新增 system setting。
3. 会破坏已有前端、接口、登录和权限吗？
   - 不应该。AI conversation WebSocket envelope、provider 调用、run monitor 数据结构、worker handler、权限和菜单都不变；只改变默认值来源和 Docker-first env 暴露面。

## 当前事实

Docker-first env 当前暴露：

```env
AI_CHAT_STREAM_MAX_DURATION=5m
AI_CHAT_STREAM_IDLE_TIMEOUT=60s
AI_RUN_STALE_TIMEOUT=15m
```

这些键当前被 `internal/config.Load()` 读取到 `config.AIConfig`：

| env key | 当前含义 | 运行时使用点 | 判断 | 目标 |
| --- | --- | --- | --- | --- |
| `AI_CHAT_STREAM_MAX_DURATION` | 单轮 AI 回复最长运行时间 | `aiConversationReplyDispatcher` 创建 timeout context | 运行时保护阈值；不是后台业务配置 | 内置 `5m` |
| `AI_CHAT_STREAM_IDLE_TIMEOUT` | 上游流式响应空闲超时 | `openaicompat.Client.StreamChat` idle watcher | 上游连接保护阈值；误调风险高 | 内置 `60s` |
| `AI_RUN_STALE_TIMEOUT` | 残留 `running` run 判定窗口 | `aichat.TimeoutRuns` / `ai:run-timeout:v1` worker handler | 后台清理保护阈值；不是 scheduler cron 配置 | 内置 `15m` |

现有运行时职责：

- `admin-api` 收到 AI 对话消息后，通过 reply dispatcher 异步处理本轮回复。
- `AI_CHAT_STREAM_MAX_DURATION` 控制本轮 reply dispatcher 的最长运行时间；当前实际 timeout 是 `max_duration + 30s` 的保护余量。
- `AI_CHAT_STREAM_IDLE_TIMEOUT` 控制 OpenAI-compatible stream 读取时上游多久不返回新数据就关闭响应体。
- `admin-worker` 的 `ai:run-timeout:v1` 只扫描并标记残留 `running` 行，不负责正常在线流式回复的即时超时。
- `AI_RUN_STALE_TIMEOUT` 只影响 stale-run sweeper 的 `started_at < now - timeout` 判定窗口。

## 选型

### 方案 A：迁到 `system_settings`

不推荐。

原因：

- 这三个值都是运行时保护阈值，不是业务运营策略。
- 在线 AI 回复和 worker sweeper 都在服务运行链路中使用这些值；把它们放到 DB 设置会增加启动期/运行期读取复杂度。
- 后台可编辑会带来误调风险：例如 idle timeout 太大，上游卡死会长时间占 goroutine；太小会让慢模型频繁 timeout。
- `system_settings` 适合验证码 TTL、上传 token TTL 这类产品策略，不适合 AI 流式连接保护参数。

### 方案 B：继续保留 env

不采用。

原因：

- Docker-first env 继续变长，违背“只让部署者改必要项”的方向。
- 三个值当前默认已经合理，普通部署场景没有每次部署都暴露的必要。
- env 暴露会让用户误以为这是日常应调参数；实际它们更像代码侧稳定性 guardrail。

### 方案 C：代码内置默认值，Docker-first env 删除（推荐）

内容：

Docker-first env 删除：

```env
AI_CHAT_STREAM_MAX_DURATION
AI_CHAT_STREAM_IDLE_TIMEOUT
AI_RUN_STALE_TIMEOUT
```

代码内置：

```text
DefaultAIChatStreamMaxDuration = 5m
DefaultAIChatStreamIdleTimeout = 60s
DefaultAIRunStaleTimeout = 15m
```

优点：

- env 一次减少 3 个键。
- 默认行为完全不变。
- 不引入 DB/system_settings 依赖。
- 运行时保护阈值由代码和测试守住，避免后台误调。

缺点：

- 极少数部署如确实需要按硬件/模型特性调长 timeout，不能再只靠 Docker-first env 改；应另开“高级 AI runtime policy”设计，而不是在普通 Docker-first env 里继续暴露。

推荐采用。

## 推荐设计

### 1. Docker-first env 删除三个 AI timeout key

最终 Docker-first env 不再出现：

```env
AI_CHAT_STREAM_MAX_DURATION=5m
AI_CHAT_STREAM_IDLE_TIMEOUT=60s
AI_RUN_STALE_TIMEOUT=15m
```

说明：

- 这三个值不是部署连接信息。
- 不影响 AI provider API key、base URL、模型等业务配置；这些仍按现有 AI provider 表/后台配置处理。
- 不影响 queue、scheduler、realtime、CORS、Redis、MySQL 等部署项。

### 2. AI runtime timeout policy 代码内置

建议在 `internal/config` 或更贴近 AI runtime 的包中集中定义默认值，避免散写：

```text
DefaultAIChatStreamMaxDuration = 5 * time.Minute
DefaultAIChatStreamIdleTimeout = 60 * time.Second
DefaultAIRunStaleTimeout = 15 * time.Minute
```

注意：

- `config.Load()` 不再读取 `AI_CHAT_STREAM_MAX_DURATION`、`AI_CHAT_STREAM_IDLE_TIMEOUT`、`AI_RUN_STALE_TIMEOUT`。
- 即使外部环境变量仍设置了旧 key，也应该被忽略，防止部署残留继续改变行为。
- `AIConfig` 零值进入 bootstrap 时仍必须归一化到默认值，避免测试或直接构造路径出现 `0`。
- `openaicompat.Client` 现有 `defaultStreamIdleTimeout=60s` 可以保留，但 bootstrap 侧传入值也要来自统一默认。
- `aichat.Service` 现有 `defaultRunStaleTimeout=15m` 可以保留，但外部注入值和 service 内部 fallback 要一致。

### 3. 不进 `system_settings`

本切片不新增 SQL/migration，不新增系统设置 key。

明确不新增：

```text
ai.chat.stream_max_duration
ai.chat.stream_idle_timeout
ai.run.stale_timeout
```

理由：

- 这三个值是运行时稳定性 guardrail，不是普通后台配置。
- 后台设置页不应出现“AI 流式空闲超时”“AI run 残留窗口”这类实现细节。
- 如果未来要产品化“AI 回复最大等待时间”，需要单独设计用户体验、错误提示、模型差异和 per-agent/per-provider 策略，不能直接把底层 timeout 暴露出来。

### 4. 运行时行为不变

不改：

- AI 对话 WebSocket path、事件 envelope、权限、菜单。
- provider stream 读取逻辑。
- `ai_runs` / `ai_run_events` schema。
- run monitor 展示字段。
- `ai:run-timeout:v1` task type 和 worker handler。
- `cron_task` 中 `ai_run_timeout` 的启用和 cron 表达式。
- queue 和 scheduler 的已有配置。

### 5. 文档同步收口

需要同步 active docs：

- `admin_back_go/deploy/docker-first/admin-go.env.example`
- 本地 ignored 的 `admin_back_go/deploy/docker-first/admin-go.env` 如果存在
- `admin_back_go/docs/architecture.md`
- `admin_back_go/README.md` 如存在 active env 列表
- `docs/contracts/admin-api-v1.md`
- `docs/testing/smoke-matrix.md`
- `docs/status/current-status.md`

文档口径改为：

```text
AI chat stream max duration, stream idle timeout, and stale-run timeout are code-owned runtime guardrails.
Docker-first env does not expose these knobs.
ai_run_timeout remains a stale-run sweeper only, not the online reply timeout mechanism.
```

历史 spec/plan 中记录旧 env 的文件不强制回改；active docs、deploy 模板和测试必须清干净。

## 迁移范围

### 需要改

后端仓 `admin_back_go`：

- `internal/config/config.go`
- `internal/config/config_test.go`
- `internal/bootstrap/app.go`
- `internal/bootstrap/worker.go`
- `internal/bootstrap/ai_reply_dispatcher_test.go` 如默认值归一化断言需要调整
- `internal/platform/ai/openaicompat/client.go` / tests 如默认值口径需要集中
- `internal/module/aichat/service.go` / tests 如 stale timeout fallback 需要集中
- `deploy/docker-first/admin-go.env.example`
- 本地 ignored 的 `deploy/docker-first/admin-go.env` 如果存在
- `docs/architecture.md`
- `README.md` 如有 active env 描述

根仓 `admin_go`：

- `docs/contracts/admin-api-v1.md`
- `docs/testing/smoke-matrix.md`
- `docs/status/current-status.md`
- 其他 active env 清单，如存在 `AI_CHAT_STREAM_*` / `AI_RUN_STALE_TIMEOUT`

### 不需要改

- 不改前端。
- 不新增 SQL/migration。
- 不新增 `system_settings` 数据。
- 不改 AI provider / agent / tool / knowledge / run monitor 的业务字段。
- 不改 `cron_task` 表、seed 或页面。
- 不改 `QUEUE_*`、`SCHEDULER_*`、`REALTIME_*`、`TOKEN_*`、`MYSQL_*`、`REDIS_*`、`CORS_*`。
- 不把 AI timeout 做成后台可编辑项。

## 兼容与风险

### 部署残留 env

实现后，即使旧部署环境还留着：

```env
AI_CHAT_STREAM_MAX_DURATION=3m
AI_CHAT_STREAM_IDLE_TIMEOUT=45s
AI_RUN_STALE_TIMEOUT=20m
```

也不会再影响运行时。测试要覆盖“旧 env 被忽略”。

### 默认值漂移

默认值不能散落在多处独立维护。

如果实现阶段保留多个包内 fallback，必须测试它们和 config 默认值一致；否则后续维护容易出现 `config=5m`、service fallback=15m 这类漂移。

### 在线回复 timeout 与 stale-run timeout 的区别

文档必须继续强调：

- 在线回复最大时长：`AI chat stream max duration` 的代码默认值。
- 上游静默卡死：`AI chat stream idle timeout` 的代码默认值。
- `ai_run_timeout`：只清理历史残留 `running` 行。

不能把 `ai_run_timeout` 写成“用户当前聊天等待时间”。

### 高级部署诉求

如果未来需要可配置 AI runtime policy，应另开设计，先回答：

- 是全局配置、provider 配置、agent 配置，还是模型级配置？
- 是否允许后台热更新？
- 已运行中的 stream 是否受影响？
- timeout 后前端提示和 run event 怎么表达？
- 是否要限制最大/最小值？

本切片不提前扩展。

## 测试计划

后端测试：

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/config ./internal/bootstrap ./internal/platform/ai/openaicompat ./internal/module/aichat
go test -count=1 ./cmd/admin-worker ./internal/jobs ./internal/platform/taskqueue
```

静态检查：

```powershell
cd E:\admin_go\admin_back_go
go vet ./internal/config ./internal/bootstrap ./internal/platform/ai/openaicompat ./internal/module/aichat
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose config --quiet
```

repo 治理：

```powershell
cd E:\admin_go
rg -n "AI_CHAT_STREAM_MAX_DURATION|AI_CHAT_STREAM_IDLE_TIMEOUT|AI_RUN_STALE_TIMEOUT" admin_back_go/deploy admin_back_go/docs admin_back_go/README.md docs/contracts docs/testing docs/status --glob "!**/*.map"
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

期望：

- deploy/env/example/active docs 中不再把三项作为可配置 env。
- 旧历史 spec/plan 中出现旧 env 不算失败。
- config 测试覆盖默认值和旧 env 忽略。
- bootstrap/service/client 测试证明零值归一化仍保持 `5m`、`60s`、`15m` 行为。

## 验收标准

1. Docker-first env/example 删除三个 AI timeout env。
2. 代码不再读取这三个 env。
3. 旧 env 即使存在也被忽略。
4. 默认行为保持：`5m` / `60s` / `15m`。
5. 不新增 `system_settings` 和 SQL migration。
6. active docs 不再要求用户配置这三个 env。
7. 后端相关测试、`go vet`、`docker compose config --quiet`、governance check 通过。

## Spec 自查

- 内容完整，无未决项。
- 范围只覆盖 AI runtime timeout env 收口。
- 明确不进 `system_settings`。
- 明确不改前端、不改业务 AI 模块、不改 cron task。
- 默认值、使用点、测试计划和验收标准一致。
