# Profile Avatar Upload Design

状态：approved-by-current-task-start，2026-05-05。

## Linus 三问

1. 真问题：上传 token 已经有了，但还没有任何真实业务上传闭环。头像是最小、最高频、最容易验证的上传场景。
2. 更简单做法：不要一口气迁所有上传场景；先迁个人资料 + 头像，复用 `UpMedia` 和 shared upload client。
3. 会破坏什么：旧个人资料页支持从用户管理跳转查看其他用户，因此新 Go 契约必须同时保留“当前用户编辑”和“指定用户只读查看”。

## 范围

In scope:

- `GET /api/admin/v1/profile`：读取当前登录用户个人资料。
- `PUT /api/admin/v1/profile`：更新当前登录用户安全字段：`username/avatar/sex/birthday/address_id/detail_address/bio`。
- `GET /api/admin/v1/users/:id/profile`：读取指定用户资料，用于用户管理跳转只读查看。
- 头像上传继续走 `POST /api/admin/v1/upload-tokens`，前端 `UpMedia` 传 `folderName='avatars'`、真实 `file.name/file.size`。
- 个人资料页前端切 Go API，移除该页面的 legacy `initPersonal/editPersonal` 调用。
- `PUT /profile` 记录显式 OperationLog，但不挂菜单按钮权限；用户编辑自己的资料只需要登录态。
- docs/contracts、current-status、smoke-matrix、backend architecture 同步。

Out of scope:

- 修改手机号、邮箱、密码验证码流程。
- 服务端转存文件。
- 头像裁剪 UI。
- OSS runtime。
- 批量迁移聊天/AI/富文本等其他上传场景。

## API Contract

### Read current profile

`GET /api/admin/v1/profile`

Auth: bearer token.

Response `data`:

```ts
interface ProfilePayload {
  profile: UserProfile
  dict: ProfileDict
}

interface UserProfile {
  user_id: number
  username: string
  email: string
  avatar: string
  phone: string
  role_id: number
  role_name: string
  address_id: number
  detail_address: string
  sex: number
  birthday: string
  bio: string
  is_self: 1 | 2
  has_password: boolean
}

interface ProfileDict {
  auth_address_tree: AddressTreeNode[]
  sexArr: Array<{ label: string; value: number }>
  verify_type_arr: Array<{ label: string; value: 'password' | 'code' }>
}
```

### Read a user profile

`GET /api/admin/v1/users/:id/profile`

Auth: bearer token.

Rules:

- `:id` must be positive.
- Response shape is identical to current profile.
- `is_self` is computed server-side from token user id, never from query/header.

### Update current profile

`PUT /api/admin/v1/profile`

Auth: bearer token.

Body:

```ts
interface UpdateProfileBody {
  username: string
  avatar?: string
  sex: number
  birthday?: string | null
  address_id: number
  detail_address?: string
  bio?: string
}
```

Rules:

- No `address` alias. New contract only accepts `address_id`.
- `username` trims spaces and must remain non-empty.
- `sex` comes from `enum.Sexes`.
- `birthday` empty string or null clears birthday; non-empty value must be `YYYY-MM-DD`.
- `address_id` can be 0 for unset.
- `email/phone/role_id/has_password/is_self` are read-only here.
- Updating profile also refreshes current user store after frontend `refresh`.

## Frontend Component Boundary

- `views/Main/personal/index.vue` owns loading, current route user id, and API calls.
- `BaseInfo` stays a focused edit form; props down, refresh event up.
- `UserInfo` remains read-only display.
- `Security` remains legacy for phone/email/password until the verification flows migrate; it is not part of this slice.

## Verification

Backend:

```powershell
go test -p=1 ./internal/module/user ./internal/bootstrap ./internal/server
go test -p=1 ./...
go vet -p=1 ./...
git diff --check
```

Frontend:

```powershell
npx vue-tsc -b --pretty false
npx eslint src/api/user/users.ts src/types/user.ts src/views/Main/personal/index.vue src/views/Main/personal/components/BaseInfo/index.vue
```
