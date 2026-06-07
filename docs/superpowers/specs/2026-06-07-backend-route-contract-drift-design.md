# Backend Route Contract Drift Spec

更新时间：2026-06-07

## 需求分析

【需求判断】
是真问题。已经有 Go 后端 route source inventory，但还缺一层“这些 route 在契约/状态文档里到底有没有被提到”的可重复漂移视图。

【核心问题】
从最新版 Go route inventory 出发，生成 route 与 `docs/contracts/*`、`docs/status/*`、`docs/knowledge/*` 的引用覆盖报告。报告只暴露证据，不把 prefix mention 包装成 exact contract。

【复杂度检查】
不引入 OpenAPI，不自动重写契约，不靠人工列表维护。脚本读取已生成的 `backend-route-inventory-YYYY-MM-DD.md`，再扫描现有文档文本，输出 exact/prefix/source-doc 分类。

【破坏性分析】
只新增 root 文档/脚本并接入 fact checker；不修改 Go/Vue/Next runtime，不修改 API 语义。风险是误把宽泛文本当契约，因此分类必须区分：

```text
contract exact       # docs/contracts 明确包含完整 path
contract prefix only # 只提到资源前缀，不等于完整契约
source docs only     # status/knowledge 有引用，contract 没有 exact
undocumented exact   # 没有 exact contract 引用
```

## Acceptance criteria

- 新增 `scripts/export-backend-route-contract-drift.ps1`。
- 生成 `docs/knowledge/backend-route-contract-drift-2026-06-07.md`。
- 报告必须引用最新 `docs/knowledge/backend-route-inventory-2026-06-07.md`。
- 报告必须包含 route 总数、contract exact、contract prefix-only、source-doc-only、undocumented exact 统计。
- `callback` surface 继续作为 HTTP callback exception，不当作 business platform。
- `scripts/check-runtime-doc-facts.ps1` 必须校验最新 drift artifact 存在、被知识库引用、route 总数与最新 route inventory 一致。
- 必须运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-backend-route-contract-drift.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

