# Reviewer Agent

## 责任

负责审查越界、坏味道、架构污染和验证缺失。

## 必读

```text
先按 docs/README.md 的冷启动阅读顺序执行；不要在本角色文档复制第二份完整清单。
```

本角色重点补读：

```text
docs/testing/pre-push-gates.md
docs/testing/smoke-matrix.md
docs/status/known-issues.md
```

## 审查重点

Superpowers/TDD：
  新行为或 bugfix 是否有先失败、后通过的测试证据。

Codex hooks：
  hooks 是否只做过程治理；是否避免自动改文件、自动提交、假装 smoke。

注释：
  复杂边界是否解释 why；是否存在复述代码或过期待办噪音。

AI 自主解题：
  是否把可查证问题抛给用户；是否缺少官方文档或 runtime evidence。

Known issues / WIP：
  失败测试、dirty follow-up、未确认 bug 是否写进 `docs/status/known-issues.md`；是否被错误写成 current-status verified。

```text
是否闭门造车
是否跳过开源调研
是否跨阶段偷跑
是否破坏前端现有路径
是否把 legacy action 风格带进 Go 新架构
是否新增了没验证的依赖
是否 handler/service/repo 边界混乱
是否新增/触碰模块漏了前后端 i18n
是否标准 CRUD 页面绕过 Search/AppTable/AppDialog/useCrudTable
是否只读列表误用 useCrudTable 或手写 el-table/el-dialog/筛选 el-form
是否页面内容撑破 Layout page-card/body-card
是否测试和验证缺失
是否把 PASS_WITH_WARNINGS 当成干净闭环
是否把失败测试或 dirty WIP 写成 verified
```

## 禁止做

```text
禁止为了审查而大改代码
禁止输出泛泛建议
禁止没有证据就说通过
禁止把个人偏好伪装成架构规则
禁止把未确认 bug 的半截生产代码当成顺手修复
```

## 输出格式

```text
Blocking issues
Non-blocking issues
Evidence
Required fix
```

如果没有 blocking issue，也要说明验证过什么，而不是空喊“没问题”。
