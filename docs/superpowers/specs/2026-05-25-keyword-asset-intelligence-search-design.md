# Keyword Vector Asset Search MVP Design Spec

状态：planned。本文只记录第一版“关键字/查询词检索我们的向量库”的设计；没有任何运行时代码、数据表、向量集合或前端页面已经实现。运行真相仍以 live runtime、smoke/test、`docs/status/current-status.md`、`docs/contracts/*` 和当前代码为准。

## 1. Outcome

第一版只做一个可验证闭环：

```text
管理员导入一批已授权文本/网页正文/证据材料
-> 后端把内容切成 chunk
-> 生成 embedding
-> 写入向量库
-> 用户输入关键字或自然语言查询
-> 后端生成 query embedding
-> 检索向量库
-> 返回命中的 chunk、来源 URL/域名/IP metadata、相似度和摘要
```

这个版本不做自动化爬虫，不做全网搜索，不做 DMCA notice，不做 provider-specific takedown adapter，不做 ASN/BGP 发现链路。它的目标是先证明“我们的向量库可查、结果可解释、数据可回溯”。

## 2. Why Narrow The Scope

用户只输入关键字时，如果系统没有自己的语料库，就会退化成“拿关键词撞搜索引擎 SEO 结果”。这不是目标产品。

正确顺序是：

```text
先有我们自己的向量语料库
-> 再做查询体验
-> 再做自动采集/爬虫给语料库喂数据
-> 最后做 hybrid search、取证、通知和处置闭环
```

因此第一版只解决最小真问题：**已有内容进库后能不能被查出来**。

## 3. Linus 三问

1. 这是真问题吗？是。没有可查的向量库闭环，后面的爬虫、取证和通知都没有落点。
2. 有更简单的方法吗？有。先做手动/seed 内容导入 + chunk + embedding + vector search，不先做 crawler、OpenSearch、Temporal、Kafka、Kubernetes 或 DMCA workflow。
3. 会破坏什么吗？不能破坏现有 admin 登录、RBAC、菜单、AI、支付、上传和队列。新模块应独立挂到 `/api/admin/v1/asset-intel`，按现有 Go 后端分层实现。

## 4. Current Project Facts

- 后端是 `admin_back_go`，Gin modular monolith，固定调用链为 `route -> handler -> service -> repository -> model`。
- 新后台 API 必须使用 `/api/admin/v1/<resource>`，不能继续旧 all-POST action URL。
- 当前已有 AI 知识库 RAG，但它是 AI agent 上下文检索，不是公开资产/证据材料检索；本模块不能把 AI 知识库表当资产库复用。
- 当前后端已有 MySQL、Redis、queue、AI provider 配置和 worker 边界。
- 前端是 `admin_front_ts`，新页面应使用 typed API、`Search`、`AppTable`、`AppDialog`、`useTable`/`useCrudTable` 和 Vue i18n。
- 文档治理要求：spec 是 planned，不得更新 `docs/status/current-status.md` 为 implemented，除非后续代码和 runtime 验证完成。

## 5. Product Boundaries

### 5.1 Search Page

第一版搜索页负责：

- 输入查询词，支持关键词或自然语言。
- 查询向量库并展示相似 chunk。
- 展示来源标题、来源 URL、域名、IP、ASN、source type、导入时间、相似度。
- 支持基础过滤：source type、domain、IP、ASN、导入时间、状态。
- 点击结果查看 chunk 上下文和来源 metadata。

第一版搜索页不负责：

- 自动爬取新网页。
- 自动创建搜索引擎任务。
- 发送 takedown notice。
- 判断法律侵权成立。

### 5.2 Corpus Management Page

第一版语料管理页负责：

- 手动创建 corpus。
- 导入文本、Markdown、URL metadata + text body、CSV/JSON seed。
- 查看导入状态、chunk 数、embedding 状态、失败原因。
- 删除或禁用 corpus/document/chunk。

第一版可以不做浏览器上传大文件。如果做文件导入，必须走现有上传能力或后端受控上传，不让前端直连第三方向量库。

### 5.3 Vector Indexing

第一版索引链路负责：

- 文本 normalize。
- chunk 切分。
- 调 embedding provider。
- 写 MySQL metadata。
- 写 Qdrant collection。
- 记录 embedding model、dimension、content hash 和 index version。

第一版不支持多 embedding model 混查。同一个 collection 必须固定 model 和 dimension。

## 6. Non-goals For MVP

第一版明确不做：

- 自动 crawler。
- 搜索引擎 SEO 候选发现。
- ASN/BGP 批量发现。
- RDAP/WHOIS 自动归因。
- CT Logs 自动发现域名。
- OpenSearch/BM25 hybrid search。
- 全互联网向量库。
- 端口扫描、漏洞扫描、目录爆破。
- DMCA notice 生成、发送、签名、授权管理。
- Cloudflare/registrar/hosting provider adapter。
- Kafka/Redpanda、Temporal、Kubernetes 编排。

这些是后续阶段，不进入第一版交付口径。

## 7. Recommended MVP Architecture

第一版采用 Go 后端 + MySQL metadata + Qdrant vector store。

选择 Qdrant 的原因：

- 不需要为了 pgvector 立即引入 Postgres，能贴合当前 MySQL 后端。
- 支持 payload metadata 和 filter，适合按 domain/IP/source/status 过滤。
- 向量数据和业务 metadata 解耦，后续可替换或并行接 pgvector。

边界：

```text
MySQL:
  corpus / document / chunk metadata
  import jobs
  source metadata
  vector point id

Qdrant:
  chunk embedding vector
  minimal payload for filtering and result display

AI provider:
  embedding model
  query embedding
  document embedding
```

## 8. Backend Module

模块名建议仍为 `assetintel`，但第一版只实现 vector search 子集。

```text
internal/module/assetintel
  route.go
  handler.go
  request.go
  service.go
  repository.go
  model.go
  dto.go
  errors.go
```

新增 platform 边界：

```text
internal/platform/vectorindex
  qdrant client wrapper
  collection ensure
  upsert points
  search points
  delete/disable points

internal/platform/embedding
  embedding provider wrapper
  model/dimension validation
  batch embedding
```

不要让 handler 直接调用 Qdrant 或 embedding provider。service 负责编排，repository 只维护 MySQL metadata。

## 9. Data Model

以下是设计级字段，不是最终 SQL。

### 9.1 `asset_intel_corpora`

用途：语料库主表。

字段：

- `id`
- `name`
- `description`
- `embedding_provider`
- `embedding_model`
- `embedding_dimension`
- `vector_collection`
- `status`: enabled/disabled
- `is_del`
- `created_by`
- `created_at`
- `updated_at`

### 9.2 `asset_intel_documents`

用途：导入文档/网页正文/证据材料主表。

字段：

- `id`
- `corpus_id`
- `source_type`: text/markdown/webpage/json/csv
- `title`
- `source_url`
- `domain`
- `ip`
- `asn`
- `content_hash`
- `text_content`
- `metadata_json`: only for explicit source metadata, not a fallback field
- `index_status`: pending/chunking/embedding/indexed/failed
- `error_message`
- `status`: enabled/disabled
- `is_del`
- `created_by`
- `created_at`
- `updated_at`

说明：`metadata_json` 只能保存明确的来源属性快照，例如原始导入文件名、外部 source id、evidence timestamp。不能用它吞未知 DTO。

### 9.3 `asset_intel_chunks`

用途：向量检索最小单位。

字段：

- `id`
- `corpus_id`
- `document_id`
- `chunk_index`
- `title`
- `content`
- `content_chars`
- `content_hash`
- `vector_point_id`
- `embedding_model`
- `embedding_dimension`
- `index_status`: pending/embedded/indexed/failed
- `error_message`
- `status`: enabled/disabled
- `is_del`
- `created_at`
- `updated_at`

### 9.4 `asset_intel_import_jobs`

用途：记录导入和索引任务。

字段：

- `id`
- `corpus_id`
- `source_type`
- `status`: pending/running/succeeded/failed/canceled
- `document_count`
- `chunk_count`
- `indexed_chunk_count`
- `failed_chunk_count`
- `error_message`
- `created_by`
- `created_at`
- `updated_at`

### 9.5 Qdrant Payload

Qdrant point payload 保持最小可过滤集合：

```json
{
  "corpus_id": 1,
  "document_id": 10,
  "chunk_id": 101,
  "source_type": "webpage",
  "domain": "example.com",
  "ip": "203.0.113.10",
  "asn": 64500,
  "status": "enabled",
  "created_at": "2026-05-25T00:00:00Z"
}
```

正文仍以 MySQL chunk 为准，Qdrant payload 不保存完整大正文。

## 10. API Contract Draft

第一版 REST 草案：

```text
GET    /api/admin/v1/asset-intel/search
GET    /api/admin/v1/asset-intel/corpora
POST   /api/admin/v1/asset-intel/corpora
GET    /api/admin/v1/asset-intel/corpora/:id
PUT    /api/admin/v1/asset-intel/corpora/:id
PATCH  /api/admin/v1/asset-intel/corpora/:id/status
DELETE /api/admin/v1/asset-intel/corpora/:id

GET    /api/admin/v1/asset-intel/documents
POST   /api/admin/v1/asset-intel/documents/import
GET    /api/admin/v1/asset-intel/documents/:id
PATCH  /api/admin/v1/asset-intel/documents/:id/status
DELETE /api/admin/v1/asset-intel/documents/:id

GET    /api/admin/v1/asset-intel/import-jobs
GET    /api/admin/v1/asset-intel/import-jobs/:id
POST   /api/admin/v1/asset-intel/import-jobs/:id/retry
```

`GET /search` query:

- `q`: required, 1-500 chars.
- `corpus_id`: optional.
- `source_type`: optional.
- `domain`: optional.
- `ip`: optional.
- `asn`: optional.
- `limit`: default 20, max 100.
- `min_score`: optional.

`GET /search` behavior:

- Does not crawl.
- Does not mutate state.
- Embeds the query using the corpus embedding model.
- Searches Qdrant.
- Loads chunk/document metadata from MySQL.
- Returns chunk excerpts, score, source metadata and trace id.

## 11. Jobs

第一版只需要导入和索引任务，不需要 crawler 任务。

任务类型建议：

```text
asset-intel:import-document:v1
asset-intel:index-document:v1
asset-intel:index-chunk-batch:v1
asset-intel:delete-vector-points:v1
```

任务原则：

- 幂等：同一 `content_hash + corpus_id` 不重复创建有效文档。
- 大文本不放 payload，只传 document id。
- embedding 失败要记录到 chunk 和 import job。
- batch embedding 必须有批大小、超时和重试上限。
- 删除文档时先软删 MySQL，再异步删除/禁用 Qdrant points。

## 12. Chunking And Embedding

默认策略：

- Normalize 换行和空白。
- 保留 URL、域名、品牌名、文件名。
- 默认 chunk size 800-1200 chars。
- 默认 overlap 100-150 chars。
- chunk 过短可合并。
- 每个 chunk 保存 `content_hash`，重复内容跳过或复用。

Embedding:

- 第一版复用现有 AI provider 边界或新增明确 embedding provider。
- collection 必须记录 model 和 dimension。
- 查询 corpus 时必须使用同一个 model。
- 不允许不同维度向量写入同一 collection。

## 13. Search Ranking

第一版只做向量相似度排序：

```text
final_score = vector_similarity_score
```

可选轻量加权：

```text
final_score =
  vector_similarity_score * 0.9
  + source_quality_score * 0.05
  + freshness_score * 0.05
```

不做 BM25，所以要明确限制：

- 精确域名、精确文件名、精确品牌词可能不如倒排索引稳定。
- 需要精确关键词能力时，Phase 3 加 OpenSearch hybrid search。

## 14. Security And Abuse Controls

第一版仍要有基本安全边界：

- 只允许导入用户有权处理的文本和网页正文。
- 不由后端主动访问外部 URL，避免第一版引入 SSRF 风险。
- 单次导入大小、文档数、chunk 数必须有限制。
- OperationLog 不捕获完整大正文。
- 前端不接触 Qdrant 或 embedding provider key。
- 搜索结果只展示当前用户有权限访问的 corpus。
- 删除/禁用 corpus 或 document 后，搜索结果必须不可见。

## 15. RBAC And Operation Log

建议权限码：

```text
assetIntel_search_view
assetIntel_corpus_view
assetIntel_corpus_add
assetIntel_corpus_edit
assetIntel_corpus_status
assetIntel_corpus_delete
assetIntel_document_view
assetIntel_document_import
assetIntel_document_status
assetIntel_document_delete
assetIntel_importJob_view
assetIntel_importJob_retry
```

OperationLog:

- 搜索 GET 默认不记录 response payload。
- corpus create/update/status/delete 记录。
- document import/status/delete 记录，但正文要摘要化或不捕获。
- import job retry 记录。

## 16. Frontend MVP

第一版页面：

```text
/asset-intel/search       向量检索
/asset-intel/corpora      语料库
/asset-intel/documents    文档/内容
/asset-intel/import-jobs  导入任务
```

页面规则：

- 列表页使用 `Search + AppTable + useTable`。
- CRUD 弹窗使用 `AppDialog + useCrudTable`。
- 所有可见文案进入 Vue i18n。
- 搜索结果要显示 score、source、domain/IP/ASN metadata、chunk excerpt。
- 空结果要说明“当前向量库没有命中”，不要提示系统会自动爬取。

## 17. Testing And Verification

Spec 后续进入实现计划时，最低验证应包括：

Backend:

```text
go test ./internal/module/assetintel -count=1
go test ./internal/platform/vectorindex -count=1
go test ./internal/platform/embedding -count=1
go test ./internal/jobs -count=1
go test ./internal/server -count=1
go test ./internal/bootstrap -count=1
go test ./internal/i18n -count=1
```

Frontend:

```text
npm run test -- tests/shared/asset-intel/*.test.ts
npx vue-tsc -b --pretty false
npm run build:check
```

Smoke:

- 登录后 `users/init` 返回资产情报菜单和按钮码。
- 创建 corpus 成功。
- 导入一条文本后生成 document/chunk。
- mock embedding + mock Qdrant 或本地 Qdrant 能完成 index。
- 搜索同义/相似查询返回预期 chunk。
- 禁用 document 后搜索不再返回该 chunk。
- 删除 corpus 后搜索不再返回相关 chunk。

Docs-only 验证：

```text
git diff --check
```

## 18. Rollback Plan

第一版实现应支持按层回滚：

- 菜单禁用：禁用资产情报菜单和权限授权，不影响其他模块。
- 向量库停用：搜索接口返回明确错误，不假装检索成功。
- Embedding provider 停用：导入任务进入 failed，并记录可见错误。
- 数据回滚：新增表独立命名 `asset_intel_*`，不改 AI、支付、用户、权限等已有业务表。
- Qdrant 回滚：MySQL metadata 保留，后续可重建 vector points。

## 19. Later Phases

Phase 2: 自动爬虫给向量库喂数据。

```text
seed URL/domain
-> crawler fetch HTML
-> extract readable text
-> document import
-> chunk + embedding
-> vector search
```

Phase 3: OpenSearch + vector hybrid search。

```text
BM25 exact keyword
+ vector semantic search
+ metadata filter
+ rerank
```

Phase 4: 资产归因和取证。

```text
CT Logs
RDAP
DNS history
ASN/BGP enrichment
evidence snapshot
```

Phase 5: DMCA/abuse/takedown workflow。

```text
rights owner authorization
evidence package
provider-specific adapter
notice tracking
removal verification
repeat offender escalation
```
