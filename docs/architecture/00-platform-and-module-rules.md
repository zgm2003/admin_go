# 多平台架构硬规则（R1-R8）

源 spec：`docs/superpowers/specs/2026-05-27-multi-platform-backend-boundary-design.md`

本文件是项目级硬规则。违反任一条视为架构缺陷，PR 不予合并。

## 词汇

- **platform**：业务平台，仅指 admin / app / openapi / merchant / miniapp 等业务入口
- **module**：业务能力，位于 `internal/module/{capability}/`
- **transport**：能力对某平台的 HTTP 表面，位于 `internal/module/{capability}/transport/{platform}/`
- **shared**：跨能力公共服务，位于 `internal/shared/`（dict / enum / validate / i18n / response / apperror / pagination / setting）
- **infra**：运行时技术资源层，位于 `internal/infra/`（DB / Redis / Queue / SDK / Logging）
- **adapter**：infra 内多供应商实现的角色名（如 `infra/payment/alipay`），不是层名

当前 `internal/shared` 已拥有 apperror / response / i18n / enum / validate / dict / setting；旧 root shared-like packages 已删除。`systemsetting` 仍是 admin CRUD，`shared/setting` 仍是 migrated typed settings key 的跨模块边界。小模块聚合已完成第一波：`userquickentry` 归入 `profile`、`notificationtask` 归入 `notification/task`、`exporttask` 目录改为 `export`、`authplatform` 目录改为 `auth_platform`；旧目录不得回归。

## R1. capability 命名

一个业务能力 = 一个 `internal/module/{capability}/` 目录。
capability 名只描述能力本身，永不带平台前缀。
小写下划线、单数。

## R2. 路由位置

所有对外 HTTP 路由必须位于 `internal/module/{capability}/transport/{platform}/`。
禁止 module 根目录直接出现 `route.go` / `handler.go`。
禁止"裸 transport"（`transport/route.go` 没有 platform 子目录）。
禁止同包内用 `platform_*.go` / `app_*.go` 文件前缀代替目录分层。

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
模块在 bootstrap 时向 `shared/dict.Service` 注册自己的 provider。
page-init 一律通过 `dict.PageInit(ctx, names...)` 组装。

## R7. setting 边界

模块不直接读 `system_settings` 表。
通过 `shared/setting` 边界读取，强类型 key，含默认值与缓存。

## R8. 无 legacy 框架概念

项目无 legacy / compat / fallback 框架性概念。
旧用户域 POST 路由直接删除，前端跟着改。
architecture.md 不再保留旧兼容适配、兜底桥接等段落。

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
