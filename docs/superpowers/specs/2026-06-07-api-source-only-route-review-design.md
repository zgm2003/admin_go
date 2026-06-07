# API Source-only Route Review Spec

更新时间：2026-06-07

## 需求分析

【需求判断】
是真问题。`frontend-backend-api-drift-2026-06-07.md` 已证明 exact 前端 backend calls 全部匹配后端 route，但当前还留下 19 条 backend admin/canvas source-only route。把这些 route 长期挂成一个 issue 没有用；需要分类，哪些是正常 backend-only，哪些才需要 owner 决策。

【核心问题】
从 frontend/backend API drift artifact 出发，对 source-only route 做可重复分类：runtime/system、queue monitor、retained Canvas payment/wallet、frontend parametric helper covered、owner-decision-required。只有最后一类继续当待决。

【复杂度检查】
不做运行时探测，不删除 route，不改前端。分类脚本只读 drift artifact 和固定项目规则；规则必须明确，不能把未知 route 静默归为“正常”。未知默认进入 `owner-decision-required`。

【破坏性分析】
只新增 root 脚本和知识库 artifact，并同步 known issues/status/fact checker。不修改 Go/Vue/Next runtime，不改变 API 语义。

## Acceptance criteria

- 新增 `scripts/export-api-source-only-route-review.ps1`。
- 生成 `docs/knowledge/api-source-only-route-review-2026-06-07.md`。
- 报告必须引用最新 `docs/knowledge/frontend-backend-api-drift-2026-06-07.md`。
- 19 条 source-only route 必须全部分类，且 owner-decision-required 当前必须收敛为 0 条。

- 不允许把未知 route 默认为“正常”；未知必须进 `owner-decision-required`。
- `scripts/check-runtime-doc-facts.ps1` 必须发现 latest review artifact，并校验 source-only 总数和 owner decision count。
- 必须运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-api-source-only-route-review.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```
