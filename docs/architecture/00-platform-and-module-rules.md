# 多平台架构硬规则（R1-R8）

源 spec：`docs/superpowers/specs/2026-05-27-multi-platform-backend-boundary-design.md`

本文件是项目级硬规则。违反任一条视为架构缺陷，PR 不予合并。

## 词汇

- **platform**：业务平台，仅指 admin / app / canvas / openapi / merchant / miniapp 等业务入口
- **module**：业务能力，位于 `internal/module/{capability}/`
- **transport**：能力对某平台的 HTTP 表面，位于 `internal/module/{capability}/transport/{platform}/`
- **shared**：跨能力公共服务，位于 `internal/shared/`（dict / enum / validate / i18n / response / apperror / pagination / setting）
- **infra**：运行时技术资源层，位于 `internal/infra/`（DB / Redis / Queue / SDK / Logging）
- **adapter**：infra 内多供应商实现的角色名（如 `infra/payment/alipay`），不是层名

当前架构级重构的 code/docs/frontend gates 已通过；最新 smoke 状态以 `docs/status/current-status.md` 为准。`internal/shared` 拥有 apperror / response / i18n / enum / validate / dict / setting；旧 root shared-like packages 已删除；`internal/infra` 是运行时技术资源层，旧 `internal/platform` 不得回归；HTTP 表面位于 `internal/module/{capability}/transport/{platform}`；`userquickentry` 归入 `profile`，`notificationtask` 归入 `notification/task`，`exporttask` 目录改为 `export`，`authplatform` 目录改为 `auth_platform`；AI flat modules 已迁入 `internal/module/ai/{provider,agent,tool,image,knowledge,conversation,message,chat,run}`；wallet 已迁入 `internal/module/payment/wallet`。旧目录和旧 import 路径由 backend architecture guards 保护，不得回归。

## R1. capability 命名

一个业务能力 = 一个 `internal/module/{capability}/` 目录。
capability 名只描述能力本身，永不带平台前缀。
小写下划线、单数。

## R2. 路由位置

所有对外 HTTP 路由必须位于 `internal/module/{capability}/transport/{platform}/`。
禁止 module 根目录直接出现 `route.go` / `handler.go`。
禁止"裸 transport"（`transport/route.go` 没有 platform 子目录）。
禁止同包内用 `platform_*.go` / `app_*.go` 文件前缀代替目录分层。

外部支付、第三方回调这类没有业务登录平台的 HTTP 入口，允许使用 `transport/callback/` 作为命名例外。`callback` 不是 business platform，不能出现在 platform 字典、权限平台枚举或用户会话平台里。

## R3. capability 不绑定平台

即使某能力当前只暴露一个平台入口，也必须显式放在 `transport/{platform}/` 下。
当前只有 admin 入口 **不等于** admin-only；这只是当前先实现的暴露面。

## R4. 新增平台

新增平台 = 在每个相关 module 加 `transport/{new_platform}/` + bootstrap 加一行 Register 调用。
禁止为新平台新建 `module/{platform}{capability}/`。

## R5. service 跨平台

service / repository 不依赖 `gin.Context`。
平台信息通过显式 `Platform` 入参传入 service。
service 持有的状态不区分平台。

## R6. dict 边界

模块不直接读 `internal/shared/enum` 拼 option 数组。
当前已落地的是 `internal/shared/dict` 统一 option 类型、共享枚举派生函数和 common provider registry；很多 module service 仍直接调用 `dict.*Options()` 组装 page-init，这是当前 runtime 事实。
长期方向是把跨模块字典收口到 `shared/dict.Service` provider 查询，避免每个业务 module 重复拼 common status / platform / login type options。不要在文档里声称不存在的 `dict.PageInit(ctx, names...)` 已经是当前事实；新增或触碰 page-init 时，先复用已有 `shared/dict` helper，再按窄切片推进 provider 化。

## R7. setting 边界

模块不直接读 `system_settings` 表。
通过 `shared/setting` 边界读取，强类型 key，含默认值与缓存。

## R8. 无 legacy 框架概念

项目无旧 PHP/action API 的 legacy / compat / fallback 框架性概念。
旧用户域 POST 路由直接删除，前端跟着改；不得为猜测兼容添加 silent fallback 字段、兜底分支或长期双写框架。

允许短期迁移桥，但必须同时满足：

```text
有明确 owner
有退出条件或后续删除计划
有 contract/test/smoke 覆盖证明不会破坏现有用户路径
命名写清 migration bridge，不伪装成长期 fallback
current-status 记录当前状态和缺口
```

## infra vs adapter 命名协议

- `infra/` 是层名，描述事实（运行时技术资源）
- `adapter` 是 infra 内某些实现的角色名，仅用于多供应商场景

例：

```text
infra/database          GORM wrapper（不是 adapter）
infra/redis             Redis client（不是 adapter）
infra/payment/alipay    Alipay adapter（多供应商，是 adapter 角色）
infra/storage/cos       COS adapter（同上）
```

详见 spec §0.4 与 §8。
