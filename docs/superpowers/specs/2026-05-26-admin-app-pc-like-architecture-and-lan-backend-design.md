# Admin App PC-like Frontend Architecture and LAN Backend Design

状态：2026-05-26 补齐 Superpowers spec，供本切片实施前审阅。

## 背景

用户反馈 `admin_app/src` 目录现在出现 `composables`、`config`、`constants`、`lib`、`locales`、`pages`、`plugins` 等并列目录，和 PC admin (`admin_front_ts`) 的目录口径不一致，交接时看不懂。当前 `admin_app` 已经能跑 app auth、profile、upload 等能力，但目录命名不是项目内统一语言。

同时，`admin_app` H5 默认 API 已改为 `http://192.168.5.20:8080/api/app/v1`，真机调试需要后端 Docker 端口和 CORS 放行局域网访问，否则手机无法请求 Go 后端。

## 已验证的当前事实

- `admin_app/src` 当前顶层目录：`api`、`components`、`composables`、`config`、`constants`、`lib`、`locales`、`pages`、`plugins`、`router`、`stores`、`types`、`utils`。
- PC admin (`admin_front_ts/src`) 顶层目录：`api`、`assets`、`components`、`enums`、`hooks`、`i18n`、`lib`、`platform`、`router`、`store`、`types`、`utils`、`views`。
- `admin_app/src/pages.json` 当前页面路径仍是 `pages/login/index`、`pages/home/index`、`pages/mine/index`、`pages/profile/edit`、`pages/settings/index`。
- Go 后端代码监听默认 `HTTP_ADDR=:8080`，容器内没有问题；Docker-first compose 当前默认把宿主端口绑定到 `127.0.0.1:8080`，真机无法访问。
- Go CORS 由 `CORS_ALLOW_ORIGINS` env 显式控制；当前开发默认只覆盖 `localhost:5173` 和 `127.0.0.1:5173`，需要把 `http://192.168.5.20:5173` 加入本地联调白名单。

## 目标

1. 让 `admin_app` 目录结构和 PC admin 使用同一套项目语言：`views`、`hooks`、`store`、`i18n`、`enums`、`platform`、`lib/http`、`lib/upload`。
2. 删除或迁走让用户困惑的顶层目录：`pages`、`composables`、`stores`、`locales`、`constants`、`config`、`plugins`。
3. 保持业务行为不变：登录、session、profile、settings、upload、i18n、uview runtime 仍按现有契约工作。
4. 后端 Docker-first 本地/局域网联调可被真机访问：宿主端口允许局域网，CORS 允许 `http://192.168.5.20:5173`。
5. 通过测试锁住新架构，避免以后又新增旧目录或旧 import。

## 非目标

- 不重做 `admin_app` UI 视觉。
- 不把 To C App 改成 PC admin 的业务模块、RBAC 页面或 Layout shell。
- 不改 app API 字段、登录规则、token 格式或上传 token 契约。
- 不动用户已认可的 `admin_app/src/manifest.json` 业务配置。
- 不把机器 IP `192.168.5.20` 写成所有生产环境的唯一默认；它只服务当前局域网真机联调，生产仍使用部署域名白名单。

## 方案比较

### 方案 A：轻量对齐 PC admin 命名，保持业务行为不变（推荐）

把 `admin_app/src` 目录改成 PC admin 同款语义，但只做结构和 import 迁移。页面目录迁为 `views`，UniApp 的 `pages.json` 同步指向新路径；业务组件和 API 契约不重写。

优点：解决“看不懂”的真实痛点；改动可用测试和 build 验证；不会把 App 写成 PC 后台。缺点：一次性 import 变更较多，需要谨慎跑全量前端验证。

### 方案 B：完全照搬 PC admin 目录和工程习惯

把 `admin_app` 强行改到和 `admin_front_ts` 一比一，包括 PC 后台的更多平台层、layout 语义和 store 命名。

优点：视觉上最像 PC admin。缺点：UniApp 有 `pages.json`、tabBar、App runtime、uview-plus 等移动端边界，完全照搬会制造新别扭。

### 方案 C：只写目录规范文档，不移动代码

新增架构说明解释 `composables/config/constants` 是什么。

优点：风险最小。缺点：不能解决用户指出的“给谁用、看不懂”的核心问题。

结论：采用方案 A。

## 目标目录结构

```text
admin_app/src
├── api                 # 业务 API client：appAuth/appProfile/appUpload
├── components          # App 组件：AppCaptcha/AppMediaUploader
├── enums               # 稳定常量/枚举，例如 storage key
├── hooks               # Vue/UniApp runtime hooks，例如 useSession/usePreferences
├── i18n
│   ├── index.ts        # createI18n 实例
│   └── locales         # zh-CN/en-US 文案
├── lib
│   ├── http            # API base URL、request、response parse
│   └── upload          # COS 上传 runtime
├── platform
│   ├── app             # App/Plus 权限与端能力边界
│   └── uview           # uview-plus install/shim 兼容层
├── router              # App 页面跳转守卫
├── store               # 可测试 controller：session/preferences
├── types
├── utils
└── views               # UniApp 页面：login/home/mine/profile/settings
```

## 前端迁移规则

- `src/pages/*` 迁到 `src/views/*`，并更新 `src/pages.json` 的 `path` 和 `tabBar.pagePath`。
- `src/router/guards.ts` 的页面常量从 `/pages/...` 改成 `/views/...`。
- 页面内 `uni.navigateTo` / `uni.reLaunch` / `uni.switchTab` 统一使用新路径。
- `src/composables/*` 迁到 `src/hooks/*`，功能保持不变。
- `src/stores/*` 迁到 `src/store/*`，controller 命名保持不变。
- `src/locales/*` 和 `src/i18n.ts` 合并为 `src/i18n/index.ts` + `src/i18n/locales/*`。
- `src/constants/storage.ts` 迁到 `src/enums/storage.ts`。
- `src/config/env.ts` 迁到 `src/lib/http/env.ts`；`src/api/http.ts` 迁到 `src/lib/http/index.ts`，让 `api/` 只保留业务 client。
- `src/lib/appUploadRuntime.ts` 迁到 `src/lib/upload/appUploadRuntime.ts`。
- `src/lib/platform/appMediaPermission.ts` 迁到 `src/platform/app/appMediaPermission.ts`。
- `src/plugins/uview-*` 迁到 `src/platform/uview/*`，`vite.config.ts` 的 alias 同步更新。

## 后端局域网放行规则

- Docker Compose 宿主端口绑定从只允许 loopback 改为允许局域网：`ADMIN_API_HOST_BIND=0.0.0.0`。
- 当前真机联调环境的 `CORS_ALLOW_ORIGINS` 包含：

```env
CORS_ALLOW_ORIGINS=http://localhost:5173,http://127.0.0.1:5173,http://192.168.5.20:5173
```

- Go 代码仍只把 CORS origin 当部署入口配置，不把 IP 写成业务配置或系统设置。
- 文档要明确：前端 H5 默认请求 `http://192.168.5.20:8080/api/app/v1`；后端需要同一台开发机的 `8080` 对局域网可达。

## 测试策略

### 前端架构测试

新增 `admin_app/tests/app-architecture.test.ts`，锁定：

- 必须存在 `views/hooks/store/i18n/enums/platform/lib/http/lib/upload`。
- 不允许存在旧顶层目录 `pages/composables/stores/locales/constants/config/plugins`。
- `src/pages.json` 页面路径必须指向 `views/*`。
- 源码和测试不得再 import `@/composables`、`@/stores`、`@/constants`、`@/config`、`@/plugins`、`@/lib/platform`、`@/lib/appUploadRuntime`。

### 前端行为验证

- `npm run test:unit`
- `npm run type-check`
- `npm run build:h5`
- 如当前环境支持 App 构建，再跑 `npm run build:app`。

### 后端放行验证

- Go config/middleware/server 相关测试。
- `docker compose config --quiet` 验证 Compose env 仍合法。
- 后端启动后，用 `Origin: http://192.168.5.20:5173` 做 `/api/app/v1/auth/login-config` 预检。

## 风险与控制

- 风险：UniApp 页面迁到 `views/*` 后部分端构建不识别。控制：以 `npm run build:h5` 为必跑门槛；App 构建可用时补 `npm run build:app`。
- 风险：import 批量迁移漏改。控制：架构测试 + `rg` 禁止旧路径 + `vue-tsc`。
- 风险：后端只改前端 base URL 不改 Docker bind，真机仍无法访问。控制：同步改 Compose bind 和实际本地 env，并用真机 origin 预检验证。
- 风险：把 `192.168.5.20` 当生产默认。控制：文档区分局域网联调和生产域名。

## 验收口径

- `admin_app/src` 顶层目录和 PC admin 语言一致，不再出现旧目录。
- `admin_app/src/pages.json`、router guards、页面跳转全部使用 `views/*`。
- `admin_app` 测试、类型检查、H5 build 通过。
- 后端 Docker-first 配置允许局域网访问，CORS 允许 `http://192.168.5.20:5173`。
- 文档同步当前事实，不把 planned 写成 implemented。
