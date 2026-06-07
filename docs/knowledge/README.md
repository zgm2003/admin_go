# Codex Knowledge Base

这是 `E:\admin_go` 的项目知识库入口。它不替代 `docs/status/current-status.md`、API 契约、smoke、MySQL live schema，也不替代代码；它把这些事实组织成 Codex 接手任务时能快速使用的工作记忆。

## 读法

```text
1. 先读 docs/README.md 的冷启动顺序
2. 再读本目录，拿到当前项目地图和 agent 操作模型
3. 修改代码前回到对应 truth source 验证
```

## 当前知识库条目

| 文档 | 用途 | 真相源 |
| --- | --- | --- |
| `docs/knowledge/current-runtime-knowledge.md` | Go / Vue / Canvas 当前 runtime 地图 | 当前代码、status、contracts、MySQL live schema |
| `docs/knowledge/runtime-source-map.md` | Go / Vue / Canvas 源码级导航和模块/页面库存 | 当前源码树 + manifest + schema artifact |
| `docs/knowledge/runtime-inventory-2026-06-07.md` | 由脚本生成的当前源码 inventory 快照 | `scripts/export-runtime-inventory.ps1` + 当前源码树 |
| `docs/knowledge/backend-route-inventory-2026-06-07.md` | 由脚本生成的 Go 后端 route source inventory | `scripts/export-backend-route-inventory.ps1` + 当前 route source + `route_meta.go` |
| `docs/knowledge/backend-route-contract-drift-2026-06-07.md` | Go route inventory 对 contract/status/knowledge docs 的漂移报告 | `scripts/export-backend-route-contract-drift.ps1` + route inventory + Markdown docs |
| `docs/knowledge/frontend-api-inventory-2026-06-07.md` | Admin Vue / Canvas Next API call source inventory | `scripts/export-frontend-api-inventory.ps1` + 当前前端源码 |
| `docs/knowledge/frontend-backend-api-drift-2026-06-07.md` | 前端 exact API calls 对 Go route source inventory 的漂移报告 | `scripts/export-frontend-backend-api-drift.ps1` + backend/frontend inventories |
| `docs/knowledge/api-source-only-route-review-2026-06-07.md` | backend admin/canvas source-only routes 分类审查 | `scripts/export-api-source-only-route-review.ps1` + frontend/backend API drift |
| `docs/knowledge/db-schema-ownership-map-2026-06-07.md` | live MySQL 表到当前 Go source model/reference owner 的映射 | `scripts/export-db-schema-ownership-map.ps1` + latest live schema artifact |
| `docs/knowledge/full-stack-module-map-2026-06-07.md` | backend route / frontend API / live DB ownership 的模块级合成地图 | `scripts/export-full-stack-module-map.ps1` + generated source artifacts |
| `docs/knowledge/backend-capability-manifest-2026-06-07.md` | Go backend capability 到 source/service/repository/model/table/transport 的 manifest | `scripts/export-backend-capability-manifest.ps1` + route/schema ownership artifacts |
| `docs/knowledge/admin-front-source-quality-inventory-2026-06-07.md` | Admin Vue `any/as any/fallback/direct external HTTP` 债务源码库存 | `scripts/export-admin-front-source-quality-inventory.ps1` + 当前 `admin_front_ts/src` |
| `docs/knowledge/admin-front-direct-external-helper-review-2026-06-07.md` | Admin Vue direct external random-image helper 删除口径 | 当前 Admin Vue source search + guard test + generated inventories |
| `docs/knowledge/admin-front-header-breadcrumb-source-quality-review-2026-06-07.md` | Admin Vue Header breadcrumb route-walk 类型/兜底清理口径 | 当前 Header source + Vitest source guard + source-quality inventory |
| `docs/knowledge/admin-front-forgot-password-error-source-quality-review-2026-06-07.md` | Admin Vue forgot-password request-error fail-closed 清理口径 | 当前 useForgotPassword source + Vitest source/behavior guard + source-quality inventory |
| `docs/knowledge/admin-front-json-editor-source-quality-review-2026-06-07.md` | Admin Vue JsonEditor parse-error / empty-editor / i18n 清理口径 | 当前 JsonEditor source/helper + Vitest source/utility/i18n guard + source-quality inventory |
| `docs/knowledge/admin-front-dicon-source-quality-review-2026-06-07.md` | Admin Vue DIcon Element Plus dynamic-module any/as-any 清理口径 | 当前 DIcon source + Vitest source guard + source-quality inventory |
| `docs/knowledge/admin-front-editor-source-quality-review-2026-06-07.md` | Admin Vue wangEditor wrapper any/as-any/upload URL fallback 清理口径 | 当前 Editor.vue source + Vitest source guard + source-quality inventory |
| `docs/knowledge/admin-front-download-manager-source-quality-review-2026-06-07.md` | Admin Vue DownloadManager catch-any / Web fetch 静默兜底清理口径 | 当前 DownloadManager source/helper + Vitest source/utility guard + source-quality inventory |
| `docs/knowledge/admin-front-dev-test-download-source-quality-review-2026-06-07.md` | Admin Vue dev test 下载页 catch-any / 错误消息兜底清理口径 | 当前 dev test page source + Vitest source guard + source-quality inventory |
| `docs/knowledge/admin-front-validator-source-quality-review-2026-06-07.md` | Admin Vue useValidator validator input any / message fallback 清理口径 | 当前 useValidator source + Vitest source guard + source-quality inventory |
| `docs/knowledge/admin-front-upload-demo-source-quality-review-2026-06-07.md` | Admin Vue upload demo media-list any 清理口径 | 当前 upload demo source + Vitest source guard + source-quality inventory |
| `docs/knowledge/admin-front-demo-any-source-quality-review-2026-06-07.md` | Admin Vue demo any 清零口径（form/display/ParticleBackground） | 当前 demo source + Vitest source guard + source-quality inventory |
| `docs/knowledge/admin-front-ai-image-payload-source-quality-review-2026-06-07.md` | Admin Vue AI image create-task payload fallback 清理口径 | 当前 AI image API source + Vitest source guard + source-quality inventory |
| `docs/knowledge/canvas-ai-request-contract-review-2026-06-07.md` | Canvas AI `agent_id` 请求契约和 provider/model 覆盖拒绝证据 | 当前 Canvas frontend service/tests + Go Canvas AI transports/tests |
| `docs/knowledge/canvas-rbac-permission-contract-review-2026-06-07.md` | Canvas RBAC `buttonCodes` 权限码口径；确认 `canvas_ai_text_generate` 是死前端类型漂移 | 当前 Canvas frontend RBAC registry/tests + Go migration/route metadata + live MySQL permissions rows |
| `docs/knowledge/canvas-asset-route-contract-review-2026-06-07.md` | Canvas 资产页路由口径；确认 `/assets` 是唯一顶层资产页，`/asset-library` 是死页 | 当前 Canvas frontend route registry/tests + generated inventory + live MySQL permissions rows |
| `docs/knowledge/canvas-auth-logout-contract-review-2026-06-07.md` | Canvas logout 契约口径；确认前端必须先调用后端 revoke 再清本地 session | 当前 Canvas frontend auth service/store/UI/tests + Go Canvas auth transport/tests |
| `docs/knowledge/admin-user-status-contract-review-2026-06-07.md` | Admin 用户状态契约口径；确认用户列表启停必须调用专用 status route | 当前 Admin Vue user API/page/tests + Go user transport/service/route metadata |
| `docs/knowledge/admin-ai-agent-test-contract-review-2026-06-07.md` | Admin AI 智能体测试契约口径；确认智能体列表测试动作必须调用专用 test route | 当前 Admin Vue AI agent API/page/tests + Go AI agent transport/service/route metadata |
| `docs/knowledge/codex-first-agent-operating-model.md` | 本项目最贴合的 Codex-first agent 工作法 | `agents/`、Superpowers、governance scripts |
| `docs/db/mysql-live-schema-2026-06-07.md` | live MySQL 表、列、索引、行数快照 | `information_schema` + `COUNT(*)` |
| `docs/db/mysql-live-schema-2026-06-07.sql` | live MySQL 全 DDL artifact | `mysqldump --no-data` |

## 事实校验

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
powershell -ExecutionPolicy Bypass -File .\scripts\export-runtime-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-route-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-route-contract-drift.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-api-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-backend-api-drift.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-api-source-only-route-review.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-db-schema-ownership-map.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-full-stack-module-map.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-capability-manifest.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\export-admin-front-source-quality-inventory.ps1 -OutputDate 2026-06-07
```

默认模式校验 `go.mod`、`package.json`、关键 API source route、tracked schema artifact、DB schema ownership map、full-stack module map 和 backend capability manifest 是否仍与知识库一致；`-LiveSchema` 会重新查 live MySQL 并比较当前表数量。

## 不准做

```text
不准用知识库覆盖 live runtime。
不准用迁移文件猜当前表结构。
不准把历史计划写成当前事实。
不准把子仓 package/go.mod 版本写成“印象版本”。
```

知识库和运行时冲突时，以 `AGENTS.md` 的证据顺序处理：live runtime behavior > captured traffic > served assets/API > process config > persisted state > generated artifacts > checked-in source > comments/dead code。
