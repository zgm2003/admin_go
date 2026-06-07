# Backend Route Inventory Spec

更新时间：2026-06-07

## 需求判断

【需求判断】
是真问题。当前 `runtime-inventory` 只有 route fragments，不能直接回答“哪个 capability/surface 暴露了哪些 source route、哪些 route 有 route_meta 权限码”。继续靠人工扫 Go route 文件会漂移。

【核心问题】
从当前 Go 源码生成一个后端 route inventory artifact，并明确它是 source inventory，不是 served endpoint smoke proof。

【复杂度检查】
不引入 OpenAPI 生成器、不运行服务、不反射 Gin engine。先用 PowerShell 读取当前 `route.go` / `*_route.go` 和 `internal/bootstrap/route_meta.go`，只解析源码中能证明的 literal/const/group 信息。

【破坏性分析】
只新增 root 文档和脚本，不修改 Go/Vue/Next runtime。风险是解析器误把无法证明的路径写成 full path；因此无法解析的表达式必须显式标记为 `unresolved`，不能兜底猜测。

## Acceptance criteria

- 新增 `scripts/export-backend-route-inventory.ps1`。
- 生成 `docs/knowledge/backend-route-inventory-2026-06-07.md`。
- artifact 至少包含：capability、surface、route file、line、method、group prefix、route argument、inferred full path、path kind、callback exception、permission code、operation metadata。
- `callback` surface 必须写成 HTTP callback exception，不是 business platform。
- 知识库入口和 current runtime knowledge 必须引用最新 artifact。
- `scripts/check-runtime-doc-facts.ps1` 必须校验最新 backend route inventory artifact 存在并被知识库引用。
- 必须运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-route-inventory.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```
