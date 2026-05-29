# Superpowers Docs Index

状态更新时间：2026-05-29

本目录是 `E:\admin_go` 的 Superpowers spec / plan / review 总入口。它记录设计和执行过程，不替代 runtime truth。

## 目录职责

```text
specs/      # 已批准或正在使用的设计规格；解释为什么做、边界是什么
plans/      # 可执行计划；解释怎么按任务落地、验证、回滚
reviews/    # 阶段收口审查；记录证据、缺口和 reviewer 结论
archive/    # 历史 spec/plan 归档；只能用于考古和 provenance
```

不在子仓维护第二套 Superpowers：

```text
admin_back_go/docs/superpowers   # 禁止新增 active spec/plan
admin_front_ts/docs/superpowers  # 禁止新增 active spec/plan
```

## Truth boundary

Superpowers 文档不是当前事实源。证据冲突时顺序固定：

```text
live runtime / smoke / served API / process config
> docs/status/current-status.md
> docs/status/module-matrix.md
> contracts / architecture / testing docs
> docs/superpowers/specs|plans|reviews
> docs/superpowers/archive
```

规则：

```text
spec 通过 != runtime implemented
plan task 勾选 != smoke 通过
review 通过 != future slices 自动完成
archive 只解释历史，不覆盖 current-status / module-matrix
```

## Active doc rules

新 Superpowers 文档默认放在 root：

```text
docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md
docs/superpowers/plans/YYYY-MM-DD-<topic>.md
docs/superpowers/reviews/YYYY-MM-DD-<topic>-review.md
```

活跃 spec/plan/review 如果要更新当前状态，必须指向：

```text
docs/status/current-status.md   # 当前入口、关键事实、验证缺口
docs/status/module-matrix.md    # per-module 当前明细
```

不要再把 `docs/status/current-status.md` 当成巨大 module detail 的唯一落点；模块分组明细写入 `module-matrix.md`。

2026-05-29 之前写下的计划可能仍写着“更新 `current-status` 某某 module row”。执行这些旧计划时按新分层解释：

```text
key status summary / verification gap -> docs/status/current-status.md
per-module section / module implementation detail -> docs/status/module-matrix.md
historical verification narrative -> docs/status/archive/*.md
```

## Archive rules

只在这些情况读 `archive/`：

```text
用户明确要求考古
需要追溯为什么做过某个架构决定
需要确认旧计划不是当前事实源
```

旧文档如果停止作为 active spec/plan/review，移动到 `archive/` 后必须满足：

```text
不保留完整冷启动清单
不保留当前 mandatory gate
不声称 archive 里的 planned/implemented 仍是当前状态
开头或 README 明确它是 historical/provenance
```

## Maintenance checks

文档维护收口至少跑：

```powershell
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

如果 Superpowers 文档改变了 runtime/status/contract 口径，还要同步检查：

```text
docs/status/current-status.md
docs/status/module-matrix.md
docs/contracts/*.md
docs/testing/*.md
docs/architecture/*.md
admin_back_go/docs/architecture.md
```
