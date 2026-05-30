# Frontend GitHub Actions SCP Deployment

Canonical location: `E:/admin_go/docs/deployment/frontend-github-actions-scp.md`.

This runbook was moved from `admin_front_ts/docs/deployment/github-actions-scp.md` because frontend deployment is a workspace-level deployment concern, not frontend runtime code truth.

---
# GitHub Actions 部署到宝塔

目标就一个：`master` 推送后，GitHub Actions 构建 `dist`，然后通过 SSH 放到宝塔站点目录。

## GitHub Secrets

在当前 frontend 仓库配置 Actions，不要去固定上游仓库配置。上游仓库只是示例：

```text
<frontend_repo_url>
# example: https://github.com/zgm2003/admin_front_ts
```

GitHub 里配置这些 Repository secrets 或 variables。`SSH_PRIVATE_KEY` 必须是 secret；服务器地址、用户、端口和目录可以放 secret，也可以放 variable。

```text
Settings -> Secrets and variables -> Actions -> Repository secrets
Settings -> Secrets and variables -> Actions -> Repository variables
```

```text
SSH_PRIVATE_KEY=部署用户的 SSH 私钥
SSH_HOST=服务器 SSH host
SSH_PORT=服务器 SSH port，未配置时 workflow 默认 22
SSH_USER=服务器 SSH 用户
DEPLOY_PATH=宝塔站点目录，例如 /www/wwwroot/<domain>
```

不要把机器 IP、`root` 用户或站点目录写死在 workflow。当前生产值只放在 GitHub Actions secrets / variables 里；换机器、换域名、fork 仓库或多环境部署时，只改 Actions 配置，不改 workflow。

注意：宝塔面板端口不参与 CI。CI 只用服务器 SSH 端口；端口值以 `SSH_PORT` 为准，默认 `22`。

## Workflow

文件：

```text
.github/workflows/deploy-admin-front.yml
```

流程：

```text
checkout
setup node 22.12.0
npm ci
npm run build
tar dist
scp 到服务器 /tmp/admin_front_ts_dist.tar.gz
清空 DEPLOY_PATH 里的旧静态文件
解压 dist
chown -R www:www DEPLOY_PATH
```

workflow 会显式拒绝缺失的 `SSH_HOST`、`SSH_USER`、`SSH_PRIVATE_KEY`、`DEPLOY_PATH`，并拒绝 `DEPLOY_PATH=/`，避免配置不完整时误清目录。

## 宝塔 Nginx 必须有 history 回退

Vue 刷新页面不 404，站点配置里要有：

```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

WebSocket 使用当前 Go Realtime contract。浏览器不能稳定给原生 WebSocket 加 `Authorization` header；当前前端 token cookie 默认是前端域名下的 host-only cookie，所以生产推荐让 WebSocket 走前端同域，再由宝塔反代到 Go 后端：

```text
wss://<frontend-domain>/api/admin/v1/realtime/ws
```

如果你刻意改成共享父域 cookie，才考虑 `wss://<api-domain>/api/admin/v1/realtime/ws`；不要把这个当默认方案。

宝塔 Nginx 必须保留 `Upgrade` / `Connection` header，并把 `/api/admin/v1/realtime/ws` 反代到 Go 后端。不要再新增旧 `/wss` 或 `/api/admin/WebSocket/bind` 入口。
