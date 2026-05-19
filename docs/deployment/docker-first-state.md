# Docker-first State Services with Baota Docker

状态：MySQL/Redis 状态服务边界说明。本文只定义状态服务 Docker 生命周期、目录、备份和连接边界；具体 schema、seed 数据、菜单权限和 migration SQL 后续单独设计。

## Project split

```text
admin-go-state
  mysql
  redis

admin-go-backend
  admin-api
  admin-worker
```

MySQL/Redis 可以用宝塔 Docker 管，但必须作为 `admin-go-state` 独立项目。它可以和后端在同一台机器，也可以放在独立状态节点；关键是不要和 `admin-go-backend` 共享 Compose 生命周期。

## Why split lifecycle

```text
应用可重建，状态要保护。
```

后端发布会频繁执行 `up -d --build`、`restart`、回滚。MySQL/Redis 承载数据，不允许因为后端发布误触 `down -v`、删除数据卷、重启数据库或清空 Redis。

## Server directories

```text
/www/docker/admin-go-state/mysql   # MySQL data/config/backup mount root
/www/docker/admin-go-state/redis   # Redis data/config mount root
/www/docker/admin-go-backend       # backend compose working directory
```

## Production rules

```text
1. MySQL/Redis 镜像固定版本，不使用 latest。
2. MySQL 数据必须有备份/恢复步骤。
3. Redis 设置密码，不暴露公网端口。
4. MySQL/Redis 端口只绑定本机或内网，公网必须由安全组/防火墙拒绝。
5. 后端通过 Docker network、宿主本地端口或内网 IP 连接 state。
6. 后端 Compose 不包含 mysql/redis 服务。
```

## Migration boundary

Docker 启动 MySQL 不等于数据库初始化完成。首次部署和升级仍需要单独 SQL/migration runbook：

```text
创建 database / user / 权限
导入 baseline SQL
执行 migration SQL
校验菜单、权限、system_settings、基础配置表数据
```

本切片不设计具体 SQL。迁移是显式步骤，应用启动是显式步骤；不要让 `admin-api` 或 `admin-worker` 容器启动时自动改库。
