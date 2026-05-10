# AI Stream Timeout Governance Design

> 目标：把 AI 对话的流式超时从“30 秒 HTTP 总超时硬砍”改成分层治理：在线流式请求自己正确终止，`ai_run_timeout` 只做残留 `running` 兜底清理。只改超时治理，不新增运行监控字段，不新增表。

## 1. Linus 三问

1. 这是真问题吗？
   - 是。真实 run `ai-mozqkd4s-spbas04m` 在持续流式输出过程中被 30 秒 `http.Client.Timeout` 中断，错误为 `Client.Timeout or context cancellation while reading body`。这不是 WebSocket 断开，也不是 provider 整体不可用；同会话后续重发成功。
2. 有更简单的方法吗？
   - 有。不要用一个 30 秒 HTTP 总超时管理流式生成。拆成“连接/首包超时、流式 idle 超时、单轮最大生成时长、DB 残留清扫”四个职责。
3. 会破坏什么吗？
   - 不能破坏现有 WebSocket-only 对话、`ai_runs` / `ai_run_events` 终态、运行监控 token-only 合同、工具/RAG 运行链。设计保持现有表和状态枚举，只收紧超时边界。

## 2. 调研结论

### OpenAI / ChatGPT 方向

- Chat/Responses 流式输出是事件模型：过程事件多次出现，最后依赖 `completed` / `finish_reason` / `[DONE]` 这类终态。
- OpenAI Responses API 已提供 WebSocket Mode，用于长运行、工具调用链重的 workflow；连接有生命周期限制，断线后需要按 response id 或完整上下文恢复。
- Realtime API 也是 WebSocket 事件流：`delta` 是过程，`done/completed/error` 是终态。

参考：

- `https://developers.openai.com/api/docs/guides/streaming-responses`
- `https://developers.openai.com/api/docs/guides/websocket-mode`
- `https://developers.openai.com/api/docs/guides/realtime-websocket`

### 豆包 / 火山方舟方向

- Chat API 兼容 OpenAI：`stream=true` 后返回 `chat.completion.chunk` 分片，最后 `data: [DONE]`。
- 文档明确长文本、深度推理场景应调大 TTFT 和 TPOT，避免流式请求因超时中断。
- 流式调用默认 usage 可能为 `null`，如需统计 token 要开启 `stream_options.include_usage=true`。

参考：

- `https://www.volcengine.com/docs/82379/2123275`
- `https://www.volcengine.com/docs/82379/1494384`
- `https://www.volcengine.com/docs/82379/1599499`
- `https://www.volcengine.com/docs/82379/1330626`

## 3. 当前项目问题

### 已确认根因

当前链路里有两个互相打架的超时：

```text
admin-api reply dispatcher: 2m
OpenAI-compatible HTTP client: 30s total timeout
```

真正砍断流的是 `http.Client.Timeout=30s`。Go `http.Client.Timeout` 覆盖从发起请求到读取响应 body 的整个生命周期；它适合普通短 HTTP 请求，不适合持续读 SSE / chunked response。

关键代码：

- `admin_back_go/internal/platform/ai/openaicompat/client.go`
  - `defaultTimeout = 30 * time.Second`
  - `http.Client{Timeout: timeout}`
  - `StreamChat` 复用该 client 读取流式 body
- `admin_back_go/internal/bootstrap/app.go`
  - `aiChatEngineFactory` 给 OpenAI-compatible client 写死 `Timeout: 30 * time.Second`
- `admin_back_go/internal/bootstrap/ai_reply_dispatcher.go`
  - dispatcher 最大执行时间是 2 分钟，但被内层 HTTP client 提前截断

### 当前 `ai_run_timeout` 问题

项目已有定时调度器和 `ai_run_timeout`：

```text
cron_task.name = ai_run_timeout
registry task type = ai:run-timeout:v1
handler = aichat.TimeoutRuns
```

但当前 repository 查询只按：

```sql
WHERE status = 'running'
```

没有 `started_at` 年龄条件。这个实现会误伤正在正常生成的 run。调度器只能做残留清理，不能接管在线请求超时。

## 4. 范围

### In

- OpenAI-compatible `StreamChat` 不再使用 30 秒总 HTTP timeout。
- 流式读取增加 idle timeout：超过一段时间没有任何上游流事件，才判定卡死。
- 单轮 AI 回复增加最大生成时长，由 dispatcher context 控制。
- `ai_run_timeout` worker 只扫描超过 stale age 的 `running` run。
- Chat Completions 请求开启 `stream_options.include_usage=true`，让已有 token 字段尽量拿到 usage。
- 更新 backend config、测试、契约文档和 smoke 说明。

### Out

- 不新增表。
- 不新增 `ai_runs` 字段。
- 不新增 run 状态；仍使用 `running/success/failed/canceled/timeout`。
- 不把 WebSocket delta 入库。
- 不保存 partial assistant message。
- 不切换到 OpenAI Responses API / WebSocket Mode；这属于未来 provider adapter 升级，不是本修复。
- 不修改前端 UI 布局。

## 5. 配置设计

新增 `config.AIConfig`，三个字段全部使用：

| 配置 | 默认值 | 使用位置 | 用途 |
| --- | --- | --- | --- |
| `AI_CHAT_STREAM_MAX_DURATION` | `5m` | `aiConversationReplyDispatcher` | 单轮 AI 回复最大运行时间。到了就取消 context，`ai_runs.status=timeout`。 |
| `AI_CHAT_STREAM_IDLE_TIMEOUT` | `60s` | `openaicompat.Client.StreamChat` | 流式读取中，超过该时间没有任何上游事件/行就关闭响应体并返回 timeout。覆盖 TTFT 和 TPOT 卡死。 |
| `AI_RUN_STALE_TIMEOUT` | `15m` | `aichat.TimeoutRuns` | `ai_run_timeout` 扫描 `started_at < now - stale` 的残留 `running`。 |

派生规则：

```text
dispatcher_timeout = AI_CHAT_STREAM_MAX_DURATION + 30s
```

原因：外层 dispatcher 应该比 provider 生成窗口略长，给 `FinishRun`、事件写入、WebSocket failed/completed 发送留出空间。

## 6. Runtime 设计

### 6.1 OpenAI-compatible stream client

`openaicompat.Client` 拆成普通请求和流式请求两类：

```text
TestConnection / 短请求 -> http.Client{Timeout: Timeout}
StreamChat              -> streamHTTPClient，不设置 Client.Timeout
```

流式请求靠两层控制：

```text
context deadline      -> 单轮最大生成时长
idle timer + body.Close -> 上游长时间无事件
```

流式读取规则：

1. 发请求前使用外层 `ctx`，该 ctx 来自 dispatcher。
2. `StreamChat` 成功拿到响应头后启动 idle timer。
3. 每读到一行 SSE 数据、注释、空行或 chunk，都刷新 idle timer。
4. 如果 idle timer 触发，关闭 `resp.Body`，让 scanner/reader 退出。
5. 如果退出原因是 idle timer，返回 `context.DeadlineExceeded` 包装错误。
6. 如果 `ctx.Done()`，返回原始 context 错误，供 `aichat.statusFromError` 映射 `canceled/timeout`。

### 6.2 stream usage

Chat Completion 请求体新增：

```json
"stream_options": { "include_usage": true }
```

现有 `readChatCompletionStream` 已能读取 `chunk.Usage` 并写入 `ChatResult`，所以不需要新增 DB 字段。

### 6.3 dispatcher

`newAIConversationReplyDispatcher` 使用配置计算出的 timeout：

```text
AI_CHAT_STREAM_MAX_DURATION + 30s
```

取消行为不变：

- 用户主动取消：`context.Canceled` -> `status=canceled`
- 到达最大生成时长：`context.DeadlineExceeded` -> `status=timeout`
- 上游 idle timeout：`context.DeadlineExceeded` -> `status=timeout`

### 6.4 ai_run_timeout sweeper

`aichat.TimeoutRuns` 改成 stale-only：

```sql
SELECT *
FROM ai_runs
WHERE status = 'running'
  AND started_at IS NOT NULL
  AND started_at < ?
ORDER BY id ASC
LIMIT ?
```

`? = now - AI_RUN_STALE_TIMEOUT`

终态更新必须保持 compare-and-set：

```sql
UPDATE ai_runs
SET status='timeout',
    finished_at=?,
    duration_ms=?,
    error_message='AI运行残留超时'
WHERE id=? AND status='running'
```

只有 `RowsAffected=1` 时才插入 `ai_run_events.timeout`，避免并发下在线请求已经成功后又补一个 timeout 事件。

## 7. 运行监控展示影响

不新增字段。现有展示继续使用：

- `status`
- `duration_ms`
- `error_message`
- `prompt_tokens`
- `completion_tokens`
- `total_tokens`
- `ai_run_events`
- `tool_calls`
- `knowledge_retrievals`

行为变化：

- 连续流式输出超过 30 秒不应失败。
- 真正静默超过 idle timeout 才失败。
- 进程崩溃/重启留下的 `running` 由 worker 稍后标成 `timeout`。

## 8. 错误语义

| 场景 | run status | event | 前端 WebSocket |
| --- | --- | --- | --- |
| 正常完成 | `success` | `completed` | `ai.response.completed.v1` |
| 用户取消 | `canceled` | `canceled` | `ai.response.failed.v1` 或本地停止忽略迟到事件，保持现有合同 |
| 单轮最大生成时长到期 | `timeout` | `timeout` | `ai.response.failed.v1`，message 为超时原因 |
| 上游长时间无任何流事件 | `timeout` | `timeout` | `ai.response.failed.v1`，message 为上游流式 idle 超时 |
| provider 4xx/5xx | `failed` | `failed` | `ai.response.failed.v1` |
| 进程崩溃留下 running | `timeout` | `timeout` | 无实时事件；运行监控可见 |

## 9. 测试设计

Backend focused tests：

1. `openaicompat`：连续流式输出超过 `Timeout` 仍成功，证明流式不再受 HTTP 总超时控制。
2. `openaicompat`：响应头已返回但长时间没有任何行，触发 idle timeout。
3. `openaicompat`：请求体包含 `stream_options.include_usage=true`。
4. `aichat.Repository.TimeoutRuns`：未超过 stale age 的 `running` 不被扫。
5. `aichat.Repository.TimeoutRuns`：超过 stale age 的 `running` 被标 `timeout` 并写事件。
6. `aichat.Repository.finishRun`：`RowsAffected=0` 时不插入终态事件。
7. `config.Load`：三个 AI timeout 配置默认值和 env 覆盖生效。
8. `bootstrap`：dispatcher timeout 使用 `AI_CHAT_STREAM_MAX_DURATION + 30s`。

Smoke / manual：

1. 模拟或真实 provider 输出超过 30 秒，最终 `ai_runs.status=success`。
2. 人为制造旧 `running` run，启动 worker 后只清理超过 `AI_RUN_STALE_TIMEOUT` 的行。

## 10. 验收标准

- `StreamChat` 不再因为 30 秒总 HTTP timeout 中断正在输出的响应。
- 静默上游会在 `AI_CHAT_STREAM_IDLE_TIMEOUT` 后变成 `timeout`。
- `ai_run_timeout` 不会误杀正在运行但未超过 stale age 的 run。
- `ai_runs` / `ai_run_events` 没有新增字段，运行监控页面无需新增展示字段。
- token usage 仍写入现有 `prompt_tokens/completion_tokens/total_tokens`。
- 后端 tests、contract check 通过。
