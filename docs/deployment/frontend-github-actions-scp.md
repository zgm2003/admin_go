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
SSH_PRIVATE_KEY=部署用户的 SSH 私钥，推荐
SSH_PASSWORD=部署用户的 SSH 密码，仅作为没有私钥时的 secret fallback；不要放 variable
SSH_HOST=服务器 SSH host
SSH_PORT=服务器 SSH port，未配置时 workflow 默认 22
SSH_USER=服务器 SSH 用户
DEPLOY_PATH=宝塔站点目录，例如 /www/wwwroot/<domain>
VITE_GO_API_BASE_URL=https://<api-domain>，当前生产可省略，workflow 会回退到仓库 `.env.production`
VITE_WEB_SOCKET_URL=wss://<api-domain>/api/admin/v1/realtime/ws，当前生产可省略，workflow 会回退到仓库 `.env.production`
VITE_PLATFORM=admin，可不配；workflow 默认 admin
```

当前项目生产值按下面替换：

```text
VITE_GO_API_BASE_URL=https://www.zgm2003.cn
VITE_WEB_SOCKET_URL=wss://www.zgm2003.cn/api/admin/v1/realtime/ws
```

不要把机器 IP、`root` 用户、站点目录写死在 workflow。生产 API 域名和 WebSocket 域名优先由 GitHub Actions secrets / variables 注入；如果没有配置，workflow 会回退读取仓库里的 `.env.production` 当前线上默认值。换机器、换域名、fork 仓库或多环境部署时，优先改 Actions 配置，不改 workflow。

注意：宝塔面板端口不参与 CI。CI 只用服务器 SSH 端口；端口值以 `SSH_PORT` 为准，默认 `22`。

## Workflow

文件在 frontend runtime repo：

```text
admin_front_ts/.github/workflows/deploy-admin-front.yml
```

流程：

```text
checkout
setup node 22.12.0
npm ci
npm run build
tar dist
用 SSH_PRIVATE_KEY 或 SSH_PASSWORD secret 认证，scp 到服务器 /tmp/admin_front_ts_dist.tar.gz
清空 DEPLOY_PATH 里的旧静态文件，但保留 `.user.ini`、`.htaccess`、`.well-known`
解压 dist
chown -R www:www DEPLOY_PATH
```

workflow 会显式拒绝缺失的 `SSH_HOST`、`SSH_USER`、`DEPLOY_PATH`，并要求 `SSH_PRIVATE_KEY` 或 `SSH_PASSWORD` 至少配置一个，同时拒绝 `DEPLOY_PATH=/`，避免配置不完整时误清目录。缺配置时 workflow 输出 GitHub annotation，不再只留下一个无上下文的 exit code。

workflow 也会在构建前解析 `VITE_GO_API_BASE_URL` 和 `VITE_WEB_SOCKET_URL`：先取 GitHub secrets / variables，缺失时回退 `.env.production`，两边都没有才拒绝构建。仓库里的 `.env.production` 记录当前线上默认值，不能改回 `example.com` 占位；GitHub Actions 生产发布仍以 secrets / variables 注入值优先。

## 宝塔 Nginx 必须有 history 回退

Vue 刷新页面不 404，站点配置里要有：

```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

WebSocket 使用当前 Go Realtime contract。生产域名分工是 `<frontend-domain>` 跑静态前端、`<api-domain>` 跑 Go 后端，所以默认值必须指向后端域名：

```text
wss://<api-domain>/api/admin/v1/realtime/ws
```

如果临时改成 `wss://<frontend-domain>/api/admin/v1/realtime/ws`，才需要在前端站点额外做同域 WebSocket 反代；不要把它写进生产默认 env。

宝塔 Nginx 必须在 `<api-domain>` 站点保留 `Upgrade` / `Connection` header，并把 `/api/admin/v1/realtime/ws` 反代到 Go 后端。不要再新增旧 `/wss` 或 `/api/admin/WebSocket/bind` 入口。
