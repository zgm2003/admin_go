# Technology Decision

## 当前定稿

主后端选 Go。这个决定已经定，不再在 Java / Python / Go 之间反复横跳。

```text
Main admin backend: Go
AI application sidecar: Python only when model/tool ecosystem needs it
Frontend: existing admin_front_ts, adapt step by step
Java: not used as the main rewrite line
```

## 为什么这样分工

Go 负责长期运行的后台系统：

```text
REST API
WebSocket realtime
RBAC
queue workers
cron jobs
middleware
logging and audit
```

新项目不再规划 SSE。AI 回复、通知、进度输出统一走 WebSocket message envelope；如果未来接 OpenAI Realtime，服务端也优先按官方 WebSocket/WebRTC 思路对齐。

Python 只负责 AI 生态更强的部分：

```text
LLM workflow
RAG
embedding
model adapters
AI tool services
```

不要把 Python 当 admin 主后端，也不要把 Go 写成 Java 企业八股。

## Go 项目铁律

```text
少层级
少抽象
先跑通
再提炼
尊重开源
不闭门造车
```

禁止 Java 味目录污染 Go：

```text
ServiceImpl
Manager
Factory
BO
VO
Converter everywhere
AbstractBaseWhatever
```

默认 Go 调用链保持简单：

```text
route -> handler -> service -> repository -> model
```

如果某一层没有真实价值，就不要为了“规范”硬加。

## 当前阶段限制

这个文件只记录技术选择。它不代表可以立刻初始化 Go 项目。

下一步仍然是：

```text
Phase 1: open-source research
```

研究完优秀开源 admin / RBAC / 前端权限模型后，才进入：

```text
Phase 2: minimal Go skeleton
```
