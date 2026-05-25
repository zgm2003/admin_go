# Keyword Asset Intelligence Search Design Spec

状态：planned。本文只记录关键字驱动的域名/IP/网页内容资产情报搜索设计；没有任何运行时代码或数据表已经实现。运行真相仍以 live runtime、smoke/test、`docs/status/current-status.md`、`docs/contracts/*` 和当前代码为准。

## 1. Outcome

建设一个后台自动化资产内容搜索模块：用户只输入关键字，系统返回命中的公开网页、域名、URL、IP、ASN、BGP prefix、页面摘要、抓取时间和资产归属置信度。

第一版不是“用户输入 ASN 后查资产”，也不是“实时爬全网”。第一版应做成“关键字触发候选发现 + 后台自动采集 + 索引检索”的闭环：

```text
用户输入关键字
-> 先查已有索引，秒级返回已采集结果
-> 结果不足时创建后台扩展采集任务
-> 任务从公开/授权数据源发现候选 URL 和域名
-> 抓取公开 HTML，提取正文和元数据
-> DNS 解析域名得到 IP
-> IP 查 ASN/BGP prefix 做归属增强
-> 写入结构化资产库和搜索索引
-> 后续搜索持续命中新增结果
```

老板提出的 ASN/BGP 方案保留，但位置调整为资产归属增强：

```text
网页 -> 域名 -> IP -> ASN/BGP
```

不要把它设计成：

```text
ASN/BGP -> IP -> 反查全部域名
```

原因是 IP 到域名没有完整可靠的公开枚举链路。PTR/reverse DNS 覆盖率低，CDN、共享主机、云厂商 IP 会污染归属判断。正确方式是多源域名发现、DNS/IP/ASN 关联和置信度评分。

## 2. Linus 三问

1. 这是真问题吗？是。用户想用一个关键词找到相关公开站点、域名和 IP，单纯人工查搜索引擎、DNS、ASN 和网页内容成本高，适合做自动采集和检索系统。
2. 有更简单的方法吗？有。第一版先做关键字候选发现、HTML 抓取、正文提取、DNS/ASN 关联和 BM25 关键词检索；不先做全网扫描、独立向量库、分布式爬虫和复杂机器学习归属模型。
3. 会破坏什么吗？不能破坏现有 admin 登录、RBAC、菜单、队列、AI、支付、上传和 current-status。新模块应独立挂到 `/api/admin/v1/asset-intel`，按现有 `route -> handler -> service -> repository -> model` 实现，后台任务走现有 worker/queue 边界。

## 3. Current Project Facts

- 后端是 `admin_back_go`，Gin modular monolith，固定调用链为 `route -> handler -> service -> repository -> model`。
- 新后台 API 必须使用 `/api/admin/v1/<resource>`，不能继续旧 all-POST action URL。
- 后台任务已经有 `cmd/admin-worker`、Redis/Asynq task queue、DB-backed cron-to-queue 边界。
- 当前已有 AI 知识库 RAG，但它是本地知识库问答，不是公开互联网资产采集；本模块不能复用 AI 知识库表作为资产爬虫垃圾桶。
- 前端是 `admin_front_ts`，新管理页应使用现有 typed API、`Search`、`AppTable`、`AppDialog`、`useTable`/`useCrudTable` 和 Vue i18n。
- 文档治理要求：spec 是 planned，不得更新 `docs/status/current-status.md` 为 implemented，除非后续代码和 runtime 验证完成。

## 4. External Practice Summary

可借鉴：

- ASN/BGP 查询：Team Cymru IP to ASN、RouteViews、RIPE RIS/RIPEstat 可用于 IP 到 ASN、prefix、路由可见性查询。
- 域名发现：Certificate Transparency、RDAP、Common Crawl、reverse DNS、页面链接爬取、用户导入 seed、授权搜索 API 可作为候选域名/URL 来源。
- 抓取治理：遵守 robots、限速、超时、重试、User-Agent 标识、失败退避，不做未授权登录态采集。
- 搜索：关键词精确搜索优先用 BM25/倒排索引；语义扩展再引入向量库。第一版不要只靠向量库。

不采用：

- 不直接扫描全部公网 IP 段。
- 不把 PTR 结果当成“该 IP 上所有域名”。
- 不直接爬取 Google/Bing 网页搜索结果页；需要使用授权 API、公开数据集或用户授权的 seed。
- 不把 CDN/shared hosting 上的 IP 关系当成强归属。
- 不在浏览器端直接抓第三方网页或调用第三方搜索密钥。

参考资料：

- Team Cymru IP to ASN Mapping: `https://www.team-cymru.com/community-services/ip-asn-mapping`
- RouteViews API: `https://api.routeviews.org/docs/`
- RIPE RIS Live: `https://ris-live.ripe.net/`
- Certificate Transparency RFC 9162: `https://www.rfc-editor.org/rfc/rfc9162.html`
- ICANN RDAP: `https://www.icann.org/rdap/`
- Common Crawl Index: `https://index.commoncrawl.org/`
- Robots Exclusion Protocol RFC 9309: `https://datatracker.ietf.org/doc/rfc9309/`
- OpenSearch hybrid search: `https://opensearch.org/blog/hybrid-search/`
- Qdrant filtering: `https://qdrant.tech/documentation/search/filtering/`

## 5. Product Boundaries

### 5.1 用户搜索页负责

- 输入关键字。
- 展示已有索引搜索结果。
- 展示结果来源、命中字段、摘要、URL、域名、IP、ASN、prefix、抓取时间、置信度。
- 展示本次搜索是否已有后台扩展采集任务；如果没有，允许用户显式创建任务。
- 支持按域名、IP、ASN、状态码、语言、抓取时间、置信度过滤。

### 5.2 采集任务页负责

- 查看关键字扩展采集任务。
- 查看任务状态、来源、候选 URL 数、抓取成功/失败数、索引成功/失败数。
- 支持取消 pending/running-safe 阶段任务。
- 支持重试 failed 任务。
- 不允许默认无限重跑或无上限扩散。

### 5.3 资产库页负责

- 域名资产列表。
- IP/ASN 关联列表。
- 页面快照列表。
- 查看单个页面的提取正文、headers 摘要、抓取记录、索引状态。
- 查看域名与 IP/ASN 的关系证据和置信度。

### 5.4 数据源配置页负责

- 配置启用的数据源：搜索 API、Common Crawl、Certificate Transparency、RDAP、reverse DNS。
- 保存第三方 API key 时必须走后端加密，不返回明文。
- 配置抓取限速、单关键词最大候选数、单域名最大页面数、超时、User-Agent。
- 第一版可先不做复杂 UI，允许用系统设置或受控 config 启用，但设计上必须保留数据源边界。

## 6. Non-goals

第一版明确不做：

- 全网 IP 段扫描。
- 端口扫描、漏洞扫描、目录爆破、登录态抓取。
- 绕过 robots 或反爬。
- 暗网、内网、非公开数据采集。
- 自动认定“某 IP 必然属于某公司”。
- 实时搜索全网。
- 独立分布式爬虫集群。
- 独立向量数据库。
- 自动生成法律/合规结论。

这些边界必须写进产品说明和管理员配置，避免功能被误用成攻击面扫描器。

## 7. Recommended Approach

采用三阶段方案。

### 7.1 Phase 1: Keyword-driven BM25 MVP

目标：最快形成可用闭环。

能力：

- 用户输入关键字。
- 查询已有 OpenSearch/Meilisearch/Typesense 索引。
- 如果结果不足，创建 `asset-intel:discover-keyword:v1` 任务。
- 任务从授权搜索 API 获取关键词候选 URL；Common Crawl、Certificate Transparency 和 seed 源只做补充发现，不能单独承诺通用关键词搜索覆盖率。
- 抓取候选页面首页和少量同域内链。
- 提取 title、meta、正文、语言、内容 hash。
- DNS 解析域名到 A/AAAA/CNAME。
- IP 查询 ASN/BGP prefix。
- MySQL 保存结构化数据。
- 搜索引擎保存页面正文和可过滤 metadata。

第一版推荐先用 OpenSearch。如果运维成本需要更低，也可用 Meilisearch/Typesense，但需要确认中文分词、过滤、排序和高亮能力满足产品需求。

### 7.2 Phase 2: Hybrid Search and Confidence

目标：提高召回和排序质量。

能力：

- 引入 Qdrant/pgvector/Milvus 保存页面 chunk embedding。
- 查询时做 BM25 + vector hybrid search。
- 引入域名/IP/ASN 关系置信度评分。
- 对 CDN/shared hosting 做降权。
- 加入定时重爬和 stale 数据标记。
- 对重复页面、镜像站、低质量页面做去重和降权。

### 7.3 Phase 3: Asset Intelligence Expansion

目标：提升覆盖率和生产可用性。

能力：

- 接 passive DNS、Censys/Shodan/SecurityTrails/DNSDB 等授权数据源。
- 分布式 crawler worker。
- 大规模 crawl budget 管理。
- 告警、订阅、导出、报告。
- 组织名/品牌名到域名/ASN 的发现链路。
- 更完整的审计、配额和租户隔离。

## 8. Architecture

### 8.1 Backend module

模块名建议：`assetintel`。

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

模块职责：

- 搜索请求、任务查询、资产查询的 REST API。
- 管理数据源配置和抓取策略。
- 编排 discovery、crawl、dns、asn、index 任务状态。
- 不直接依赖第三方 SDK 细节。

外部边界建议：

```text
internal/platform/assetsearch     # 搜索 API / Common Crawl source adapter
internal/platform/webcrawler      # HTTP fetch, robots, rate limit, content limits
internal/platform/dnsresolver     # DNS A/AAAA/CNAME/PTR
internal/platform/asnlookup       # IP -> ASN/prefix provider
internal/platform/searchindex     # OpenSearch/Meilisearch/Typesense adapter
internal/platform/vectorindex     # Phase 2 only
```

### 8.2 Jobs

任务类型建议：

```text
asset-intel:discover-keyword:v1
asset-intel:crawl-url:v1
asset-intel:resolve-domain:v1
asset-intel:enrich-ip-asn:v1
asset-intel:index-page:v1
asset-intel:recrawl-stale:v1
```

任务原则：

- 每个任务幂等。
- 每个任务 payload 只放必要 ID 和版本，不放大 HTML。
- 大内容写 DB/object storage 后传 ID。
- 失败有错误码、错误摘要和重试次数。
- URL 去重、domain 限速、全局并发限制必须在 service/platform 层实现。

### 8.3 Frontend pages

菜单建议：

```text
/asset-intel/search       资产搜索
/asset-intel/tasks        采集任务
/asset-intel/domains      域名资产
/asset-intel/pages        页面快照
/asset-intel/sources      数据源配置
```

第一版可只开放：

```text
/asset-intel/search
/asset-intel/tasks
/asset-intel/pages
```

`domains` 和 `sources` 可在后续阶段补 UI，但后端表结构和权限编码要预留清晰边界，不使用兜底 JSON。

## 9. Data Model

第一版表应围绕任务、候选、页面、域名、解析、ASN、索引状态建模。以下是设计级字段，不是最终 SQL。

### 9.1 `asset_intel_search_tasks`

用途：记录用户关键字搜索触发的后台扩展采集任务。

字段：

- `id`
- `keyword`
- `status`: pending/running/succeeded/failed/canceled
- `source_scope`: enabled sources snapshot
- `candidate_count`
- `crawl_success_count`
- `crawl_failed_count`
- `indexed_count`
- `error_message`
- `created_by`
- `created_at`
- `updated_at`

### 9.2 `asset_intel_candidates`

用途：候选 URL/域名池，记录从哪个数据源发现。

字段：

- `id`
- `task_id`
- `source_type`: search_api/common_crawl/ct/rdap/reverse_dns/seed/crawl_link
- `keyword`
- `url`
- `domain`
- `discovered_at`
- `status`: pending/crawled/skipped/failed
- `skip_reason`
- `dedupe_hash`

### 9.3 `asset_intel_domains`

用途：域名主表。

字段：

- `id`
- `domain`
- `registrable_domain`
- `tld`
- `first_seen_at`
- `last_seen_at`
- `confidence_level`: high/medium/low/unknown
- `confidence_score`
- `status`

### 9.4 `asset_intel_domain_resolutions`

用途：DNS 解析历史。

字段：

- `id`
- `domain_id`
- `record_type`: A/AAAA/CNAME/PTR
- `record_value`
- `resolved_ip`
- `ttl`
- `resolved_at`
- `source_type`

### 9.5 `asset_intel_ip_assets`

用途：IP 和 ASN 归属增强。

字段：

- `id`
- `ip`
- `asn`
- `asn_name`
- `prefix`
- `rir`
- `country_code`
- `provider`
- `looked_up_at`

### 9.6 `asset_intel_pages`

用途：网页快照和正文索引主记录。

字段：

- `id`
- `task_id`
- `domain_id`
- `url`
- `canonical_url`
- `http_status`
- `content_type`
- `title`
- `meta_description`
- `language`
- `html_storage_ref`
- `text_content`
- `content_hash`
- `fetched_at`
- `index_status`: pending/indexed/failed
- `error_message`

### 9.7 `asset_intel_page_ip_links`

用途：页面抓取时域名解析到 IP 的关系快照。

字段：

- `id`
- `page_id`
- `domain_id`
- `ip_asset_id`
- `relation_type`: current_dns/historical_dns/ptr/ct_hint
- `confidence_score`
- `evidence_summary`
- `created_at`

### 9.8 `asset_intel_source_configs`

用途：数据源配置。

字段：

- `id`
- `source_type`
- `name`
- `enabled`
- `rate_limit_per_minute`
- `daily_quota`
- `encrypted_api_key`
- `config_scope`
- `status`
- `created_at`
- `updated_at`

注意：第三方密钥不返回明文；如果复用现有 secretbox，需要明确 APP_SECRET 轮换风险和重录策略。

## 10. API Contract Draft

第一版 REST 草案：

```text
GET    /api/admin/v1/asset-intel/search
POST   /api/admin/v1/asset-intel/search-tasks
GET    /api/admin/v1/asset-intel/search-tasks
GET    /api/admin/v1/asset-intel/search-tasks/:id
PATCH  /api/admin/v1/asset-intel/search-tasks/:id/cancel
POST   /api/admin/v1/asset-intel/search-tasks/:id/retry
GET    /api/admin/v1/asset-intel/pages
GET    /api/admin/v1/asset-intel/pages/:id
GET    /api/admin/v1/asset-intel/domains
GET    /api/admin/v1/asset-intel/domains/:id
GET    /api/admin/v1/asset-intel/ip-assets
GET    /api/admin/v1/asset-intel/sources
PUT    /api/admin/v1/asset-intel/sources/:id
```

搜索接口行为：

- `GET /search?keyword=...` 只查询索引，不直接爬取。
- `POST /search-tasks` 创建扩展采集任务。
- 前端搜索页可在结果不足时提示并触发任务，或由用户点击“扩展采集”。
- 第一版不要让 GET 搜索产生后台副作用，避免刷新页面重复创建任务。

## 11. Search Ranking

第一版排序建议：

```text
final_score =
  keyword_score * 0.55
  + field_boost * 0.15
  + asset_confidence_score * 0.15
  + freshness_score * 0.10
  + source_quality_score * 0.05
```

字段权重：

- `title` 命中最高。
- `meta_description` 次之。
- `body` 正文命中正常权重。
- `domain` / `url` 命中应单独加权。
- CDN/shared hosting 关系不得给强归属加分。

Phase 2 hybrid search：

```text
BM25 candidates + vector candidates
-> 合并去重
-> metadata filter
-> rerank
-> 返回命中片段和关系证据
```

## 12. Security, Compliance, and Abuse Controls

必须默认内建：

- 只抓公开 HTTP/HTTPS 页面。
- 不提交表单、不登录、不绕过权限。
- 尊重 robots 和站点限速策略。
- 对每个 domain 设置并发和速率上限。
- 对每个关键词设置候选上限、深度上限、页面上限。
- 禁止内网 IP、localhost、link-local、metadata service 地址抓取，防 SSRF。
- URL normalize 后再请求，禁止 file/gopher/ftp 等非 HTTP 协议。
- HTML 和 headers 存储前限制大小。
- 不记录完整敏感 headers 和 cookies。
- OperationLog 不捕获大 HTML 内容。
- 第三方 API key 只后端保存和调用。
- 抓取失败、403、robots disallow 要记录状态，不要绕过。

这个模块天然接近 OSINT/资产发现能力，必须有 RBAC、审计、配额和安全开关。第一版默认只给管理员或明确授权角色开放。

## 13. Error Handling

错误应分层：

- 用户输入错误：关键词为空、长度过长、非法过滤条件。
- 数据源错误：API key 缺失、quota 超限、第三方 429/5xx。
- 抓取错误：robots disallow、超时、DNS 失败、TLS 失败、非 HTML、内容过大。
- 索引错误：搜索引擎不可用、mapping 不匹配、index 写入失败。
- 任务错误：取消、重试次数耗尽、幂等冲突。

后端用户可见错误必须用 i18n key；第三方原始错误只作为内部摘要，不直接透出密钥、完整 URL query 或敏感响应。

## 14. RBAC and Operation Log

建议权限码：

```text
assetIntel_search_view
assetIntel_search_collect
assetIntel_task_view
assetIntel_task_cancel
assetIntel_task_retry
assetIntel_page_view
assetIntel_domain_view
assetIntel_ip_view
assetIntel_source_view
assetIntel_source_edit
```

OperationLog：

- 搜索 GET 默认不记录请求/响应大 payload。
- 创建采集任务、取消、重试、修改数据源配置必须记录。
- 配置保存时敏感字段遮蔽。
- 页面详情响应不捕获 HTML 正文。

## 15. Testing and Verification

Spec 后续进入实现计划时，最低验证应包括：

Backend:

```text
go test ./internal/module/assetintel -count=1
go test ./internal/platform/dnsresolver -count=1
go test ./internal/platform/asnlookup -count=1
go test ./internal/platform/webcrawler -count=1
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
- 搜索页 GET 能返回空列表。
- 创建搜索任务返回 task id。
- worker 执行 mock source/mock crawler/mock index 后 task 状态闭环。
- 页面列表能查到被索引页面。
- 数据源密钥不明文返回。
- SSRF 禁止用例覆盖 localhost/private IP/link-local。

Docs-only 验证：

```text
git diff --check
```

## 16. Rollback Plan

第一版实现应支持按层回滚：

- 菜单禁用：删除/禁用资产情报菜单和权限授权，不影响其他模块。
- Worker 停止：禁用 asset-intel task registration，不影响 API 只读查询。
- 数据源停用：关闭 source config，不再创建外部请求。
- 索引停用：搜索接口返回明确错误或降级到 MySQL 最近页面列表，但不能假装全文检索正常。
- 数据回滚：新增表独立命名 `asset_intel_*`，不改现有业务表。

不要把资产情报字段混进 AI、支付、用户、权限等已有业务表。

## 17. Implementation Defaults

这些默认决策用于后续 implementation plan；用户可以在进入实现前改，但计划必须以一个确定版本推进。

1. 第一版搜索索引用 OpenSearch。理由：BM25、过滤、高亮、后续 hybrid search 路线都更完整。
2. 第一版关键词候选发现需要接一个授权搜索 API，例如 Bing Web Search、Brave Search API 或 SerpAPI。没有 API key 时，只能做 dev fallback：seed import、CT、Common Crawl enrichment 和 mock source，不能宣称生产可用的关键词全网发现。
3. 第一版默认保存正文、title、meta、headers 摘要、content hash 和 HTML 存储引用；原始 HTML 默认不直接长期存 MySQL 大字段。若没有对象存储配置，先不保存原始 HTML，只保存正文和 metadata。
4. robots 强制遵守，抓取 User-Agent 固定由后端配置，默认每域名低并发、低速率。
5. 第一版菜单只给超级管理员或显式授权角色，不默认开放给所有后台用户。

## 18. Decisions To Revisit Before Implementation Plan

进入 implementation plan 前只需要复核这些产品选择是否要覆盖默认值：

1. 选择哪个授权搜索 API provider，以及是否已有 API key。
2. 是否必须保存原始 HTML 快照；如果必须保存，使用现有 COS 还是新增对象存储配置。
3. 默认每关键词候选 URL 上限、每域名页面上限、每域名速率。
