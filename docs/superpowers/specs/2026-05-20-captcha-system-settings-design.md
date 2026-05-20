# Captcha 系统设置迁移与前缀内置设计

日期：2026-05-20
状态：draft
范围：`admin_back_go` 的 CAPTCHA 运行时配置、`system_settings` 读写、部署 env 模板、smoke 辅助脚本

## 目标

这次只做 **captcha 一个模块**，不顺手扩别的配置。

要达到的结果很简单：

1. `CAPTCHA_TTL` 和 `CAPTCHA_SLIDE_PADDING` 不再放在 env 里。
2. CAPTCHA Redis 前缀不再暴露为 env，直接内置在代码里。
3. env 尽量短，只保留真正的启动/拓扑/密钥类配置。
4. 验证码的可调参数可以在后台轻松改，改完无需重启。

## 当前事实

- `captcha` 模块已经存在，且当前只支持 slide。
- 现在的 bootstrap 通过 `cfg.Captcha.TTL`、`cfg.Captcha.RedisPrefix`、`cfg.Captcha.SlidePadding` 构造服务。
- `system_settings` 已经是可用的后端配置表，且支持 number/string/bool/json。
- 现有 `system/setting` 页面已经能列表、编辑、启停、复制 value，不需要先造一套新 CRUD。
- `auth.verify_code.ttl_minutes` 已经是一个成功的“env → system_settings”先例。

## 选型

### 方案 A：复用现有 system settings（推荐）

把 captcha 的可变参数作为系统设置项，继续走现成的 `/system-settings` CRUD。

优点：

- 改动最小。
- 路径最清楚。
- 不用新增新表、新接口、新配置层。

### 方案 B：单独做一个 captcha 配置页

做一个 `/system/captcha` 之类的专页，只显示这两个值。

优点：

- UX 更直观。

缺点：

- 这次会比必要范围更大。

### 方案 C：继续放 env

不采用。

原因：

- env 不适合业务可调策略。
- 用户改配置要碰容器/重启，太重。
- 也不符合当前仓库“能进系统设置就不进 env”的收口方向。

## 推荐设计

### 1. 系统设置 key

只新增两个业务键：

- `auth.captcha.ttl_minutes`
- `auth.captcha.slide_padding`

建议值：

- `auth.captcha.ttl_minutes = 2`
- `auth.captcha.slide_padding = 10`

备注建议：

- `验证码有效期分钟数`
- `滑块容差像素`

### 2. Redis 前缀

`captcha:slide:` 变成代码内置常量，不再做成 env，也不做成系统设置。

原因很直接：

- 这是实现命名空间，不是业务策略。
- 暴露给后台没有实际价值。
- 只会增加用户认知和配置面。

### 3. 后端运行时

`captcha` 服务不再从 `config.Captcha.RedisPrefix` 取值。

推荐做法：

- 新增一个 captcha policy 读取边界，读取 `auth.captcha.ttl_minutes` 和 `auth.captcha.slide_padding`。
- bootstrap 注入这个 policy。
- service 在生成/校验时按需读取当前值。
- 读取失败、缺失、禁用、类型不对，都按配置错误处理，别静默猜。

这样能保持：

- 业务值在 DB
- 基础设施常量在代码
- env 只留真正的运行环境项

### 4. 前端

第一版不新增 captcha 专页。

直接复用现有 `system/setting` 页面维护这两个 key 就够了。

如果后面觉得通用列表太杂，再补一个快捷入口页，但不放进这次切片。

### 5. Smoke / 辅助脚本

`basic-admin-smoke.ps1` 和 `full-admin-smoke.ps1` 里现在用的 `CAPTCHA_REDIS_PREFIX` 要改成固定内置前缀。

原因：

- 运行时已经不再暴露这个 env。
- smoke 只是跟着真实 runtime 读同一个默认前缀。

## 迁移范围

### 需要改

- `admin_back_go/internal/config/config.go`
- `admin_back_go/internal/bootstrap/app.go`
- `admin_back_go/internal/module/captcha/*`
- `admin_back_go/internal/module/systemsetting` 读写边界（如需）
- `admin_back_go/database/migrations/*`
- `admin_back_go/deploy/docker-first/admin-go.env`
- `admin_back_go/deploy/docker-first/admin-go.env.example`
- `admin_back_go/README.md`
- `docs/deployment/*` 里所有 `CAPTCHA_` 相关说明
- `admin_back_go/scripts/basic-admin-smoke.ps1`
- `admin_back_go/scripts/full-admin-smoke.ps1`

### 不改

- `auth_platforms` 逻辑
- `verify_code` 的 system setting 方案
- CAPTCHA 公共 API 的响应结构
- 登录流程的 slide 形态

## 验证标准

实施后至少要满足：

1. `admin-go.env` 里不再出现 `CAPTCHA_TTL` / `CAPTCHA_REDIS_PREFIX` / `CAPTCHA_SLIDE_PADDING`。
2. `captcha` 仍能正常生成、验证。
3. `/api/admin/v1/auth/login` 的 slide captcha 登录流程不回退。
4. 系统设置页能修改 `auth.captcha.ttl_minutes` 和 `auth.captcha.slide_padding`，修改后生效。
5. `captcha:slide:` 仍可被 smoke/test 读取，但不再依赖 env。

## 测试要求

实现阶段至少跑：

- `go test ./internal/module/captcha ./internal/bootstrap ./internal/config`
- `go test ./...`
- `powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working`
- `git diff --check`
- 相关 smoke 一轮，确认 captcha + login 没坏

## 风险

- 如果设置行被删或禁用，captcha 读取会失败；这是配置错误，不是静默 fallback。
- system settings 页面会比专页更通用，但这版先优先控制切片大小。
- prefix 内置后，未来如果真要改命名空间，只能走代码迁移，不是后台改值。
