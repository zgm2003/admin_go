# Address Dict Redis Cache Design

日期：2026-05-11  
范围：`admin_back_go/internal/module/user` 地址字典读取链路  
状态：design for review

## Linus 三问

### 1. 这是个真问题，还是臆想出来的？

是真问题。

当前个人资料、用户管理初始化、用户列表展示都会读取地址字典。地址字典不是几个 enum label，而是 live DB 中 `address` 表的行政区划树。当前运行库已验证：

```text
address active rows: 3244
max(updated_at): 2026-03-09 10:56:01
```

这种数据低频变化、高频读取。每次 profile/page-init/list 都全量查 MySQL、构建树、返回大 dict，是坏味道。

### 2. 有更简单的做法吗？

有。不要重构前端，不新增复杂字典中心，不把 Redis 当真相源。

第一刀只做：

```text
MySQL address 表 = 真相源
Redis 永久 key = 派生缓存
Service cache-aside = miss 回源、重建缓存
现有 API response shape 不变
```

### 3. 会破坏已有前端、接口、登录和权限吗？

不破坏。

`auth_address_tree` 字段继续存在，前端 `el-cascader` 不动。个人资料更新仍然只提交 `address_id` 和 `detail_address`，不接受 legacy `address` alias。

## 当前证据

当前代码路径：

```text
admin_front_ts/src/views/Main/personal/index.vue
  -> UsersApi.initPersonal()

admin_front_ts/src/api/user/users.ts
  -> GET /api/admin/v1/profile
  -> GET /api/admin/v1/users/:id/profile

admin_back_go/internal/module/user/handler.go
  -> CurrentProfile / UserProfile

admin_back_go/internal/module/user/service.go
  -> Profile()
  -> repository.ActiveAddresses()
  -> buildAddressTree()

admin_back_go/internal/module/user/repository.go
  -> SELECT * FROM address WHERE is_del = 2 ORDER BY parent_id ASC, id ASC
```

现在没有 Redis 地址缓存。现有 Redis 只覆盖 token/session、验证码、RBAC button grant、系统设置缓存失效、队列、实时 Pub/Sub 等边界。

## 目标

1. 地址大字典只在 Redis miss 或显式失效后查询 MySQL。
2. Redis key 不设置 TTL，应用层视为永久缓存。
3. Redis 不可用、缓存不存在、缓存 JSON 损坏时，接口仍可从 MySQL 回源。
4. 保持现有 REST contract：

```ts
dict: {
  auth_address_tree: AddressTreeNode[]
}
```

5. 后续如果地址表有管理功能，只需要在地址 create/update/delete 成功后删除缓存 key。

## 非目标

本次不做：

```text
不改前端 personal/userManager/home 的调用方式
不新增地址管理 UI
不新增地址 CRUD API
不把 Redis 当唯一存储
不引入新的缓存框架
不新增后台 goroutine 定时刷新
不把所有 dict 都抽成“大字典中心”
```

别为了一个地址树把系统做成缓存平台。先把真问题解决掉。

## 推荐设计

### 缓存模型

新增一个很小的地址字典缓存接口，属于 `user` 模块，不放进通用 platform 层。

```go
type AddressDictCache interface {
    Get(ctx context.Context) (*AddressDictSnapshot, bool, error)
    Set(ctx context.Context, snapshot AddressDictSnapshot) error
    Delete(ctx context.Context) error
}
```

Redis 实现只负责序列化和 key 操作，不负责业务判断。

```text
Redis key: admin_go:dict:address:v1
TTL: none
```

`go-redis` 写入使用：

```go
rdb.Set(ctx, key, payload, 0)
```

`0` 表示不设置过期时间。运行时可用 Redis `TTL admin_go:dict:address:v1` 验证，期望值是 `-1`。

### Snapshot 结构

缓存不要只存 raw rows，也不要只存 tree。服务端同时需要：

```text
1. auth_address_tree：给前端 cascader
2. path_by_id：给用户列表拼 address_show
```

建议缓存派生快照：

```go
type AddressDictSnapshot struct {
    Version          int                `json:"version"`
    GeneratedAt      string             `json:"generated_at"`
    RowCount         int                `json:"row_count"`
    SourceMaxUpdated string             `json:"source_max_updated"`
    Tree             []AddressTreeNode  `json:"tree"`
    PathByID         map[int64][]string `json:"path_by_id"`
}
```

说明：

```text
version          固定为 1，结构变化时升 Redis key v2
generated_at     缓存生成时间，只做诊断
row_count        诊断用，方便 smoke 或日志观察
source_max_updated  取 address.updated_at 最大值，诊断用，不做自动一致性判断
tree             当前 API 直接返回的地址树
path_by_id       用户列表拼 address_show，避免每次从 rows 递归找父级
```

### Service 调用

新增 service 内部方法：

```text
loadAddressDict(ctx) (*AddressDictSnapshot, error)
```

流程：

```text
1. 如果 AddressDictCache 配置存在：
   1.1 Redis GET key
   1.2 hit 且 JSON 正常：直接返回 snapshot
   1.3 miss：继续查 MySQL
   1.4 JSON 损坏：best-effort DEL key，然后查 MySQL
   1.5 Redis 连接错误：查 MySQL，接口不因为缓存失败而炸

2. 查 MySQL：
   2.1 repository.ActiveAddresses(ctx)
   2.2 buildAddressTree(rows)
   2.3 buildPathByID(rows)
   2.4 cache.Set(ctx, snapshot) best-effort 写入
   2.5 返回 snapshot
```

替换现有三处地址读取：

```text
PageInit()  -> snapshot.Tree
Profile()   -> snapshot.Tree
List()      -> snapshot.PathByID 拼 address_show
```

### 错误处理原则

```text
Redis miss              正常回源 MySQL
Redis get error          回源 MySQL，不阻断用户资料读取
Redis JSON corrupt       删除坏 key，回源 MySQL
Redis set error          返回 MySQL 结果，不让接口失败
MySQL error              返回现有 “查询地址字典失败”
```

原因很简单：Redis 是性能缓存，MySQL 是真相源。缓存失败不应该把个人资料页打死；MySQL 失败才是真错误。

### 并发与雪崩

本次不引入分布式锁。

理由：

```text
address 当前只有 3244 active rows
miss 只会多查几次 MySQL，不是高危写操作
引入 Redis lock / singleflight 反而增加复杂度
```

如果以后地址数据膨胀到几十万行，或者有多实例冷启动压力，再考虑：

```text
进程内 singleflight
Redis SET NX 短锁
启动预热
```

现在不要为了假想威胁上复杂锁。

## Redis 永存的准确含义

这里的“永存”是应用层语义：

```text
Set expiration = 0
没有 TTL
不主动过期
只在显式 Delete 或 Redis 数据丢失时重建
```

它不等于 Redis 是数据库。

如果部署层配置了 `maxmemory` 且 eviction policy 允许淘汰 key，Redis 仍可能删除这个缓存。所以部署文档需要说清楚：

```text
地址字典缓存可丢，可由 MySQL 重建
如果希望尽量不被淘汰，Redis 应保留足够内存，生产环境优先 noeviction 或明确的内存策略
```

## 失效策略

当前 Go 侧没有 address CRUD，所以第一阶段只需要实现缓存 Delete 能力，不暴露新管理接口。

未来触发点：

```text
address create/update/delete/import 成功后：
  DEL admin_go:dict:address:v1
```

手动修复/导入后的 runbook：

```powershell
redis-cli DEL admin_go:dict:address:v1
```

下一次 profile/page-init/list 会自动回源 MySQL 并重建缓存。

## API 契约影响

第一阶段没有响应字段变化。

仍然返回：

```ts
interface ProfileResponse {
  profile: {
    address_id: number
    detail_address: string
  }
  dict: {
    auth_address_tree: AddressTreeNode[]
  }
}
```

用户管理 page-init 也仍然返回：

```ts
dict: {
  auth_address_tree: AddressTreeNode[]
}
```

## 后续可选优化

如果后面要继续减 payload，再做第二阶段：

```text
新增 GET /api/admin/v1/dicts/address-tree
前端全局 store/session cache 地址树
profile 不再携带 auth_address_tree
```

但这会改变前端数据加载方式，应单独立 spec，不混进本次。

## 预计改动文件

后端：

```text
admin_back_go/internal/module/user/address_dict_cache.go
admin_back_go/internal/module/user/dto.go
admin_back_go/internal/module/user/service.go
admin_back_go/internal/module/user/service_test.go
admin_back_go/internal/bootstrap/app.go
```

文档：

```text
docs/contracts/admin-api-v1.md
docs/migration/current-status.md
admin_back_go/docs/architecture.md
```

不改前端。

## 测试策略

### 单元测试

新增/调整 `internal/module/user` 测试：

```text
cache hit:
  Profile/PageInit/List 不调用 ActiveAddresses

cache miss:
  调用 ActiveAddresses，生成 snapshot，写 Redis cache

redis get error:
  回源 MySQL，接口成功

redis set error:
  接口成功，不把缓存写失败暴露给用户

corrupt JSON:
  删除坏 key，回源 MySQL

address_show:
  使用 snapshot.PathByID 拼出完整地址路径 + detail_address
```

### 验证命令

后端：

```powershell
cd E:/admin_go/admin_back_go
go test ./internal/module/user ./internal/bootstrap ./internal/server -count=1
go test -race ./internal/module/user -count=1
go vet ./internal/module/user ./internal/bootstrap ./internal/server
```

如果本机有 golangci-lint：

```powershell
golangci-lint run ./internal/module/user ./internal/bootstrap ./internal/server
```

Smoke：

```powershell
cd E:/admin_go/admin_back_go
./scripts/basic-admin-smoke.ps1
```

手工 Redis 验证：

```powershell
redis-cli EXISTS admin_go:dict:address:v1
redis-cli TTL admin_go:dict:address:v1
```

期望：

```text
EXISTS = 1
TTL = -1
```

## 验收标准

1. profile/page-init/list 首次访问可正常返回地址树。
2. 首次访问后 Redis 有 `admin_go:dict:address:v1`。
3. Redis TTL 为 `-1`。
4. 删除 Redis key 后再次访问可自动重建。
5. Redis 不可用时，只要 MySQL 可用，profile/page-init/list 不因为缓存失败而 500。
6. API response shape 不变，前端无需修改。
7. 文档明确写出地址字典缓存来源、key、TTL、失效方式。

## 风险

### 缓存陈旧

地址数据极少变更，第一阶段接受手动失效。后续有 address CRUD 时必须接入自动失效。

### Redis 误删或重启丢数据

可接受。缓存 miss 后从 MySQL 重建。

### 多实例同时 miss

可接受。当前数据量不大，重复几次全量查询比引入锁简单。

### Payload 仍然大

第一阶段解决 MySQL 重复查和重复构建派生结构，不解决每次 response 都返回大树的问题。这个留给第二阶段前端全局字典接口。

## 最终判断

先做 Redis 永久 cache-aside。  
不要改前端。  
不要做通用字典平台。  
不要让 Redis 变成真相源。  

这是当前最小、稳、可回滚、不会破坏用户空间的方案。
