# Admin App Upload Platform Permission Design

状态：review-ready spec for implementation
日期：2026-05-24
责任 agent：`frontend-adapter`
范围：`admin_app` 上传组件命名、H5/App 平台边界、App 权限前置、uview-plus 上传组件取舍

## 1. 一句话结论

`admin_app` 的上传不能直接搬 `admin_front_ts/src/components/UpMedia`，也不能继续把“头像上传”当成唯一上传组件。

本切片固定为：

```text
H5 + App only，明确不做小程序。
App 上传必须在打开相册/相机前走平台权限前置。
App 端新增共享组件 AppMediaUploader。
uview-plus 的 up-upload 只做选择/预览/删除 UI，上传仍走现有 /api/app/v1/upload-tokens + COS runtime。
不使用 uview-plus autoUpload。
```

## 2. Linus 三问

### 2.1 这是真问题吗？

是。

当前运行时事实：

```text
admin_app/src/components/AppUpload/src/AppAvatarUploader.vue
```

直接调用 `uni.chooseImage`，没有 App 权限前置，也只表达“头像”。这会把后续商品图、聊天图、资料附件等上传继续拖进头像组件或复制组件。

同时 `admin_app/docs/architecture.md` 还写着 `App/H5/小程序多端基线`，但当前产品口径是 H5 + App，不做小程序。

### 2.2 有更简单的做法吗？

有。不要重做一套文件中心，也不要把后台管理端 `UpMedia` 直接复制到 App。

最小正确做法：

```text
1. 新建 AppMediaUploader 作为 admin_app 共享上传入口。
2. 头像编辑页只是它的一个使用场景：folder=avatars，mediaKind=image。
3. H5 和 App 的权限/选择逻辑在组件内部显式分支。
4. 后端契约不变，继续走 App scope 的 /api/app/v1/upload-tokens。
```

### 2.3 会破坏已有前端、接口、登录和权限吗？

不应该。

本 spec 不改后端接口，不改登录态，不引入 admin 菜单/RBAC，不改 `/api/app/v1/upload-tokens` 请求/响应结构。

会改动的是：

```text
admin_app 上传组件命名与边界
admin_app H5/App 平台声明
admin_app App 权限前置
admin_app upload tests/docs
```

## 3. 当前项目事实

### 3.1 admin_front_ts 的 UpMedia 是 PC 管理端组件

路径：

```text
admin_front_ts/src/components/UpMedia/src/index.vue
```

它依赖：

```text
Element Plus el-upload / el-image / el-popover
admin_front_ts/src/lib/upload
/api/admin/v1 upload token client
browser File
```

所以它只能作为“已有上传命名和 COS token/runtime 分层”的参考，不能直接复用到 UniApp App。

### 3.2 admin_app 当前上传是头像专用组件

路径：

```text
admin_app/src/components/AppUpload/src/AppAvatarUploader.vue
```

当前行为：

```text
1. 点击组件后直接 uni.chooseImage。
2. sourceType 同时给 album + camera。
3. 成功后调用 uploadAppFileToCloud。
4. 上传成功 emit update:modelValue / uploaded。
```

问题：

```text
1. 组件名和边界是 avatar，不是共享 media upload。
2. App 打开相册/相机前没有权限前置。
3. H5/App/小程序边界没有收紧。
4. 后续上传场景会复制头像组件。
```

### 3.3 当前 App API 上传契约是正确方向

路径：

```text
admin_app/docs/app-api-v1.md
admin_app/src/api/appUpload.ts
admin_app/src/lib/appUploadRuntime.ts
```

已有契约：

```text
POST /api/app/v1/upload-tokens
Authorization: Bearer <token>
platform: app
provider: cos
```

这个契约继续保留。上传组件只负责选择文件、权限前置、调用现有 App upload runtime、回填 URL。

### 3.4 uview-plus 已经在 admin_app 中安装

当前依赖：

```text
uview-plus@^3.8.37
pages.json easycom: ^u-(.*) / ^up-(.*)
```

本地 `node_modules/uview-plus/components/u-upload` 显示：

```text
1. u-upload 支持 accept=image/video/file/media 等。
2. file/media/all 带小程序/H5 兼容提示。
3. autoUpload 默认 false。
4. autoUploadDriver 有 local/oss/cos/kodo 字段，但当前 cos 分支没有项目需要的 STS + COS putObject 逻辑。
5. beforeRead 发生在 chooseFile 成功之后，不适合做“打开相机/相册前”的 App 权限前置。
```

所以结论不是“完全不用 uview-plus”，而是：

```text
用 up-upload 做移动端预览/删除/选择 UI。
不用 up-upload autoUpload。
不要把权限检查放在 beforeRead。
用 trigger slot + @tap.stop 自己先问权限，再调用 up-upload 实例 chooseFile。
```

## 4. 平台定义

### 4.1 只支持两类前端 runtime

```text
H5       = 浏览器/移动浏览器页面
APP-PLUS = 打包后的 App runtime
```

明确不支持：

```text
MP-WEIXIN
MP-ALIPAY
MP-BAIDU
MP-TOUTIAO
MP-QQ
quickapp
```

`admin_app` 可以继续使用 UniApp，但不再把小程序当成产品目标。

### 4.2 H5 上传策略

H5 不做 native permission preflight。

原因：

```text
浏览器文件选择器、相机 capture 和权限提示由浏览器/系统管理。
前端只能触发用户手势下的文件选择，不能像 App 一样预申请系统权限。
```

H5 仍然要做：

```text
1. 只在用户点击后打开选择器。
2. 获取 upload token 后、真正 PUT COS 前按 token.rule 再校验大小和后缀；后端 /upload-tokens 仍是真校验。
3. 上传走 COS-only App runtime，Body 必须是 Blob/File，不能把 App 本地路径字符串直接交给 cos-js-sdk-v5。
```

### 4.3 App 上传策略

App 必须在打开选择器前先走权限前置。

最小权限矩阵：

| 用户动作 | Android 权限 | iOS 行为 | 说明 |
| --- | --- | --- | --- |
| 拍照 | `android.permission.CAMERA` | 先展示用途说明，再由系统相机权限弹窗接管 | 打开 camera 前必须问 |
| 相册图片 | Android 13+ `READ_MEDIA_IMAGES`，旧版 `READ_EXTERNAL_STORAGE` | 先展示用途说明，再由系统相册权限弹窗接管 | 选 album 前必须问 |
| 视频 | Android 13+ `READ_MEDIA_VIDEO`，旧版 `READ_EXTERNAL_STORAGE` | 同上 | 本切片只为后续预留，不默认接入业务页 |

打包清单必须同步：

```text
Android manifest: CAMERA, READ_MEDIA_IMAGES, READ_MEDIA_VIDEO, READ_EXTERNAL_STORAGE。
iOS manifest privacyDescription: NSCameraUsageDescription, NSPhotoLibraryUsageDescription。
```

权限被拒绝：

```text
1. 不打开选择器。
2. showToast 显示 i18n 文案。
3. 不调用 /upload-tokens。
4. 不改变 modelValue。
```

已授权场景不重复弹用途说明，直接打开选择器；未授权或未知状态才展示用途说明并请求权限。

## 5. 命名决策

### 5.1 不采用 UpMedia 作为 admin_app 组件名

`UpMedia` 在 `admin_front_ts` 中已经是 PC admin 组件名。它依赖 Element Plus，并且没有 App 权限语义。

在 `admin_app` 继续叫 `UpMedia` 有两个坏处：

```text
1. 容易让人误以为 PC 和 App 组件可以互换。
2. `up-*` 已经是 uview-plus easycom 组件前缀，`UpMedia` 容易和 uview-plus 组件命名混淆。
```

### 5.2 采用 AppMediaUploader

共享组件名：

```text
AppMediaUploader
```

路径：

```text
admin_app/src/components/AppMediaUploader/index.ts
admin_app/src/components/AppMediaUploader/src/AppMediaUploader.vue
```

职责：

```text
1. 显示上传入口、预览、删除、上传状态。
2. 根据 H5/App 平台执行选择前处理。
3. App 平台选择前先问权限。
4. 使用 uploadAppFileToCloud 上传。
5. 通过 v-model 回填 URL。
```

业务页用法：

```vue
<AppMediaUploader
  v-model="profileForm.avatar"
  folder="avatars"
  media-kind="image"
  :source-types="['album', 'camera']"
  :title="t('mine.avatarUpload')"
  :hint="t('mine.avatarUploadHint')"
/>
```

## 6. 组件边界

### 6.1 AppMediaUploader props

```ts
interface AppMediaUploaderProps {
  modelValue: string
  folder: string
  mediaKind?: 'image' | 'video'
  sourceTypes?: Array<'album' | 'camera'>
  title?: string
  hint?: string
  width?: number
  height?: number
  clearable?: boolean
  disabled?: boolean
}
```

第一版默认单文件上传。多图、多附件列表以后由真实业务场景再扩展，不在头像切片里预造。

### 6.2 emits

```ts
interface AppMediaUploaderEmits {
  'update:modelValue': [value: string]
  uploaded: [payload: { url: string; key: string }]
  cleared: []
}
```

### 6.3 依赖方向

```text
pages/profile/edit.vue
  -> AppMediaUploader
  -> ensureAppMediaPermission
  -> uploadAppFileToCloud
  -> appUploadTokenClient
  -> /api/app/v1/upload-tokens
```

页面不能直接调用 `uni.chooseImage`、`uni.uploadFile`、`appUploadTokenClient.create`。

## 7. uview-plus 取舍

### 7.1 备选方案

#### 方案 A：直接复制 admin_front_ts UpMedia

拒绝。

原因：

```text
Element Plus / el-upload 不能作为 UniApp App 组件。
admin_front_ts upload client 走后台管理端抽象，不是 App scope。
没有 App 权限前置。
```

#### 方案 B：完全手写 UniApp 上传 UI

可行但不推荐作为第一版。

优点：

```text
权限前置和选择器完全可控。
```

缺点：

```text
会重复写预览、删除、状态、尺寸、移动端触控样式。
项目已经引入 uview-plus，没必要第一版绕开现成移动端组件。
```

#### 方案 C：使用 up-upload 做 UI，项目自己控制权限和 COS 上传

推荐。

优点：

```text
移动端 UI 与当前 uview-plus 栈一致。
不使用 uview-plus autoUpload，避免和项目 COS-only STS runtime 冲突。
权限前置由 AppMediaUploader 自己控制。
```

限制：

```text
必须用 trigger slot 拦截点击，先问权限，再调用 up-upload 实例 chooseFile。
不能把权限逻辑放到 beforeRead，因为 beforeRead 已经晚于 chooseFile。
```

## 8. 测试与验收

### 8.1 静态契约测试

新增或更新测试，必须锁住：

```text
1. profile/edit 使用 AppMediaUploader，不再直接使用 AppAvatarUploader。
2. AppMediaUploader 使用 up-upload，但 autoUpload=false。
3. AppMediaUploader 选择前调用 ensureAppMediaPermission。
4. AppMediaUploader 不直接包含 wx.* / MP-WEIXIN / chooseMessageFile。
5. package scripts/docs 不再宣称支持小程序/quickapp。
6. manifest 声明 App 相册/相机所需 Android 权限和 iOS privacyDescription。
7. appUploadRuntime 不把 App 本地路径字符串作为 cos.putObject Body。
```

### 8.2 单元测试

测试纯函数：

```text
resolveAppMediaPermissionPlan({
  platform: 'h5',
  source: 'camera',
  mediaKind: 'image',
}) -> no native permissions

resolveAppMediaPermissionPlan({
  platform: 'app',
  source: 'camera',
  mediaKind: 'image',
  os: 'android',
  androidSdkInt: 34,
}) -> CAMERA

resolveAppMediaPermissionPlan({
  platform: 'app',
  source: 'album',
  mediaKind: 'image',
  os: 'android',
  androidSdkInt: 34,
}) -> READ_MEDIA_IMAGES

resolveAppMediaPermissionPlan({
  platform: 'app',
  source: 'album',
  mediaKind: 'image',
  os: 'android',
  androidSdkInt: 32,
}) -> READ_EXTERNAL_STORAGE
```

### 8.3 验证命令

实现完成后至少运行：

```powershell
cd E:\admin_go\admin_app
npm run test:unit
npm run type-check
npm run build:h5
npm run build:app

cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

如果 `build:app` 受本机 HBuilderX/App 打包环境限制失败，必须记录失败原因，不能把 H5 构建当成 App 真机证明。

## 9. 文档同步

实现完成且验证通过后更新：

```text
admin_app/docs/architecture.md
admin_app/docs/app-api-v1.md
docs/status/current-status.md
```

注意：本 spec 和 plan 只是 planned，不允许把它写进 current-status 的 implemented。

## 10. Spec self-review

检查结果：

```text
无 TBD/TODO。
Scope 聚焦在 admin_app 上传组件、平台边界和权限前置。
不改后端 API，不扩大到全量文件中心。
H5/App/小程序边界明确。
uview-plus 只作为 UI/选择组件，不接管 COS 上传。
App manifest 权限、iOS privacyDescription、App 本地路径转 Blob、token.rule 二次校验已经纳入约束。
```
