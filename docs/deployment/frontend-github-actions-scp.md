# Frontend GitHub Actions SCP Deployment

Canonical location: `E:/admin_go/docs/deployment/frontend-github-actions-scp.md`.

This runbook was moved from `admin_front_ts/docs/deployment/github-actions-scp.md` because frontend deployment is a workspace-level deployment concern, not frontend runtime code truth.

---
# GitHub Actions 部署到宝塔

目标就一个：`master` 推送后，GitHub Actions 构建 `dist`，然后用 `root` 通过 SSH 放到宝塔站点目录。

## GitHub Secrets

仓库：

```text
https://github.com/zgm2003/admin_front_ts
```

GitHub 里只需要配一个 Secret：

```text
Settings -> Secrets and variables -> Actions -> Repository secrets
```

```text
SSH_PRIVATE_KEY=root 用户的 SSH 私钥
```

服务器信息已经写死在 workflow：

```text
SSH_HOST=118.126.104.244
SSH_PORT=22
SSH_USER=root
DEPLOY_PATH=/www/wwwroot/zgm2003.cn
```

注意：宝塔面板端口 `12315` 不参与 CI。CI 只用 SSH `22`。

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
清空 /www/wwwroot/zgm2003.cn 里的旧静态文件
解压 dist
chown -R www:www /www/wwwroot/zgm2003.cn
```

## 宝塔 Nginx 必须有 history 回退

Vue 刷新页面不 404，站点配置里要有：

```nginx
location / {
    try_files $uri $uri/ /index.html;
}
```

WebSocket 使用当前 Go Realtime contract：

```text
wss://www.zgm2003.cn/api/admin/v1/realtime/ws
```

宝塔 Nginx 必须保留 `Upgrade` / `Connection` header，并把 `/api/admin/v1/realtime/ws` 反代到 Go 后端。不要再新增旧 `/wss` 或 `/api/admin/WebSocket/bind` 入口。
