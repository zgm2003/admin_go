# DB Schema Ownership Map Spec

更新时间：2026-06-07

## 需求分析

【需求判断】
是真问题。当前已经有 live MySQL schema snapshot，但 Codex 看到一张表时仍需要人工追 Go 模型、repository 和模块归属。总目标要求表结构必须从 MySQL 查验；下一步应该把 live table 与当前 Go source ownership 接起来。

【核心问题】
以 `docs/db/mysql-live-schema-2026-06-07.md` 为表清单真相源，生成每张 live table 的 Go model owner candidates、reference owners、coverage 分类。源码只能解释 ownership，不能覆盖 live schema。

【复杂度检查】
不解析迁移历史，不连接 DB 二次查询，不改 Go 代码。脚本只读 latest live schema artifact 和当前 Go source。识别 `TableName() string`、`.Table("...")` 和非 transport Go 源码中的精确表名引用；无法证明 owner 时保持 `live-schema-only` 或 `go-reference-only`，不兜底猜 owner。

【破坏性分析】
只新增 root 文档/脚本并接入 fact checker。不修改数据库、Go runtime、Vue/Next runtime、API、登录或权限。

## Acceptance criteria

- 新增 `scripts/export-db-schema-ownership-map.ps1`。
- 生成 `docs/knowledge/db-schema-ownership-map-2026-06-07.md`。
- 报告必须引用最新 live schema artifact：

```text
docs/db/mysql-live-schema-2026-06-07.md
docs/db/mysql-live-schema-2026-06-07.sql
```

- 报告必须覆盖 live schema 中全部 `56` 张 base tables。
- 报告必须包含 coverage summary：

```text
go-model
explicit-table-call
go-reference-only
live-schema-only
```

- 未能通过 Go model 证明的表必须进入 “Tables without Go model ownership”，不能被默认归属。
- `scripts/check-runtime-doc-facts.ps1` 必须发现 latest ownership map，并校验表数与 latest live schema artifact 一致。
- 必须运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\export-db-schema-ownership-map.ps1 -OutputDate 2026-06-07
powershell -ExecutionPolicy Bypass -File .\scripts\check-runtime-doc-facts.ps1 -LiveSchema
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```
