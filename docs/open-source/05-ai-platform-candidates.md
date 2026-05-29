# AI Platform Open Source Candidates

Status: researched on 2026-05-08 for the AI core rebuild; runtime boundary refreshed on 2026-05-29. This file records sources and adoption boundaries; it is not an implementation claim. Current implemented AI runtime facts live in `docs/status/module-matrix.md` and `admin_back_go/docs/architecture.md`.

## Problem

Historical starting point: the early AI slice had Go-owned config/agent/knowledge/chat/run plans but was not yet a real AI platform. Current runtime has moved on: `internal/module/ai/{provider,agent,tool,image,knowledge,conversation,message,chat,run}` is active, provider calls go through `internal/infra/ai`, and production chat must fail explicitly when no enabled provider/agent exists. Do not use this research note to override current runtime facts.

The intended product surface is deliberately boring and complete:

```text
供应商配置 -> engine/provider connections
智能体配置 -> local AI agents bound to provider models and future workflow engines
AI 对话     -> admin_go chat page + local conversation/message/run mirror
知识库       -> local RAG first; future sidecar dataset/document sync only after a new spec
运行监控     -> local runs/events/usage mirror
AI 工具管理  -> local tool maps + safe workflow references
```

Any candidate that cannot cover this surface without leaking third-party secrets into Vue is not acceptable for phase one.

## Candidate Summary

| Candidate | What it gives us | Fit | Decision |
| --- | --- | --- | --- |
| Dify sidecar | Agentic workflow, RAG pipelines, integrations/tools, model access, observability, app APIs | Good future sidecar if local Go AI features stop being enough | Not active runtime; introduce only with a new spec/plan behind `internal/infra/ai` |
| CloudWeGo Eino | Go-native ChatModel/Tool/Retriever/Embedding abstractions, ADK, graph/workflow composition, streaming/callbacks | Best Go-native future embedded engine | Keep as future engine path; do not block current OpenAI-compatible runtime on it |
| RAGFlow | Strong document/RAG engine, deep document understanding, dataset-oriented APIs | Good future knowledge-base sidecar for heavy PDFs/OCR/table docs | Not phase one; introduce only when Dify knowledge/doc ability is insufficient |
| OpenAI official Go SDK | Direct Responses API, streaming, tool calling from Go | Useful for direct OpenAI-compatible/native provider implementation | Keep as small direct-provider option, not as the whole platform |
| LangChainGo | General Go LLM framework | Less targeted than Eino for this repo's Go-native path | Do not select as default |

## Source Notes

Live source check on 2026-05-08 used primary project/docs pages only; it was refreshed on 2026-05-09 against Dify docs, CloudWeGo Eino docs/GitHub, and RAGFlow public sources. The result does not make `admin_go` depend on Dify internals; it only confirms the sidecar/API boundary.

### Dify

Dify's public site says it provides agentic workflows, RAG pipelines, integrations, and observability in one product, and also highlights access/switch/compare across LLMs. This maps directly to the user-visible modules we need: provider/model configuration, agent/workflow configuration, knowledge base, tools, chat runtime, and monitoring.

Sources:
- https://dify.ai/
- https://github.com/langgenius/dify
- Dify API docs for chat messages: https://docs.dify.ai/api-reference/chat/send-chat-message
- Dify API docs for stop generation: https://docs.dify.ai/api-reference/chat/stop-chat-message-generation
- Dify API docs for text document creation: https://docs.dify.ai/en/guides/knowledge-base/knowledge-and-documents-maintenance/maintain-dataset-via-api

API facts used in the design:

```text
POST /chat-messages is the chat runtime boundary; admin_go sends query/inputs/user/response_mode/conversation_id/files and consumes JSON or SSE depending response_mode.
response_mode=streaming returns text/event-stream ChunkChatEvent objects; task_id/message_id/conversation_id/metadata.usage are the minimum fields admin_go mirrors.
POST /chat-messages/{task_id}/stop is the cancel boundary and is streaming-only; the same stable user key must be sent.
Knowledge document sync uses POST /datasets/{dataset_id}/document/create-by-text; creation is asynchronous and returns document + batch, so admin_go must store engine_document_id/batch/indexing_status locally.
Dify API keys stay server-side; Vue never receives a Dify key.
```

Adoption boundary:

```text
Dify is an AI engine, not the admin backend.
admin_go keeps users, RBAC, menus, operation logs, route contracts, smoke gates, and product pages.
Dify is a future sidecar candidate only; it owns model/workflow/RAG/tool internals only after a new spec/plan explicitly adopts it.
admin_go would still store engine connection, app mappings, local conversation/run/event mirrors, and user-facing permissions.
```

Do not directly expose the Dify console as the product UI. If Dify console is used during early setup, it is an operator/admin escape hatch, not the final admin_go UX.

### CloudWeGo Eino

Eino is explicitly a Go LLM application framework. Its README lists reusable components such as `ChatModel`, `Tool`, `Retriever`, `ChatTemplate`, an Agent Development Kit, graph/workflow composition, stream processing, callbacks/tracing/metrics, and interrupt/resume.

Sources:
- https://github.com/cloudwego/eino
- https://www.cloudwego.io/docs/eino/

Adoption boundary:

```text
Eino is the Go-native embedded engine path.
It is not phase-one required while the OpenAI-compatible provider boundary is enough.
The Go `AIEngine` interface must be small enough that OpenAI-compatible, DifyEngine, and EinoEngine can all implement it later.
```

### RAGFlow

RAGFlow describes itself as an open-source RAG engine with Agent capabilities and a context layer for LLMs. Its README emphasizes deep document understanding, template-based chunking, grounded citations, heterogeneous data sources, and RAG workflow orchestration.

Sources:
- https://github.com/infiniflow/ragflow
- https://ragflow.io/

Adoption boundary:

```text
RAGFlow is a future specialized knowledge/RAG sidecar.
Do not add it in the first rebuild unless Dify cannot satisfy document ingestion/retrieval requirements.
```

### OpenAI official Go SDK

The OpenAI Go library provides Go access to the OpenAI REST API, uses the Responses API as the primary model interface, supports streaming responses, and demonstrates tool calling.

Sources:
- https://github.com/openai/openai-go
- https://platform.openai.com/docs/api-reference/streaming

Adoption boundary:

```text
Use it only for a direct OpenAI/native engine implementation or focused tests.
Do not use raw OpenAI SDK calls inside `module/ai/chat`; keep calls behind `internal/infra/ai`.
```

## Final Decision

Current product direction:

```text
admin_go + local Go AI modules + OpenAI-compatible provider boundary in internal/infra/ai.
```

Fallback/future direction:

```text
Add Dify/Eino/RAGFlow later only behind internal/infra/ai and without changing admin_go REST or Vue pages.
```

Hard rule:

```text
No AI business module may call Dify/OpenAI/Eino SDKs directly. Runtime calls go through `internal/infra/ai` interfaces, and business state is mirrored in local MySQL tables owned by admin_go.
```
