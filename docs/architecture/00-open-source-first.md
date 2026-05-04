# Open Source First

## 结论

本项目不从零发明 admin 架构。先学习、验证、裁剪优秀开源实践，再落地自己的最小实现。

闭门造车是垃圾路线。原因很简单：

```text
开源项目已经替你踩过 RBAC、菜单、按钮权限、API 权限、前端动态路由、登录态、审计日志这些坑。
```

我们要做的是取其骨架，不是复制其全部复杂度。

## 决策顺序

任何架构决策必须按这个顺序：

```text
1. 查当前项目真实需求
2. 查优秀开源项目怎么做
3. 查国内 Go / admin 工程常见做法
4. 写明可借鉴点和不采用点
5. 裁剪成当前阶段最小方案
6. 再进入实现
```

## 研究对象分类

不要一上来找“完美项目”。按能力拆开看：

```text
Go backend skeleton
RBAC model
Menu and permission model
Frontend dynamic routes
API contract style
Middleware chain
Config and logging
Code generation and scaffolding
```

每类至少形成一页研究记录，放在：

```text
docs/open-source/
```

## 禁止事项

```text
禁止未调研就宣布“最佳架构”
禁止因为某项目 star 多就照搬
禁止把大而全平台直接塞进当前项目
禁止把前端、后端、权限、生成器一次性全做
禁止为了显得专业引入当前阶段用不上的东西
```

## 采用标准

一个开源做法只有满足这些条件才允许进入本项目：

```text
能解决当前阶段的真实问题
能被 AI 稳定理解和重复执行
能被普通开发者快速接手
能用小范围验证证明有效
不会污染未来阶段
```

## RBAC 特别规则

当前 RBAC 不是神圣的，也不默认正确。

RBAC 研究必须回答：

```text
用户、角色、权限、菜单、按钮、接口如何关联
权限编码是按 route、action、resource，还是自定义 code
菜单权限和 API 权限是否强绑定
超级管理员如何绕过权限检查
数据权限第一期是否只是预留
前端动态路由如何由后端返回
```

没回答这些问题，不准建表。
