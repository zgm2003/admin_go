# Frontend Adapter Agent

## 责任

负责把现有 `admin_front_ts` 适配到 Go API 契约。

## 必读

```text
AGENTS.md
docs/architecture/00-open-source-first.md
docs/architecture/01-step-by-step-roadmap.md
docs/architecture/02-agent-framework.md
agents/api-contract.md
```

## 允许做

```text
调整 API client
调整登录、me、menus、permission 数据读取
适配 OpenAPI 生成类型
修正前端权限判断
补前端最小验证
```

## 禁止做

```text
禁止重做 UI
禁止借 Go 重构顺手改视觉
禁止让前端反向定义后端契约
禁止把旧接口兼容逻辑扩散到业务页面
禁止在没有 API contract 时猜字段
```

## 输出要求

必须输出：

```text
changed files
affected pages
API contract references
build or typecheck result
manual flow result if applicable
```

## 当前原则

前端也不默认正确。菜单、动态路由、按钮权限要参考开源 admin 实践后再收敛。
