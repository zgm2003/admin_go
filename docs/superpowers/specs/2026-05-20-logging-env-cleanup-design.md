# Logging env 收口设计

日期：2026-05-20
状态：draft
范围：`admin_back_go` 日志运行时配置、Docker-first env 模板、系统日志读取契约、相关文档和测试

## 目标

这次只做 **logging env cleanup**，不重做日志系统、不引入 ELK/Loki、不改系统日志页面交互。

要达到的结果：

1. Docker-first env 里日志配置尽量短，只保留真实部署路径。
2. 日志文件名、轮转策略、可读扩展名、最大 tail 行数等实现策略全部代码内置。
3. 保持容器 stdout 与文件日志并存，方便 Docker/宝塔面板看运行状态，也方便后台系统日志页面读取文件。
4. 不把日志初始化依赖 `system_settings`，避免 DB 未连接前没有可靠日志。

## Linus 三问

1. 这是真问题吗？
   - 是。当前 Docker-first env 暴露 10+ 个 `LOG_*` 键，大部分是产品默认策略或实现细节，部署用户不应该逐项理解和修改。
2. 有更简单的做法吗？
   - 有。只保留 `LOG_DIR`，其余使用代码默认值；不新增表、不新增后台页面、不扩大日志平台能力。
3. 会破坏已有前端、接口、登录和权限吗？
   - 不应该。日志文件仍写到同一目录，系统日志 API 仍按目录读取 `.log` 文件，前端系统日志页面契约不变。

## 当前事实

Docker-first env 当前暴露：

```env
LOG_ENABLE_FILE=true
LOG_DIR=/app/runtime/logs
LOG_FILE_NAME=admin-api.log
LOG_API_FILE_NAME=admin-api.log
LOG_WORKER_FILE_NAME=admin-worker.log
LOG_MAX_TAIL_LINES=2000
LOG_ALLOWED_EXTENSIONS=.log
LOG_FILE_MAX_SIZE_MB=64
LOG_FILE_MAX_BACKUPS=7
LOG_FILE_MAX_AGE_DAYS=14
LOG_FILE_COMPRESS=true
```

这些键可以分成两类：

| env key | 当前含义 | 判断 | 目标 |
| --- | --- | --- | --- |
| `LOG_DIR` | 文件日志目录 | 部署路径，和 Docker volume/宝塔宿主机挂载有关 | 保留 env |
| `LOG_ENABLE_FILE` | 是否写文件日志 | 产品默认能力，Docker-first 应默认开启 | 内置 `true` |
| `LOG_FILE_NAME` | 旧的单进程日志文件名 | 兼容残留，实际有 API/worker 分文件名 | 删除 env，必要时只保留内部兼容 |
| `LOG_API_FILE_NAME` | API 进程日志文件名 | 固定约定 | 内置 `admin-api.log` |
| `LOG_WORKER_FILE_NAME` | worker 进程日志文件名 | 固定约定 | 内置 `admin-worker.log` |
| `LOG_MAX_TAIL_LINES` | 后台最多读取行数 | 安全/性能上限 | 内置 `2000` |
| `LOG_ALLOWED_EXTENSIONS` | 允许读取的日志扩展名 | 安全白名单 | 内置 `.log` |
| `LOG_FILE_MAX_SIZE_MB` | 单文件轮转大小 | 运维默认策略 | 内置 `64` |
| `LOG_FILE_MAX_BACKUPS` | 备份文件数 | 运维默认策略 | 内置 `7` |
| `LOG_FILE_MAX_AGE_DAYS` | 保留天数 | 运维默认策略 | 内置 `14` |
| `LOG_FILE_COMPRESS` | 是否压缩归档 | 运维默认策略 | 内置 `true` |

## 选型

### 方案 A：把日志策略迁到 `system_settings`

不推荐。

原因：

- 日志初始化早于 DB 和 `system_settings` 可用性。
- 启动失败、DB 不通、migration 出错时，日志仍必须可靠输出。
- 系统设置适合业务策略，不适合启动期日志基础设施策略。

### 方案 B：保留全部 `LOG_*` env

不采用。

原因：

- env 过长，违背当前 Docker-first “用户只改必要项”的方向。
- 大多数值用户改错只会制造不可观测或日志读取风险。
- `LOG_FILE_NAME`、`LOG_API_FILE_NAME`、`LOG_WORKER_FILE_NAME` 同时存在，对普通部署用户没有价值。

### 方案 C：只保留 `LOG_DIR`，其余内置（推荐）

内容：

- Docker-first env 只保留：

```env
LOG_DIR=/app/runtime/logs
```

- 其余日志策略使用代码默认值。
- 系统日志 API 继续从 `LOG_DIR` 读取允许扩展名内的日志文件。

优点：

- env 一次减少约 10 个键。
- 启动期日志不依赖 DB。
- 保留用户真正需要改的部署路径。
- 现有日志页面、文件轮转、API/worker 分文件不需要产品改版。

缺点：

- 如果极少数部署要调整轮转大小或保留天数，需要发版或另做专门设计，不再靠 env 热改。

推荐采用。

## 推荐设计

### 1. Docker-first env 只保留日志目录

最终 Docker-first env 中日志部分变为：

```env
LOG_DIR=/app/runtime/logs
```

说明：

- `LOG_DIR` 是容器内路径，必须和 volume 挂载保持一致。
- 宝塔/宿主机只需要关心把宿主目录挂载到容器 `/app/runtime` 或 `/app/runtime/logs`。
- 不再要求用户理解日志文件名、轮转、压缩和读取白名单。

### 2. 日志策略代码内置

代码默认值：

```text
enable_file=true
api_file_name=admin-api.log
worker_file_name=admin-worker.log
max_tail_lines=2000
allowed_extensions=.log
file_max_size_mb=64
file_max_backups=7
file_max_age_days=14
file_compress=true
```

处理 `LOG_FILE_NAME`：

- 对 Docker-first env 不再暴露。
- 代码层可删除该 env 读取；如为了最小改动保留结构字段，也必须让 Docker-first 模板不再文档化。
- API/worker 进程使用明确的内置文件名，不依赖用户设置。

### 3. 不进 `system_settings`

本切片不新增任何系统设置 key。

理由：

- 文件日志是启动期基础设施。
- DB 不可用时仍要能写启动日志。
- `system_settings` 不能变成所有默认值的 dumping ground。

### 4. 系统日志页面契约不变

不改：

- 系统日志文件列表 API。
- 系统日志 tail/lines API。
- 前端系统日志页面。
- 路径穿越防护。
- `.log` 白名单语义。

只改变默认值来源：从 env 读取变为代码内置。

### 5. stdout 行为保持

保留当前 stdout/stderr 输出行为。

文件日志默认开启后：

- Docker logs 仍可看到关键日志。
- `/app/runtime/logs/admin-api.log` 写 API 进程日志。
- `/app/runtime/logs/admin-worker.log` 写 worker 进程日志。
- 后台系统日志页面继续读这些文件。

## 迁移范围

### 需要改

后端仓 `admin_back_go`：

- `internal/config/config.go`
- `internal/config/config_test.go`
- `internal/config/logging_test.go`
- `internal/config/logging_process_test.go`
- `deploy/docker-first/admin-go.env.example`
- 本地 ignored 的 `deploy/docker-first/admin-go.env` 如果存在，也同步删除除 `LOG_DIR` 以外的日志 env
- 如 README 或 backend docs 直接列出 `LOG_*`，同步更新

根仓 `admin_go`：

- `docs/deployment/docker-first-backend.md`
- `docs/status/current-status.md`
- `docs/testing/smoke-matrix.md` 如有日志 env 口径
- 相关 Superpowers plan

### 不改

- `internal/platform/logging` 的核心写日志能力。
- `internal/platform/logstore` 的读取接口形状。
- `internal/module/systemlog` REST contract。
- 前端系统日志页面。
- Docker volume 目录结构。
- MySQL/Redis/APP_SECRET/queue/realtime/scheduler/AI/CORS 等其他 env 组。

## 行为保持

不改变：

- 默认写文件日志。
- API 与 worker 分别写不同日志文件。
- 日志目录默认仍是 `/app/runtime/logs`。
- 后台最多读取 2000 行。
- 只允许读取 `.log` 扩展名。
- 单文件 64MB、7 个备份、14 天、压缩归档。

行为变化：

- Docker-first env 不再接受这些日志策略作为用户配置入口。
- 如果用户旧 env 里仍保留这些键，实现可选择忽略它们；文档与模板不再展示。
- 新部署只需要确认 `LOG_DIR` 和 volume 挂载正确。

## 错误处理

- `LOG_DIR` 为空或不可写时，文件日志初始化应降级到 stdout 或返回清晰错误，遵循现有 logging bootstrap 语义。
- 日志文件读取仍必须限制在 `LOG_DIR` 内，不能因为内置扩展名改变路径穿越防护。
- 若日志目录不存在，保持现有创建目录或报错行为；本切片不改变该策略。

## 测试要求

实现阶段至少跑：

```powershell
cd E:\admin_go\admin_back_go
go test -count=1 ./internal/config ./internal/platform/logging ./internal/platform/logstore ./internal/module/systemlog
```

如果改到 bootstrap 初始化，再补：

```powershell
go test -count=1 ./internal/bootstrap ./internal/server
```

根仓治理：

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Docker-first 验证建议：

```powershell
cd E:\admin_go\admin_back_go\deploy\docker-first
docker compose config --quiet
docker compose up -d --build admin-api admin-worker
```

然后验证：

- `/health`
- `/ready`
- `admin-api.log` 存在并有新日志
- `admin-worker.log` 存在并有新日志或 worker 启动日志
- 系统日志页面/API 能列出并读取 `.log` 文件

## 文档要求

需要把以下口径统一：

1. Docker-first env 的日志组只保留 `LOG_DIR`。
2. 日志文件名和轮转策略是代码内置默认值。
3. `LOG_DIR` 是部署路径，需要与 volume 挂载匹配。
4. 日志策略不进入 `system_settings`。
5. 后台系统日志页面读取文件日志，不负责修改日志运行策略。

## 风险

- 少数部署如果确实需要改日志保留天数或轮转大小，实施后不能直接改 env；需要新设计或发版。
- 如果实现阶段直接删除结构字段，相关测试和文档必须同步，否则会出现旧 env 文档残留。
- 文件日志默认开启会继续占用磁盘；但 64MB、7 backups、14 days、compress 的默认轮转能控制单进程日志增长。

## 审阅清单

请重点确认：

1. 是否接受 Docker-first env 日志组只保留 `LOG_DIR`。
2. 是否接受日志策略不进入 `system_settings`。
3. 是否接受 API/worker 日志文件名固定为 `admin-api.log` / `admin-worker.log`。
4. 是否接受轮转策略固定为 64MB、7 backups、14 days、compress。
