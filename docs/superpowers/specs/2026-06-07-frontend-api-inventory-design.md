# Frontend API Inventory Spec

更新时间：2026-06-07

## 需求分析

【需求判断】
是真问题。后端 route inventory 和 contract drift 已经闭合到源码/契约层，但前端仍缺一份从当前 Vue 管理端和 Canvas Next 源码生成的 API 调用清单。没有这层，后续做前后端 API drift 只能靠人工扫文件，容易把 blob 下载、Next proxy、外部 helper 误判成后端契约问题。

【核心问题】
生成一个可重复的 frontend API source inventory：明确哪些调用落在 `/api/admin/v1`、`/api/canvas/v1`，哪些只是 wrapper/proxy/blob/external，不猜复杂运行时 URL，不用默认值掩盖未知表达式。

【复杂度检查】
不引入 OpenAPI 生成器，不重构前端，不修改 API runtime。脚本只读取当前源码，用 TypeScript AST 提取 call expression，再输出 Markdown inventory。解析边界必须明示：能解析 literal、简单 const、简单 template；复杂 URL 要分类或列为 unresolved，不能兜底猜路径。

【破坏性分析】
只新增 root 脚本和文档 artifact，并把 artifact 接入知识库和 runtime fact checker。不修改 `admin_front_ts`、`canvas_front_next` 业务代码，不改变接口、登录、权限、构建或部署。

## Acceptance criteria

- 新增 `scripts/export-frontend-api-inventory.ps1`。
- 生成 `docs/knowledge/frontend-api-inventory-2026-06-07.md`。
- inventory 必须覆盖 active source roots：

```text
admin_front_ts/src/api
admin_front_ts/src/lib
admin_front_ts/src/hooks
admin_front_ts/src/views
admin_front_ts/src/components
canvas_front_next/src/services
canvas_front_next/src/app
canvas_front_next/src/features
canvas_front_next/src/stores
canvas_front_next/src/hooks
```

- inventory 必须排除 `*.test.ts`、`*.test.tsx`、`*.d.ts`。
- inventory 必须包含 summary count：

```text
Frontend API calls found
Admin frontend backend API calls
Canvas frontend backend API calls
External HTTP helper calls
Dynamic blob/download URL calls
Wrapper/proxy infrastructure calls
Parametric backend admin helper calls
Backend /api calls outside known prefixes
Unresolved frontend API expressions
```

- inventory 必须能证明这些关键 source calls 存在：

```text
GET /api/admin/v1/users/me
GET /api/canvas/v1/users/me
POST /api/canvas/v1/auth/logout
```

- `Unresolved frontend API expressions` 必须为 `0`；确实不能精确还原的调用要进入明确分类，例如 `blob/download`、`next-proxy`、`wrapper-internal`、`backend-admin-parametric`。
- `scripts/check-runtime-doc-facts.ps1` 必须发现最新 frontend API inventory，并校验知识库引用和关键 source calls。
- 必须运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-api-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```
