# Frontend Backend API Drift Spec

更新时间：2026-06-07

## 需求分析

【需求判断】
是真问题。现在已经有 Go 后端 route source inventory，也有 Admin Vue / Canvas Next frontend API call inventory，但两者还没有自动对齐。没有这层，前端调用是否真的落在后端当前 route 上仍要靠人工扫表。

【核心问题】
从两个已生成 artifact 出发，生成一个可重复 drift 报告：前端 exact backend API call 必须能匹配后端 route method/path；动态段统一归一成 `:param`；后端 `ANY` route 可以匹配前端具体 method。非 exact 的 parametric helper、wrapper、Next proxy、blob/download、external HTTP 调用必须隔离，不准伪装成匹配或 mismatch。

【复杂度检查】
不引入 OpenAPI，不扫运行中服务，不修改前后端业务代码。脚本只解析当前 Markdown inventory artifact。动态段归一是必要复杂度；跨函数推断 parametric helper 不是本切片目标，先显式分类并在报告里说明。

【破坏性分析】
只新增 root 脚本和知识库文档，并接入 fact checker。不修改 Go/Vue/Next runtime，不改变接口、登录、权限、构建或部署。风险是把“后端 route 未被 exact frontend 调用”误读为 bug，因此该类只作为 review backlog，不作为失败条件。

## Acceptance criteria

- 新增 `scripts/export-frontend-backend-api-drift.ps1`。
- 生成 `docs/knowledge/frontend-backend-api-drift-2026-06-07.md`。
- 报告必须引用最新：

```text
docs/knowledge/backend-route-inventory-2026-06-07.md
docs/knowledge/frontend-api-inventory-2026-06-07.md
```

- 报告 summary 必须包含：

```text
Frontend exact backend API calls compared
frontend-route-match
frontend-method-mismatch
frontend-no-backend-route
Backend admin/canvas routes not referenced by exact frontend calls
Frontend parametric backend helper calls excluded from exact matching
Frontend inventory unresolved expressions
```

- 当前 exact frontend backend calls 必须全部匹配后端 route：

```text
frontend-method-mismatch = 0
frontend-no-backend-route = 0
```

- 后端 source-only route table 必须保留，不能把 retained payment/wallet、runtime/system、queue monitor、parametric helper 这类情况吞掉。
- `scripts/check-runtime-doc-facts.ps1` 必须发现最新 drift artifact，并校验 artifact 被知识库引用、引用了两个 source inventory、且 mismatch/no-backend-route 为 0。
- 必须运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-frontend-backend-api-drift.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```
