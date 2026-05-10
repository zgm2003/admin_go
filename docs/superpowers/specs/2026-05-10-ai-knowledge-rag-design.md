# AI Knowledge Base RAG Design Spec

状态：implemented and verified on 2026-05-10. 本文保留知识库重构设计取舍；运行真相以 live DB、`docs/migration/current-status.md`、`docs/contracts/admin-api-v1.md` 和当前代码为准。

## 1. Outcome

重构 `/ai/knowledge` 为 admin_go 本地知识库模块：知识库管理页维护知识库、文档、分块和检索测试；智能体配置页决定每个智能体能读取哪些知识库；AI 对话在调用模型前执行本地检索，把命中的片段注入本轮用户上下文；运行监控展示本轮知识库检索和命中链路。

第一版不引入独立向量数据库，不接 OpenAI hosted vector store，不复活旧 Dify/RAGFlow dataset map 壳子。检索采用 MySQL 持久化分块 + Go 内部评分，满足当前项目架构知识库和小中型文本知识库的可用闭环。

## 2. Linus 三问

1. 这是真问题吗？是。当前 AI provider / agent / chat / run / tool 已经成链，最后缺的是“智能体读取项目知识”的 RAG 闭环；live DB 当前没有 `ai_knowledge_*` 表，但代码里还残留 `aiknowledgemap`，这是运行时和代码不一致。
2. 有更简单的方法吗？有。先做本地 MySQL 分块检索，不引入 Qdrant/Milvus/pgvector，不让供应商 dataset 概念污染本地智能体配置。
3. 会破坏什么吗？不能破坏现有 `/ai/providers`、`/ai/agents`、`/ai/tools`、`/ai/runs`、`/ai/chat` 路径和 WebSocket 对话；新增知识库只在 agent 绑定后影响对应智能体，默认不绑定则不改变聊天行为。

## 3. Current project facts

- AI 产品菜单事实：`/ai/providers`、`/ai/agents`、`/ai/knowledge`、`/ai/tools`、`/ai/runs`、`/ai/chat`。
- 当前 live DB 事实：`ai_agents`、`ai_conversations`、`ai_messages`、`ai_runs`、`ai_run_events`、`ai_tools`、`ai_agent_tools`、`ai_tool_calls` 已存在；本次迁移已新增并入库 `ai_knowledge_bases`、`ai_knowledge_documents`、`ai_knowledge_chunks`、`ai_agent_knowledge_bases`、`ai_knowledge_retrievals`、`ai_knowledge_retrieval_hits`。
- 当前代码事实：active backend 是 `internal/module/aiknowledge`，active frontend API 是 `src/api/ai/knowledge.ts`；旧 `internal/module/aiknowledgemap` 和 `src/api/ai/knowledgeMaps.ts` 已从 active workspace 删除。旧 `/ai-knowledge-maps` 精确字符串只允许留在 negative tests 或历史设计文档里。
- 当前聊天执行链：`aichat` 创建 `ai_runs`，加载智能体和工具，调用 provider，保存助手消息，完成 run。知识库检索应插入在第一次 `StreamChat` 前。

## 4. External practice summary

- OpenAI File Search / Retrieval 的主线是 vector store + file_search tool；它适合直接采用 Responses API hosted retrieval，但会改变当前 OpenAI-compatible Chat Completions 边界。
- OpenAI Embeddings 文档建议大量向量快速检索时使用向量数据库；当前项目第一版数据规模和运维阶段不需要单独引入向量库。
- Dify/RAGFlow 都把知识库做成 dataset / document / chunk / retrieval 体系。可借鉴对象模型，不照搬外部 dataset id 作为本地核心字段。

采用点：知识库、文档、分块、智能体绑定、运行时检索记录。

不采用点：外部 dataset 映射为核心、浏览器直接调用供应商、独立向量库、供应商 hosted file_search、异步 sidecar。

## 5. Product boundaries

### 5.1 知识库管理页负责

- 知识库 CRUD、启用/禁用、删除。
- 文档 CRUD、启用/禁用、删除。
- 文档重建分块。
- 检索测试。
- 查看分块。
- 初始化项目架构知识库内容。

### 5.2 智能体配置页负责

- 配置当前智能体可读取哪些知识库。
- 配置每个绑定的 `top_k`、`min_score`、`max_context_chars`。
- 启用/禁用智能体和知识库绑定关系。

### 5.3 对话运行时负责

- 根据当前会话的 `agent_id` 读取启用绑定。
- 对本轮用户消息执行检索。
- 按分数、数量和上下文字符预算筛选片段。
- 把选中片段注入本轮 user content，不改写智能体自定义 system prompt。
- 写入检索记录和命中记录。

### 5.4 运行监控负责

- 运行详情展示 `knowledge_retrievals`。
- 每次检索展示 query、状态、耗时、命中数、选中数、错误信息。
- 命中列表展示知识库、文档、chunk、rank、score、状态、跳过原因、内容快照。

## 6. Data model

全表都包含 `status`、`is_del`、`created_at`、`updated_at`。没有预留字段，没有 `meta_json` 垃圾桶。

### 6.1 `ai_knowledge_bases`

用途：知识库主表，管理页列表、智能体绑定候选、运行时过滤都读它。

```sql
CREATE TABLE `ai_knowledge_bases` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '知识库ID',
  `name` VARCHAR(128) NOT NULL COMMENT '知识库名称，列表、绑定、监控展示',
  `code` VARCHAR(128) NOT NULL COMMENT '知识库唯一编码，用于种子幂等和人工识别',
  `description` VARCHAR(1024) NOT NULL DEFAULT '' COMMENT '知识库说明，管理页展示和智能体绑定时辅助选择',
  `chunk_size_chars` INT UNSIGNED NOT NULL DEFAULT 1200 COMMENT '默认分块字符数，重建文档分块时使用',
  `chunk_overlap_chars` INT UNSIGNED NOT NULL DEFAULT 120 COMMENT '默认分块重叠字符数，重建文档分块时使用',
  `default_top_k` INT UNSIGNED NOT NULL DEFAULT 5 COMMENT '检索测试和智能体绑定默认召回条数',
  `default_min_score` DECIMAL(8,4) NOT NULL DEFAULT 0.1000 COMMENT '检索测试和智能体绑定默认最低分',
  `default_max_context_chars` INT UNSIGNED NOT NULL DEFAULT 6000 COMMENT '检索测试和智能体绑定默认上下文字符预算',
  `status` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1启用 2禁用；运行时只读取启用知识库',
  `is_del` TINYINT UNSIGNED NOT NULL DEFAULT 2 COMMENT '1删除 2正常；所有查询默认 is_del=2',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ai_knowledge_bases_code` (`code`, `is_del`),
  KEY `idx_ai_knowledge_bases_status` (`status`, `is_del`, `updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI知识库';
```

字段用途：

| Field | Runtime / UI usage |
| --- | --- |
| `id` | REST detail、文档外键、agent 绑定、检索 hit 外键 |
| `name` | 列表、选择器、运行监控展示 |
| `code` | 种子数据幂等、人工识别、唯一校验 |
| `description` | 列表说明、绑定弹窗说明 |
| `chunk_size_chars` | 文档重建分块默认值 |
| `chunk_overlap_chars` | 文档重建分块默认重叠 |
| `default_top_k` | 检索测试默认值、agent 绑定默认值 |
| `default_min_score` | 检索测试默认值、agent 绑定默认值 |
| `default_max_context_chars` | 检索测试默认值、agent 绑定默认值 |
| `status` | 管理启禁用、runtime 过滤 |
| `is_del` | 软删除过滤 |
| `created_at` | 列表展示、审计排序 |
| `updated_at` | 列表展示、最近维护排序 |

### 6.2 `ai_knowledge_documents`

用途：知识库文档表，保存原文，重建分块时读取 `content`。

```sql
CREATE TABLE `ai_knowledge_documents` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '文档ID',
  `knowledge_base_id` BIGINT UNSIGNED NOT NULL COMMENT 'ai_knowledge_bases.id',
  `title` VARCHAR(191) NOT NULL COMMENT '文档标题，列表、分块、监控展示',
  `source_type` VARCHAR(32) NOT NULL DEFAULT 'text' COMMENT '来源类型：text/markdown/file；第一版写 text/markdown',
  `source_ref` VARCHAR(512) NOT NULL DEFAULT '' COMMENT '来源标识，如 docs/architecture/04-go-backend-framework.md 或上传文件URL',
  `content` LONGTEXT NOT NULL COMMENT '文档原文，编辑和重建分块使用',
  `index_status` VARCHAR(16) NOT NULL DEFAULT 'pending' COMMENT 'pending/indexing/indexed/failed；分块状态展示和运行过滤',
  `error_message` VARCHAR(1024) NOT NULL DEFAULT '' COMMENT '分块失败原因，管理页展示',
  `last_indexed_at` DATETIME NULL COMMENT '最近成功重建分块时间',
  `status` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1启用 2禁用；运行时只读取启用文档',
  `is_del` TINYINT UNSIGNED NOT NULL DEFAULT 2 COMMENT '1删除 2正常',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_ai_knowledge_documents_base` (`knowledge_base_id`, `status`, `is_del`, `updated_at`),
  KEY `idx_ai_knowledge_documents_index` (`index_status`, `is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI知识库文档';
```

字段用途：

| Field | Runtime / UI usage |
| --- | --- |
| `id` | REST detail、chunk 外键、hit 外键 |
| `knowledge_base_id` | 文档归属过滤、删除级联软删 |
| `title` | 文档列表、chunk 标题、运行监控快照来源 |
| `source_type` | 区分手写文本、Markdown、上传文件 |
| `source_ref` | 展示来源路径或文件URL、种子幂等 |
| `content` | 编辑保存、重建 chunks |
| `index_status` | pending/indexing/indexed/failed 管理页展示、runtime 只读 indexed |
| `error_message` | 分块失败展示 |
| `last_indexed_at` | 判断最近一次分块时间 |
| `status` | 管理启禁用、runtime 过滤 |
| `is_del` | 软删除过滤 |
| `created_at` | 列表展示 |
| `updated_at` | 列表排序和编辑后刷新 |

### 6.3 `ai_knowledge_chunks`

用途：检索最小单位。运行时只检索启用知识库、启用文档、启用 chunk。

```sql
CREATE TABLE `ai_knowledge_chunks` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '分块ID',
  `knowledge_base_id` BIGINT UNSIGNED NOT NULL COMMENT 'ai_knowledge_bases.id，检索时直接过滤',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT 'ai_knowledge_documents.id',
  `chunk_index` INT UNSIGNED NOT NULL COMMENT '同一文档内分块序号，从1开始',
  `title` VARCHAR(191) NOT NULL DEFAULT '' COMMENT '分块标题，默认继承文档标题',
  `content` TEXT NOT NULL COMMENT '分块内容，检索和上下文注入使用',
  `content_chars` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '分块字符数，用于 max_context_chars 预算',
  `status` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1启用 2禁用；运行时只读取启用分块',
  `is_del` TINYINT UNSIGNED NOT NULL DEFAULT 2 COMMENT '1删除 2正常',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ai_knowledge_chunks_doc_index` (`document_id`, `chunk_index`, `is_del`),
  KEY `idx_ai_knowledge_chunks_base` (`knowledge_base_id`, `status`, `is_del`, `id`),
  KEY `idx_ai_knowledge_chunks_document` (`document_id`, `status`, `is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI知识库分块';
```

字段用途：

| Field | Runtime / UI usage |
| --- | --- |
| `id` | hit 外键、chunk 详情 |
| `knowledge_base_id` | runtime 检索过滤，避免先 join 文档再过滤 |
| `document_id` | 文档分块列表和删除软级联 |
| `chunk_index` | 文档内顺序、引用展示 |
| `title` | 检索评分、运行监控展示 |
| `content` | 检索评分、上下文注入、hit 快照来源 |
| `content_chars` | 上下文字符预算计算 |
| `status` | chunk 级启禁用过滤 |
| `is_del` | 软删除过滤 |
| `created_at` | 分块创建时间展示 |
| `updated_at` | 分块更新时间展示 |

### 6.4 `ai_agent_knowledge_bases`

用途：智能体和知识库绑定表。知识库是否能被智能体读取，只看这张表，不写入 `ai_agents` JSON 字段。

```sql
CREATE TABLE `ai_agent_knowledge_bases` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '绑定ID',
  `agent_id` BIGINT UNSIGNED NOT NULL COMMENT 'ai_agents.id',
  `knowledge_base_id` BIGINT UNSIGNED NOT NULL COMMENT 'ai_knowledge_bases.id',
  `top_k` INT UNSIGNED NOT NULL DEFAULT 5 COMMENT '本智能体对此知识库召回条数',
  `min_score` DECIMAL(8,4) NOT NULL DEFAULT 0.1000 COMMENT '本智能体对此知识库最低命中分',
  `max_context_chars` INT UNSIGNED NOT NULL DEFAULT 6000 COMMENT '本智能体对此知识库最大注入字符数',
  `status` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1启用 2禁用；运行时只加载启用绑定',
  `is_del` TINYINT UNSIGNED NOT NULL DEFAULT 2 COMMENT '1删除 2正常',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_ai_agent_knowledge_base` (`agent_id`, `knowledge_base_id`, `is_del`),
  KEY `idx_ai_agent_knowledge_agent` (`agent_id`, `status`, `is_del`),
  KEY `idx_ai_agent_knowledge_base` (`knowledge_base_id`, `status`, `is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI智能体知识库绑定';
```

字段用途：

| Field | Runtime / UI usage |
| --- | --- |
| `id` | 绑定行编辑和更新 |
| `agent_id` | 智能体配置页读取和运行时加载 |
| `knowledge_base_id` | 绑定知识库 |
| `top_k` | runtime 限制召回数量 |
| `min_score` | runtime 过滤低相关片段 |
| `max_context_chars` | runtime 控制注入上下文长度 |
| `status` | 绑定启禁用 |
| `is_del` | 软删除过滤 |
| `created_at` | 绑定创建展示 |
| `updated_at` | 绑定更新时间展示 |

### 6.5 `ai_knowledge_retrievals`

用途：每个 run 的知识库检索主记录。运行监控详情读取它。

```sql
CREATE TABLE `ai_knowledge_retrievals` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '检索ID',
  `run_id` BIGINT UNSIGNED NOT NULL COMMENT 'ai_runs.id',
  `query` TEXT NOT NULL COMMENT '本轮检索查询文本，通常为用户消息正文',
  `status` VARCHAR(16) NOT NULL COMMENT 'success/failed/skipped',
  `total_hits` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '原始命中数量',
  `selected_hits` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '进入上下文的命中数量',
  `duration_ms` INT UNSIGNED NULL COMMENT '检索耗时毫秒',
  `error_message` VARCHAR(1024) NOT NULL DEFAULT '' COMMENT '失败原因',
  `is_del` TINYINT UNSIGNED NOT NULL DEFAULT 2 COMMENT '1删除 2正常；运行监控默认只读正常记录',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_ai_knowledge_retrievals_run` (`run_id`, `is_del`, `created_at`),
  KEY `idx_ai_knowledge_retrievals_status` (`status`, `is_del`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI知识库检索记录';
```

字段用途：

| Field | Runtime / UI usage |
| --- | --- |
| `id` | hit 外键、运行详情分组 |
| `run_id` | 运行监控详情关联 |
| `query` | 运行监控展示和问题复盘 |
| `status` | success/failed/skipped 展示 |
| `total_hits` | 检索效果统计 |
| `selected_hits` | 实际进入上下文数量 |
| `duration_ms` | 运行监控耗时展示 |
| `error_message` | 失败展示 |
| `is_del` | 运行监控过滤 |
| `created_at` | 检索时间展示 |
| `updated_at` | 终态更新时间 |

### 6.6 `ai_knowledge_retrieval_hits`

用途：记录每个检索命中的 chunk 快照。运行监控不能只 join 当前 chunk，因为文档以后可能被改。

```sql
CREATE TABLE `ai_knowledge_retrieval_hits` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '命中ID',
  `retrieval_id` BIGINT UNSIGNED NOT NULL COMMENT 'ai_knowledge_retrievals.id',
  `knowledge_base_id` BIGINT UNSIGNED NOT NULL COMMENT '命中知识库ID',
  `knowledge_base_name` VARCHAR(128) NOT NULL COMMENT '命中时知识库名称快照',
  `document_id` BIGINT UNSIGNED NOT NULL COMMENT '命中文档ID',
  `document_title` VARCHAR(191) NOT NULL COMMENT '命中时文档标题快照',
  `chunk_id` BIGINT UNSIGNED NOT NULL COMMENT '命中分块ID',
  `chunk_index` INT UNSIGNED NOT NULL COMMENT '命中分块序号快照',
  `score` DECIMAL(10,6) NOT NULL DEFAULT 0.000000 COMMENT '检索评分',
  `rank_no` INT UNSIGNED NOT NULL COMMENT '本次检索排序，从1开始',
  `content_snapshot` TEXT NOT NULL COMMENT '命中内容快照，运行监控和问题复盘使用',
  `status` TINYINT UNSIGNED NOT NULL DEFAULT 1 COMMENT '1进入上下文 2跳过',
  `skip_reason` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '跳过原因：low_score/context_limit',
  `is_del` TINYINT UNSIGNED NOT NULL DEFAULT 2 COMMENT '1删除 2正常',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_ai_knowledge_hits_retrieval` (`retrieval_id`, `status`, `rank_no`),
  KEY `idx_ai_knowledge_hits_chunk` (`chunk_id`, `is_del`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='AI知识库检索命中';
```

字段用途：

| Field | Runtime / UI usage |
| --- | --- |
| `id` | 命中行展示 |
| `retrieval_id` | 归属检索记录 |
| `knowledge_base_id` | 当前对象跳转和统计 |
| `knowledge_base_name` | 历史监控快照展示 |
| `document_id` | 当前对象跳转和统计 |
| `document_title` | 历史监控快照展示 |
| `chunk_id` | 当前 chunk 跳转和统计 |
| `chunk_index` | 引用展示 |
| `score` | 排名和调参依据 |
| `rank_no` | 稳定展示顺序 |
| `content_snapshot` | 历史复盘和运行监控展示 |
| `status` | 1进入上下文，2被跳过 |
| `skip_reason` | 解释低分或超预算跳过 |
| `is_del` | 运行监控过滤 |
| `created_at` | 命中时间展示 |
| `updated_at` | 状态更新时间 |

## 7. REST API contract

统一 `/api/admin/v1`，不使用旧 `/ai-knowledge-maps`。

```text
GET    /api/admin/v1/ai-knowledge-bases/page-init
GET    /api/admin/v1/ai-knowledge-bases
GET    /api/admin/v1/ai-knowledge-bases/:id
POST   /api/admin/v1/ai-knowledge-bases
PUT    /api/admin/v1/ai-knowledge-bases/:id
PATCH  /api/admin/v1/ai-knowledge-bases/:id/status
DELETE /api/admin/v1/ai-knowledge-bases/:id

GET    /api/admin/v1/ai-knowledge-bases/:id/documents
GET    /api/admin/v1/ai-knowledge-documents/:id
POST   /api/admin/v1/ai-knowledge-bases/:id/documents
PUT    /api/admin/v1/ai-knowledge-documents/:id
PATCH  /api/admin/v1/ai-knowledge-documents/:id/status
DELETE /api/admin/v1/ai-knowledge-documents/:id
POST   /api/admin/v1/ai-knowledge-documents/:id/reindex
GET    /api/admin/v1/ai-knowledge-documents/:id/chunks

POST   /api/admin/v1/ai-knowledge-bases/:id/retrieval-tests

GET    /api/admin/v1/ai-agents/:id/knowledge-bases
PUT    /api/admin/v1/ai-agents/:id/knowledge-bases
```

### Permission mapping

使用现有 live permission code，不新增重复 code：

```text
POST   /ai-knowledge-bases                         -> ai_knowledge_add
PUT    /ai-knowledge-bases/:id                     -> ai_knowledge_edit
PATCH  /ai-knowledge-bases/:id/status              -> ai_knowledge_status
DELETE /ai-knowledge-bases/:id                     -> ai_knowledge_del
POST   /ai-knowledge-documents/:id/reindex         -> ai_knowledge_reindex
POST   /ai-knowledge-bases/:id/retrieval-tests     -> ai_knowledge_retrieval_test
POST   /ai-knowledge-bases/:id/documents           -> ai_knowledge_document_add
PUT    /ai-knowledge-documents/:id                 -> ai_knowledge_document_edit
PATCH  /ai-knowledge-documents/:id/status          -> ai_knowledge_document_status
DELETE /ai-knowledge-documents/:id                 -> ai_knowledge_document_del
```

智能体知识库绑定沿用智能体绑定权限概念，避免新增同义按钮：

```text
GET /ai-agents/:id/knowledge-bases  -> read route, no button code
PUT /ai-agents/:id/knowledge-bases  -> ai_agent_binding_add
```

## 8. Retrieval algorithm

第一版是可解释检索，不假装语义向量：

1. 输入 query：本轮用户消息纯文本，去掉空白。
2. 加载启用绑定：`ai_agent_knowledge_bases.status=1,is_del=2`，并 join 启用知识库。
3. 候选 chunk：知识库、文档、chunk 都必须 `status=1,is_del=2`，文档 `index_status='indexed'`。
4. 候选筛选：SQL 限定绑定知识库，再在 Go 里对 title/content 做大小写不敏感匹配评分。
5. 评分规则：标题命中权重大于内容命中；完整 query 命中权重大于分词命中；同分按 chunk id 升序。
6. 低于 `min_score` 的 hit 写入 hit 表，`status=2, skip_reason='low_score'`。
7. 超过 `max_context_chars` 的 hit 写入 hit 表，`status=2, skip_reason='context_limit'`。
8. 选中 hit 以 `[K1]`、`[K2]` 编号注入本轮 user content。

注入格式：

```text
以下是当前智能体允许读取的知识库片段。回答时只能把这些片段当作项目内知识参考；如果片段不足，请明确说明知识库没有覆盖。

[K1] 知识库：admin_go 项目架构知识库；文档：Go 后端架构；分块：1
<chunk content>

[K2] ...

用户问题：
<original user message>
```

不修改 `ai_agents.system_prompt`。没有命中时不注入知识库上下文。

## 9. Runtime monitor DTO additions

`GET /api/admin/v1/ai-runs/:id` 增加：

```json
{
  "knowledge_retrievals": [
    {
      "id": 1,
      "run_id": 10,
      "query": "这个项目后端架构是什么？",
      "status": "success",
      "total_hits": 4,
      "selected_hits": 2,
      "duration_ms": 8,
      "error_message": "",
      "created_at": "2026-05-10 20:00:00",
      "hits": [
        {
          "id": 1,
          "knowledge_base_id": 1,
          "knowledge_base_name": "admin_go 项目架构知识库",
          "document_id": 1,
          "document_title": "Go 后端架构",
          "chunk_id": 1,
          "chunk_index": 1,
          "score": 0.820000,
          "rank_no": 1,
          "content_snapshot": "admin_back_go 采用 Gin modular monolith...",
          "status": 1,
          "status_name": "进入上下文",
          "skip_reason": "",
          "created_at": "2026-05-10 20:00:00"
        }
      ]
    }
  ]
}
```

## 10. Seed knowledge content

第一版迁移入库一个默认知识库和 6 篇文档。内容是项目架构摘要，不从旧知识库表迁移。

### Knowledge base

```text
name: admin_go 项目架构知识库
code: admin_go_project_architecture
description: admin_go 后端、前端、AI 模块和迁移规范的项目内知识库，用于智能体回答项目架构相关问题。
chunk_size_chars: 1200
chunk_overlap_chars: 120
default_top_k: 5
default_min_score: 0.1000
default_max_context_chars: 6000
status: 1
is_del: 2
```

### Seed documents

1. `项目总原则` / `docs/architecture/00-open-source-first.md`
2. `Go 后端架构` / `docs/architecture/04-go-backend-framework.md`
3. `开发质量规则` / `docs/architecture/05-development-quality-rules.md`
4. `AI 模块当前事实` / `docs/migration/current-status.md#ai`
5. `AI 对话运行链路` / `admin_back_go/internal/module/aichat/service.go`
6. `Vue 前端 AI 页面结构` / `admin_front_ts/src/views/Main/ai`

### Seed chunk examples

```text
项目总原则：admin_go 是 open-source-first admin rewrite workspace。处理任务先读当前状态，不靠聊天记录猜进度；再读架构、契约、测试文档；再按 agent 角色接手一个窄切片；最后才改代码、跑验证、同步文档。架构、RBAC、菜单、API 契约和项目前端权限默认先参考成熟开源和当前运行事实，不凭感觉发明。
```

```text
Go 后端架构：admin_back_go 采用 Gin modular monolith。顶层调用链是 cmd -> bootstrap -> server -> module -> platform。业务模块内部默认是 route -> handler -> service -> repository -> model。handler 不直接查数据库，service 不依赖 gin.Context，repository 不写业务决策，model 不写业务方法。
```

```text
开发质量规则：项目禁止兜底字段、兼容猜测、全 POST、any TypeScript 和未验证声明。新增接口必须使用 /api/admin/v1/<resource> REST 风格。字段必须有真实用途，文档与运行时冲突时以运行时为准并修正文档。
```

```text
AI 模块当前事实：当前 AI 产品面包括供应商配置、智能体配置、知识库、AI 工具管理、运行监控、AI 对话。供应商配置保存 provider 和 provider models，智能体配置保存 ai_agents 并选择 provider-owned model，工具管理只定义 ai_tools，智能体配置页通过 ai_agent_tools 决定可用工具。
```

```text
AI 对话运行链路：浏览器通过 WebSocket 接收 ai.response.start.v1、ai.response.delta.v1、ai.response.completed.v1、ai.response.failed.v1。发送消息后，aimessage 保存用户消息，aichat 创建 ai_runs，加载智能体、历史消息、工具绑定，调用 provider stream，保存助手消息并完成 run。
```

```text
Vue 前端结构：admin_front_ts 使用 Vue 3、Composition API、script setup lang=ts 和 typed API client。AI 页面位于 src/views/Main/ai，当前子模块包含 providers、agents、knowledge、tools、runs、chat。按钮权限通过 userStore.can(code) 控制，表格和弹窗优先复用 AppTable、AppDialog、Search 等项目组件。
```

## 11. Frontend component map

### Knowledge page

- `src/views/Main/ai/knowledge/index.vue`：页面组合层，只管理选中知识库和子组件事件。
- `components/KnowledgeBaseList/index.vue`：搜索、列表、状态、删除、打开文档。
- `components/KnowledgeBaseFormDialog/index.vue`：新增/编辑知识库。
- `components/KnowledgeDocumentPanel/index.vue`：展示选中知识库下文档列表和分块入口。
- `components/KnowledgeDocumentFormDialog/index.vue`：新增/编辑文档正文。
- `components/KnowledgeChunkDialog/index.vue`：查看文档分块。
- `components/RetrievalTestDialog/index.vue`：输入 query，展示检索命中和分数。

### Agent page

- 新增 `components/AgentKnowledgeDialog/index.vue`：与现有 `AgentToolDialog` 同级，负责配置智能体知识库绑定。
- `agents/index.vue`：新增“知识库”操作按钮，只打开 dialog，不把知识库绑定塞进智能体新增/编辑主表单。

### Run monitor page

- `runs/components/RunDetailDialog` 或当前详情组件：新增知识库检索区块，与工具调用区块同级。
- 展示密度控制：默认折叠 hit 内容，只显示 score/rank/name；点击展开内容快照。

## 12. Backend module map

- 新模块：`internal/module/aiknowledge`
  - `model.go`：6 张表模型。
  - `dto.go`：REST DTO、runtime DTO、repository 接口。
  - `request.go`：Gin request 结构。
  - `repository.go`：Gorm 持久化、绑定、检索候选、run monitor 查询。
  - `chunker.go`：纯函数分块。
  - `retriever.go`：纯函数评分和筛选。
  - `service.go`：CRUD、reindex、retrieval test、agent binding、runtime retrieval。
  - `handler.go`：HTTP handler。
  - `route.go`：REST route 注册。
- 修改 `internal/module/aichat`：增加 `KnowledgeRuntime` 依赖，`StreamChat` 前执行检索并把上下文合入 user content。
- 修改 `internal/module/airun`：详情返回 `knowledge_retrievals`。
- 修改 `internal/bootstrap` 和 `internal/server`：挂新模块，卸旧 `aiknowledgemap` active route。

## 13. Error handling

- 知识库不存在：`404 AI知识库不存在`。
- 文档不存在：`404 AI知识库文档不存在`。
- 禁用知识库用于绑定：`100 AI知识库不存在或已禁用`。
- 文档正文为空：`100 AI知识库文档内容不能为空`。
- 分块参数非法：`100 分块配置不合法`。
- 检索 query 为空：`100 检索内容不能为空`。
- 运行时检索失败：写 `ai_knowledge_retrievals.status='failed'`，同时 run 继续还是失败由错误类型决定。第一版采用失败不阻断模型：写 failed 记录、写 run event message，然后无知识库上下文继续模型调用。

## 14. Verification gates

Backend:

```powershell
cd E:\admin_go\admin_back_go
go test ./internal/module/aiknowledge ./internal/module/aichat ./internal/module/airun ./internal/server ./internal/bootstrap -count=1
go vet -p=1 ./...
```

Frontend:

```powershell
cd E:\admin_go\admin_front_ts
.\node_modules\.bin\vitest.cmd run tests/shared/ai/ai-knowledge-api.test.ts tests/shared/ai/ai-agent-api.test.ts tests/shared/ai/ai-run-api.test.ts --maxWorkers=1
npx vue-tsc -b --pretty false
npm run build:check
```

Smoke:

```powershell
cd E:\admin_go\admin_back_go
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\full-admin-smoke.ps1
```

DB checks:

```sql
SELECT COUNT(*) AS knowledge_tables
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN (
    'ai_knowledge_bases',
    'ai_knowledge_documents',
    'ai_knowledge_chunks',
    'ai_agent_knowledge_bases',
    'ai_knowledge_retrievals',
    'ai_knowledge_retrieval_hits'
  );

SELECT id, name, code, status, is_del
FROM ai_knowledge_bases
WHERE code = 'admin_go_project_architecture';
```

## 15. Non-goals

- 不引入 Qdrant、Milvus、pgvector。
- 不接 OpenAI hosted file_search / vector_store。
- 不接 Dify/RAGFlow dataset API。
- 不支持多媒体 OCR。
- 不支持跨租户知识隔离，因为当前 admin_go AI 模块还没有 tenant 模型。
- 不把知识库绑定字段塞进 `ai_agents` JSON。
- 不把知识库做成 `ai_tools` 的伪工具。
