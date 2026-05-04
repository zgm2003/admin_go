# 2026-05-04 System Log Go Migration Plan

## Goal

把旧 PHP `SystemLog` 页面迁到 Go 后端，并把运行日志基建从“只能 stdout 打 JSON”升级成可审计、可轮转、可只读浏览的系统日志能力。

## Scope

第一期只做：

- Go 运行日志文件输出：继续用官方 `log/slog`，文件轮转用 `lumberjack`。
- 只读系统日志 API：列文件、读 tail 行、按 level/keyword 过滤。
- 前端系统日志页从 `legacyRequest` 改为 Go REST API。
- 同步架构、契约、迁移状态、smoke matrix 文档。

第一期明确不做：

- 不做删除、清空、下载日志。
- 不接 ELK/Loki/Grafana。
- 不把 `operationlog` 和 `systemlog` 混成一个模块。
- 不兼容旧 PHP 全 POST 路由。

## Architecture

```text
cmd/admin-api -> bootstrap logger -> slog JSON stdout + optional lumberjack file
server route -> module/systemlog -> platform/logstore -> OS log files
```

边界：

- `operationlog` 是后台用户操作审计，数据库是事实源。
- `systemlog` 是系统运行日志文件浏览，只读，文件系统是事实源。
- `platform/logstore` 才能碰 OS 文件；handler/service 不直接拼路径读文件。

## REST Contract

```text
GET /api/admin/v1/system-logs/init
GET /api/admin/v1/system-logs/files
GET /api/admin/v1/system-logs/files/:name/lines?tail=500&level=ERROR&keyword=db
```

返回仍保持 `{ code, data, msg }`。`:name` 支持 URL escaped 的一级子目录形式，比如 `worker%2Fadmin-worker.log`。

## Safety Rules

- 文件名必须是相对路径，禁止绝对路径、`..`、空字节、反斜杠路径穿越。
- 只允许配置的扩展名，默认 `.log`。
- 只扫描根目录和一级子目录，不递归深层目录。
- tail 行数受 `LOG_MAX_TAIL_LINES` 限制。
- 过滤在 tail 后执行，不一次性读完整大文件。

## Implementation Checklist

- [ ] `internal/platform/logstore`：文件枚举、安全校验、tail、level/keyword filter。
- [ ] `internal/config`：增加 LoggingConfig。
- [ ] `internal/platform/logging`：构造 `slog.Logger`，stdout + 可选 lumberjack file。
- [ ] `internal/module/systemlog`：route/handler/service/request/dto。
- [ ] `internal/server` / `internal/bootstrap`：注入 systemlog service 并注册路由。
- [ ] `internal/enum` / `internal/dict`：日志级别和 tail 字典。
- [ ] 前端 `src/api/system/log.ts`：改 Go REST typed API。
- [ ] 前端 `src/views/Main/system/log/index.vue`：消费新 lines DTO，不用 legacy。
- [ ] 文档：contract/current-status/architecture/smoke matrix。

## Verification

Backend:

```powershell
go test ./internal/platform/logstore ./internal/config ./internal/module/systemlog ./internal/server ./internal/bootstrap
go test -p=1 ./...
go vet -p=1 ./...
git diff --check
```

Frontend touched area:

```powershell
npx vue-tsc -b --pretty false
npx eslint src/api/system/log.ts src/views/Main/system/log/index.vue
```

Race detector 暂不作为通过条件：当前 Windows 环境缺 `gcc`，此前已验证会报 `cgo: C compiler "gcc" not found`。
