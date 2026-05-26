# Admin App Upload Platform Permission Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the avatar-only upload implementation with a platform-aware `AppMediaUploader` that supports H5 + App only, asks App permissions before opening camera/album, and keeps upload on the existing `/api/app/v1/upload-tokens` COS runtime.

**Architecture:** `AppMediaUploader` is the only shared App-side media upload component. It wraps uview-plus `up-upload` for mobile preview/selection UI, intercepts the trigger tap to run platform permission logic first, then uploads through `uploadAppFileToCloud`; uview-plus `autoUpload` remains disabled. H5 has no native permission preflight, App has explicit camera/album permission gating, and mini-program paths are removed from advertised support.

**Tech Stack:** UniApp Vue3, TypeScript, `<script setup lang="ts">`, vue-i18n, uview-plus `up-upload`, `cos-js-sdk-v5`, Vitest, vue-tsc, Uni CLI `h5` and `app` builds.

---

## Scope Check

In scope:

```text
1. admin_app upload component naming and shared boundary.
2. App permission preflight for camera/album before file chooser opens.
3. H5/App-only platform contract; no mini-program target in scripts/docs/tests.
4. uview-plus up-upload as UI/selection wrapper, not as auto-upload runtime.
5. Profile avatar upload migrated to the shared component.
```

Out of scope:

```text
1. Changing Go backend upload token API.
2. Adding a file center, file database, or orphan asset table.
3. Multi-file business workflow beyond the single avatar use case.
4. App store packaging, certificates, or real device permission screenshots.
5. Mini-program compatibility.
```

## File Structure

Root docs:

```text
Read:   docs/superpowers/specs/2026-05-24-admin-app-upload-platform-permission-design.md
Verify: scripts/check-agent-governance.ps1
```

App docs/config:

```text
Modify: admin_app/package.json
Modify: admin_app/package-lock.json
Modify: admin_app/src/manifest.json
Modify: admin_app/docs/architecture.md
Modify: admin_app/docs/app-api-v1.md
```

App runtime:

```text
Create: admin_app/src/lib/platform/appMediaPermission.ts
Create: admin_app/src/components/AppMediaUploader/index.ts
Create: admin_app/src/components/AppMediaUploader/src/AppMediaUploader.vue
Modify: admin_app/src/pages/profile/edit.vue
Modify: admin_app/src/lib/appUploadRuntime.ts
Modify: admin_app/src/locales/zh-CN.ts
Modify: admin_app/src/locales/en-US.ts
Delete: admin_app/src/components/AppUpload/index.ts
Delete: admin_app/src/components/AppUpload/src/AppAvatarUploader.vue
```

App tests:

```text
Create: admin_app/tests/app-platform-scope.test.ts
Create: admin_app/tests/app-upload-permission.test.ts
Modify: admin_app/tests/app-upload-runtime.test.ts
Modify: admin_app/tests/app-profile-ui.test.ts
```

---

### Task 1: Lock H5/App-only platform scope before runtime changes

**Files:**
- Create: `admin_app/tests/app-platform-scope.test.ts`
- Modify: `admin_app/package.json`
- Modify: `admin_app/package-lock.json`
- Modify: `admin_app/src/manifest.json`
- Modify: `admin_app/docs/architecture.md`

- [x] **Step 1: Add failing platform-scope test**

Create `admin_app/tests/app-platform-scope.test.ts`:

```ts
import { readFileSync } from 'node:fs'
import { join } from 'node:path'

import { describe, expect, it } from 'vitest'

function readProjectFile(path: string): string {
  return readFileSync(join(process.cwd(), path), 'utf8')
}

describe('admin_app platform scope', () => {
  it('advertises only H5 and App runtime targets', () => {
    const pkg = JSON.parse(readProjectFile('package.json')) as { scripts: Record<string, string> }
    const scriptNames = Object.keys(pkg.scripts)

    expect(scriptNames).toContain('dev:h5')
    expect(scriptNames).toContain('build:h5')
    expect(scriptNames).toContain('dev:app')
    expect(scriptNames).toContain('build:app')
    expect(scriptNames.some((name) => name.includes('mp-'))).toBe(false)
    expect(scriptNames.some((name) => name.includes('quickapp'))).toBe(false)
    expect(scriptNames.some((name) => name.includes('custom'))).toBe(false)
  })

  it('does not keep mini-program or quickapp manifest sections', () => {
    const manifest = readProjectFile('src/manifest.json')

    expect(manifest).toContain('"app-plus"')
    expect(manifest).not.toContain('"mp-weixin"')
    expect(manifest).not.toContain('"mp-alipay"')
    expect(manifest).not.toContain('"mp-baidu"')
    expect(manifest).not.toContain('"mp-toutiao"')
    expect(manifest).not.toContain('"quickapp"')
  })

  it('declares App camera and album permission metadata', () => {
    const manifest = readProjectFile('src/manifest.json')

    expect(manifest).toContain('android.permission.CAMERA')
    expect(manifest).toContain('android.permission.READ_MEDIA_IMAGES')
    expect(manifest).toContain('android.permission.READ_MEDIA_VIDEO')
    expect(manifest).toContain('android.permission.READ_EXTERNAL_STORAGE')
    expect(manifest).toContain('NSCameraUsageDescription')
    expect(manifest).toContain('NSPhotoLibraryUsageDescription')
  })

  it('documents H5 plus App instead of mini-program multi-end support', () => {
    const architecture = readProjectFile('docs/architecture.md')

    expect(architecture).toContain('H5 + App')
    expect(architecture).toContain('不做小程序')
    expect(architecture).not.toContain('App/H5/小程序多端基线')
  })
})
```

- [x] **Step 2: Run the failing test**

Run:

```powershell
cd E:\admin_go\admin_app
npm run test:unit -- tests/app-platform-scope.test.ts
```

Expected now: FAIL because `package.json` still has `mp-*` / `quickapp` / `custom` scripts and `manifest.json` still has mini-program sections.

- [x] **Step 3: Update package scripts**

In `admin_app/package.json`, replace the current script block with:

```json
"scripts": {
  "dev:h5": "uni -p h5",
  "dev:app": "uni -p app",
  "build:h5": "uni build -p h5",
  "build:app": "uni build -p app",
  "type-check": "vue-tsc --noEmit",
  "test": "vitest run --config vitest.config.ts",
  "test:unit": "vitest run --config vitest.config.ts"
}
```

Do not remove `@dcloudio/uni-mp-*` dependencies in this task. Dependency pruning creates large lockfile churn and is not required to stop advertising mini-program support. If dependency pruning is needed, write a separate cleanup spec.

- [x] **Step 4: Remove mini-program manifest sections and declare App permissions**

In `admin_app/src/manifest.json`, remove:

```json
quickapp
mp-weixin
mp-alipay
mp-baidu
mp-toutiao
```

Keep `app-plus`, `uniStatistics`, and `vueVersion`. Under `app-plus.distribute.android.permissions`, ensure these declarations exist before implementing runtime permission requests:

```json
"<uses-permission android:name=\"android.permission.CAMERA\"/>",
"<uses-permission android:name=\"android.permission.READ_MEDIA_IMAGES\"/>",
"<uses-permission android:name=\"android.permission.READ_MEDIA_VIDEO\"/>",
"<uses-permission android:name=\"android.permission.READ_EXTERNAL_STORAGE\" android:maxSdkVersion=\"32\"/>"
```

Under `app-plus.distribute.ios`, add privacy descriptions so iOS has Info.plist usage strings before camera or photo library access:

```json
"privacyDescription": {
  "NSCameraUsageDescription": "需要相机权限用于拍照上传。",
  "NSPhotoLibraryUsageDescription": "需要相册权限用于选择图片上传。"
}
```

- [x] **Step 5: Update architecture wording**

In `admin_app/docs/architecture.md`, replace the UI selection paragraph with:

```markdown
采用 `uview-plus` + UniApp 原生组件作为 H5 + App 基线，不做小程序。当前实现通过 easycom 按需引入组件，并只安装本地 `$u` runtime，不使用 `uview-plus` 全量 plugin install。
```

Also replace:

```text
build:h5：先证明 H5 构建链路可跑；App 真机包作为后续发布切片。
```

with:

```text
build:h5：证明浏览器/H5 构建链路可跑。
build:app：证明 UniApp App target 可编译；真机权限流仍需要后续设备 smoke。
```

- [x] **Step 6: Re-run platform-scope test**

Run:

```powershell
cd E:\admin_go\admin_app
npm run test:unit -- tests/app-platform-scope.test.ts
```

Expected: PASS.

---

### Task 2: Add upload permission and naming contract tests

**Files:**
- Create: `admin_app/tests/app-upload-permission.test.ts`
- Modify: `admin_app/tests/app-upload-runtime.test.ts`
- Modify: `admin_app/tests/app-profile-ui.test.ts`

- [x] **Step 1: Add failing permission resolver test**

Create `admin_app/tests/app-upload-permission.test.ts`:

```ts
import { describe, expect, it } from 'vitest'

import { resolveAppMediaPermissionPlan } from '../src/lib/platform/appMediaPermission'

describe('app media upload permissions', () => {
  it('does not request native permissions on H5', () => {
    expect(resolveAppMediaPermissionPlan({
      platform: 'h5',
      os: 'web',
      source: 'camera',
      mediaKind: 'image',
    })).toEqual({
      shouldShowRationale: false,
      shouldRequestNativePermission: false,
      permissions: [],
    })
  })

  it('requests camera permission before opening App camera', () => {
    expect(resolveAppMediaPermissionPlan({
      platform: 'app',
      os: 'android',
      androidSdkInt: 34,
      source: 'camera',
      mediaKind: 'image',
    })).toEqual({
      shouldShowRationale: true,
      shouldRequestNativePermission: true,
      permissions: ['android.permission.CAMERA'],
    })
  })

  it('uses Android 13 media permission for image album access', () => {
    expect(resolveAppMediaPermissionPlan({
      platform: 'app',
      os: 'android',
      androidSdkInt: 34,
      source: 'album',
      mediaKind: 'image',
    })).toEqual({
      shouldShowRationale: true,
      shouldRequestNativePermission: true,
      permissions: ['android.permission.READ_MEDIA_IMAGES'],
    })
  })

  it('uses legacy storage permission before Android 13', () => {
    expect(resolveAppMediaPermissionPlan({
      platform: 'app',
      os: 'android',
      androidSdkInt: 32,
      source: 'album',
      mediaKind: 'image',
    })).toEqual({
      shouldShowRationale: true,
      shouldRequestNativePermission: true,
      permissions: ['android.permission.READ_EXTERNAL_STORAGE'],
    })
  })
})
```

- [x] **Step 2: Update upload runtime static contract test**

In `admin_app/tests/app-upload-runtime.test.ts`, change the second test to read the new component:

```ts
it('keeps app media upload permission-gated and wired to COS runtime', () => {
  const uploader = readProjectFile('src/components/AppMediaUploader/src/AppMediaUploader.vue')
  const runtime = readProjectFile('src/lib/appUploadRuntime.ts')
  const permission = readProjectFile('src/lib/platform/appMediaPermission.ts')

  expect(uploader).toContain('<up-upload')
  expect(uploader).toContain(':auto-upload="false"')
  expect(uploader).toContain('ensureAppMediaPermission')
  expect(uploader).toContain('uploadAppFileToCloud')
  expect(uploader).toContain("@tap.stop.prevent=\"handleChoose\"")
  expect(uploader).not.toContain('uni.chooseImage({')
  expect(uploader).not.toContain('wx.')
  expect(uploader).not.toContain('MP-WEIXIN')
  expect(permission).toContain('readAppRuntimePlatform')
  expect(permission).toContain('READ_MEDIA_IMAGES')
  expect(permission).toContain('READ_EXTERNAL_STORAGE')
  expect(permission).not.toContain("import i18n from '@/locales'")
  expect(permission).not.toContain('declare const plus')
  expect(permission).not.toContain('// #ifdef H5')
  expect(runtime).toContain("from 'cos-js-sdk-v5'")
  expect(runtime).toContain('cos.putObject')
  expect(runtime).toContain('buildPublicFileURL')
  expect(runtime).toContain('readAppLocalFileAsBlob')
  expect(runtime).toContain('validateUploadTokenRule')
  expect(runtime).not.toContain('// #ifdef APP-PLUS\n  return path')
})
```

- [x] **Step 3: Update profile UI contract test**

In `admin_app/tests/app-profile-ui.test.ts`, replace:

```ts
expect(profileEditPage).toContain('AppAvatarUploader')
```

with:

```ts
expect(profileEditPage).toContain('AppMediaUploader')
expect(profileEditPage).toContain('folder="avatars"')
expect(profileEditPage).toContain('media-kind="image"')
```

And replace:

```ts
expect(minePage).not.toContain('AppAvatarUploader')
```

with:

```ts
expect(minePage).not.toContain('AppMediaUploader')
expect(minePage).not.toContain('AppAvatarUploader')
```

And replace the locale-copy assertions:

```ts
expect(source).toContain('uploadingAvatar')
expect(source).toContain('avatarUploadSuccess')
```

with:

```ts
expect(source).toContain('mediaUpload')
expect(source).toContain('uploading')
expect(source).toContain('uploadSuccess')
```

- [x] **Step 4: Run failing tests**

Run:

```powershell
cd E:\admin_go\admin_app
npm run test:unit -- tests/app-upload-permission.test.ts tests/app-upload-runtime.test.ts tests/app-profile-ui.test.ts
```

Expected now: FAIL because the new permission helper and `AppMediaUploader` do not exist yet.

---

### Task 3: Implement the App permission helper

**Files:**
- Create: `admin_app/src/lib/platform/appMediaPermission.ts`
- Modify: `admin_app/src/locales/zh-CN.ts`
- Modify: `admin_app/src/locales/en-US.ts`

- [x] **Step 1: Create platform permission helper**

Create `admin_app/src/lib/platform/appMediaPermission.ts`:

```ts
import { i18n } from '@/i18n'

export type AppUploadRuntimePlatform = 'h5' | 'app'
export type AppUploadRuntimeOS = 'web' | 'android' | 'ios' | 'unknown'
export type AppMediaSource = 'album' | 'camera'
export type AppMediaKind = 'image' | 'video'

export interface AppMediaPermissionInput {
  platform: AppUploadRuntimePlatform
  os: AppUploadRuntimeOS
  source: AppMediaSource
  mediaKind: AppMediaKind
  androidSdkInt?: number
}

export interface AppMediaPermissionPlan {
  shouldShowRationale: boolean
  shouldRequestNativePermission: boolean
  permissions: string[]
}

interface AndroidPermissionResult {
  granted?: string[]
  deniedAlways?: string[]
  deniedPresent?: string[]
}

export function readAppRuntimePlatform(): AppUploadRuntimePlatform {
  try {
    return uni.getSystemInfoSync().uniPlatform === 'app' ? 'app' : 'h5'
  } catch {
    return 'h5'
  }
}

export function resolveAppMediaPermissionPlan(input: AppMediaPermissionInput): AppMediaPermissionPlan {
  if (input.platform === 'h5') {
    return { shouldShowRationale: false, shouldRequestNativePermission: false, permissions: [] }
  }

  if (input.os !== 'android') {
    return { shouldShowRationale: true, shouldRequestNativePermission: false, permissions: [] }
  }

  if (input.source === 'camera') {
    return { shouldShowRationale: true, shouldRequestNativePermission: true, permissions: ['android.permission.CAMERA'] }
  }

  const sdk = input.androidSdkInt || 0
  if (sdk >= 33) {
    return {
      shouldShowRationale: true,
      shouldRequestNativePermission: true,
      permissions: [input.mediaKind === 'video' ? 'android.permission.READ_MEDIA_VIDEO' : 'android.permission.READ_MEDIA_IMAGES'],
    }
  }

  return { shouldShowRationale: true, shouldRequestNativePermission: true, permissions: ['android.permission.READ_EXTERNAL_STORAGE'] }
}

export async function ensureAppMediaPermission(source: AppMediaSource, mediaKind: AppMediaKind): Promise<boolean> {
  const platform = readAppRuntimePlatform()
  if (platform !== 'app') {
    return true
  }

  const plan = resolveAppMediaPermissionPlan({
    platform,
    os: readAppRuntimeOS(),
    source,
    mediaKind,
    androidSdkInt: readAndroidSdkInt(),
  })

  if (plan.shouldRequestNativePermission && areAndroidPermissionsGranted(plan.permissions)) {
    return true
  }

  if (plan.shouldShowRationale) {
    const confirmed = await showPermissionRationale(source)
    if (!confirmed) {
      return false
    }
  }

  if (!plan.shouldRequestNativePermission || plan.permissions.length === 0) {
    return true
  }

  return requestAndroidPermissions(plan.permissions)
}

function readAppRuntimeOS(): AppUploadRuntimeOS {
  try {
    const system = uni.getSystemInfoSync()
    const name = (system.osName || system.platform || '').toLowerCase()
    if (name.includes('android')) return 'android'
    if (name.includes('ios')) return 'ios'
  } catch {
    // Fall through to plus.os below.
  }

  const runtime = getPlusRuntime()
  const plusName = runtime?.os?.name?.toLowerCase() || ''
  if (plusName.includes('android')) return 'android'
  if (plusName.includes('ios')) return 'ios'
  return 'unknown'
}

function readAndroidSdkInt(): number {
  const runtime = getPlusRuntime()
  if (!runtime?.android?.importClass) {
    return 0
  }

  try {
    const version = runtime.android.importClass('android.os.Build$VERSION') as { SDK_INT?: number } | undefined
    return Number(version?.SDK_INT || 0)
  } catch {
    return 0
  }
}

function areAndroidPermissionsGranted(permissions: string[]): boolean {
  const runtime = getPlusRuntime()
  if (!runtime?.android?.runtimeMainActivity || !runtime.android.invoke) {
    return false
  }

  try {
    const activity = runtime.android.runtimeMainActivity()
    return permissions.every((permission) => Number(runtime.android?.invoke?.(activity, 'checkSelfPermission', permission)) === 0)
  } catch {
    return false
  }
}

function requestAndroidPermissions(permissions: string[]): Promise<boolean> {
  return new Promise((resolve) => {
    const runtime = getPlusRuntime()
    if (!runtime?.android?.requestPermissions) {
      resolve(false)
      return
    }

    runtime.android.requestPermissions(
      permissions,
      (result: AndroidPermissionResult) => {
        resolve((result.deniedAlways || []).length === 0 && (result.deniedPresent || []).length === 0)
      },
      () => resolve(false),
    )
  })
}

function showPermissionRationale(source: AppMediaSource): Promise<boolean> {
  return new Promise((resolve) => {
    uni.showModal({
      title: i18n.global.t('upload.permissionTitle'),
      content: i18n.global.t(source === 'camera' ? 'upload.cameraPermissionDesc' : 'upload.albumPermissionDesc'),
      confirmText: i18n.global.t('upload.permissionConfirm'),
      cancelText: i18n.global.t('common.cancel'),
      success: (result) => resolve(Boolean(result.confirm)),
      fail: () => resolve(false),
    })
  })
}

function getPlusRuntime(): Partial<typeof plus> | null {
  if (typeof plus === 'undefined') {
    return null
  }
  return plus
}
```

Use the existing named export from `src/i18n.ts`; do not create a second i18n instance and do not redeclare the global `plus` type.

- [x] **Step 2: Add common cancel key**

In both locale files, add `cancel` under `common`:

```ts
cancel: '取消',
```

```ts
cancel: 'Cancel',
```

- [x] **Step 3: Add upload permission i18n keys**

In `admin_app/src/locales/zh-CN.ts`, add top-level `upload`:

```ts
upload: {
  permissionTitle: '需要访问权限',
  permissionConfirm: '继续',
  cameraPermissionDesc: '需要相机权限用于拍照上传。',
  albumPermissionDesc: '需要相册权限用于选择图片上传。',
  permissionDenied: '未获得权限，无法选择文件',
  chooseSource: '选择上传来源',
  chooseAlbum: '从相册选择',
  chooseCamera: '拍照上传',
  mediaUpload: '上传文件',
  mediaUploadHint: '点击选择文件，将上传到当前 COS 配置。',
  uploading: '上传中...',
  uploadSuccess: '上传成功',
  uploadFailed: '上传失败',
},
```

In `admin_app/src/locales/en-US.ts`, add:

```ts
upload: {
  permissionTitle: 'Permission required',
  permissionConfirm: 'Continue',
  cameraPermissionDesc: 'Camera access is required to take a photo for upload.',
  albumPermissionDesc: 'Photo library access is required to choose an image for upload.',
  permissionDenied: 'Permission was not granted. Unable to choose a file.',
  chooseSource: 'Choose source',
  chooseAlbum: 'Photo library',
  chooseCamera: 'Camera',
  mediaUpload: 'Upload file',
  mediaUploadHint: 'Tap to choose a file. It will upload through the current COS configuration.',
  uploading: 'Uploading...',
  uploadSuccess: 'Upload completed',
  uploadFailed: 'Upload failed',
},
```

- [x] **Step 4: Run permission tests**

Run:

```powershell
cd E:\admin_go\admin_app
npm run test:unit -- tests/app-upload-permission.test.ts
```

Expected: PASS.

---

### Task 4: Implement AppMediaUploader with uview-plus UI and project COS runtime

**Files:**
- Create: `admin_app/src/components/AppMediaUploader/index.ts`
- Create: `admin_app/src/components/AppMediaUploader/src/AppMediaUploader.vue`
- Modify: `admin_app/src/lib/appUploadRuntime.ts`

- [x] **Step 1: Create component export**

Create `admin_app/src/components/AppMediaUploader/index.ts`:

```ts
export { default as AppMediaUploader } from './src/AppMediaUploader.vue'
```

- [x] **Step 2: Create AppMediaUploader component**

Create `admin_app/src/components/AppMediaUploader/src/AppMediaUploader.vue`:

```vue
<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'

import { uploadAppFileToCloud } from '@/lib/appUploadRuntime'
import {
  ensureAppMediaPermission,
  type AppMediaKind,
  type AppMediaSource,
} from '@/lib/platform/appMediaPermission'

interface UUploadFile {
  url?: string
  thumb?: string
  name?: string
  size?: number
  type?: string
  file?: Blob
  status?: 'success' | 'uploading' | 'failed'
  message?: string
}

interface UUploadAfterReadEvent {
  file: UUploadFile | UUploadFile[]
}

interface UUploadDeleteEvent {
  index: number
}

interface UUploadInstance {
  chooseFile(params?: { capture?: AppMediaSource[] }): Promise<unknown>
}

const props = withDefaults(defineProps<{
  modelValue: string
  folder: string
  mediaKind?: AppMediaKind
  sourceTypes?: AppMediaSource[]
  title?: string
  hint?: string
  width?: number
  height?: number
  clearable?: boolean
  disabled?: boolean
}>(), {
  modelValue: '',
  mediaKind: 'image',
  sourceTypes: () => ['album', 'camera'] as AppMediaSource[],
  title: '',
  hint: '',
  width: 112,
  height: 112,
  clearable: true,
  disabled: false,
})

const emit = defineEmits<{
  (e: 'update:modelValue', value: string): void
  (e: 'uploaded', payload: { url: string; key: string }): void
  (e: 'cleared'): void
}>()

const { t } = useI18n()
const uploadRef = ref<UUploadInstance | null>(null)
const fileList = ref<UUploadFile[]>([])
const uploading = ref(false)
const pickerOpen = ref(false)

const accept = computed(() => props.mediaKind === 'video' ? 'video' : 'image')
const uploadTitle = computed(() => props.title || t('upload.mediaUpload'))
const uploadHint = computed(() => {
  if (uploading.value) return t('upload.uploading')
  return props.hint || t('upload.mediaUploadHint')
})

watch(
  () => props.modelValue,
  (value) => {
    const url = value.trim()
    fileList.value = url
      ? [{ url, thumb: url, type: props.mediaKind, status: 'success' }]
      : []
  },
  { immediate: true },
)

async function handleChoose(): Promise<void> {
  if (props.disabled || uploading.value || pickerOpen.value) return

  pickerOpen.value = true
  try {
    const source = await resolveSource()
    if (!source) return

    const allowed = await ensureAppMediaPermission(source, props.mediaKind)
    if (!allowed) {
      uni.showToast({ title: t('upload.permissionDenied'), icon: 'none' })
      return
    }

    await uploadRef.value?.chooseFile({ capture: [source] })
  } finally {
    pickerOpen.value = false
  }
}

function resolveSource(): Promise<AppMediaSource | null> {
  if (props.sourceTypes.length <= 1) {
    return Promise.resolve(props.sourceTypes[0] || 'album')
  }

  return new Promise((resolve) => {
    uni.showActionSheet({
      itemList: props.sourceTypes.map((source) => source === 'camera' ? t('upload.chooseCamera') : t('upload.chooseAlbum')),
      success: (result) => resolve(props.sourceTypes[result.tapIndex] || null),
      fail: () => resolve(null),
    })
  })
}

async function handleAfterRead(event: UUploadAfterReadEvent): Promise<void> {
  const file = Array.isArray(event.file) ? event.file[0] : event.file
  const path = file.url || file.thumb || ''
  if (!path) return

  uploading.value = true
  fileList.value = [{ ...file, status: 'uploading', message: t('upload.uploading') }]

  try {
    const uploaded = await uploadAppFileToCloud({
      path,
      name: resolveFileName(file, path),
      size: file.size,
      body: file.file,
    }, {
      folder: props.folder,
      fileKind: props.mediaKind === 'image' ? 'image' : 'file',
    })

    fileList.value = [{ ...file, url: uploaded.url, thumb: uploaded.url, status: 'success', message: '' }]
    emit('update:modelValue', uploaded.url)
    emit('uploaded', { url: uploaded.url, key: uploaded.key })
    uni.showToast({ title: t('upload.uploadSuccess'), icon: 'success' })
  } catch (error) {
    const message = resolveUploadErrorMessage(error)
    fileList.value = [{ ...file, status: 'failed', message }]
    uni.showToast({ title: message, icon: 'none' })
  } finally {
    uploading.value = false
  }
}

function handleDelete(event: UUploadDeleteEvent): void {
  fileList.value.splice(event.index, 1)
  emit('update:modelValue', '')
  emit('cleared')
}

function resolveFileName(file: UUploadFile, path: string): string {
  if (file.name?.trim()) return file.name
  const cleanPath = path.split('?')[0]
  const fromPath = cleanPath.split('/').pop()
  if (fromPath && fromPath.includes('.')) return fromPath
  return props.mediaKind === 'video' ? 'upload.mp4' : 'upload.png'
}

function resolveUploadErrorMessage(error: unknown): string {
  if (error instanceof Error && error.message && !error.message.startsWith('upload.')) {
    return error.message
  }
  return t('upload.uploadFailed')
}
</script>

<template>
  <view class="app-media-uploader">
    <up-upload
      ref="uploadRef"
      :file-list="fileList"
      :accept="accept"
      :auto-upload="false"
      :max-count="1"
      :width="width"
      :height="height"
      :deletable="clearable"
      :disabled="disabled || uploading || pickerOpen"
      @after-read="handleAfterRead"
      @delete="handleDelete"
    >
      <template #trigger>
        <view class="app-media-uploader__trigger" @tap.stop.prevent="handleChoose">
          <text class="app-media-uploader__plus">+</text>
        </view>
      </template>
    </up-upload>

    <view class="app-media-uploader__copy">
      <text class="app-media-uploader__title">{{ uploadTitle }}</text>
      <text class="app-media-uploader__hint">{{ uploadHint }}</text>
    </view>
  </view>
</template>

<style scoped>
.app-media-uploader {
  display: flex;
  align-items: center;
  gap: 22rpx;
  padding: 22rpx;
  border: 1rpx solid var(--app-line);
  border-radius: 28rpx;
  background:
    linear-gradient(135deg, rgba(37, 99, 235, 0.06), transparent 56%),
    var(--app-card-soft-bg);
  box-shadow: inset 0 0 0 1rpx rgba(255, 255, 255, 0.28);
}

.app-media-uploader__trigger {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 112rpx;
  height: 112rpx;
  border-radius: 32rpx;
  background: linear-gradient(135deg, #4f8cff 0%, #67e8c6 100%);
  box-shadow: 0 14rpx 34rpx rgba(64, 117, 255, 0.18);
}

.app-media-uploader__plus {
  color: #fff;
  font-size: 54rpx;
  font-weight: 900;
}

.app-media-uploader__copy {
  flex: 1;
  min-width: 0;
}

.app-media-uploader__title,
.app-media-uploader__hint {
  display: block;
}

.app-media-uploader__title {
  color: var(--app-text);
  font-size: 28rpx;
  font-weight: 900;
}

.app-media-uploader__hint {
  margin-top: 8rpx;
  color: var(--app-text-muted);
  font-size: 23rpx;
  line-height: 1.45;
}
</style>
```

- [x] **Step 3: Adjust app upload runtime body resolution and token-rule guard**

In `admin_app/src/lib/appUploadRuntime.ts`, export `AppUploadFileLike` and keep `body` as `Blob`; do not widen it to a path string:

```ts
export interface AppUploadFileLike {
  path: string
  name: string
  size?: number
  body?: Blob
}
```

Update `uploadAppFileToCloud` so App local paths are converted to `Blob` before requesting `/upload-tokens`, then validate the returned `token.rule` before `cos.putObject`:

```ts
export async function uploadAppFileToCloud(
  file: AppUploadFileLike,
  options: AppUploadRuntimeOptions,
): Promise<AppUploadRuntimeResult> {
  const body = file.body ?? await resolveUploadBody(file.path)
  const fileSize = resolveFileSize(file.size, body)
  if (fileSize <= 0) {
    throw new Error('upload.file_invalid')
  }

  const payload: AppUploadTokenPayload = {
    folder: options.folder,
    file_name: file.name,
    file_size: fileSize,
    file_kind: options.fileKind || 'image',
  }
  const token = await appUploadTokenClient.create(payload)

  validateUploadTokenRule(payload, token.rule)

  if (token.provider !== 'cos') {
    throw new Error('Unsupported upload provider')
  }

  const cos = new CosClientConstructor({
    getAuthorization(_options, callback) {
      callback({
        TmpSecretId: token.credentials.tmp_secret_id,
        TmpSecretKey: token.credentials.tmp_secret_key,
        SecurityToken: token.credentials.session_token,
        StartTime: token.start_time,
        ExpiredTime: token.expired_time,
      })
    },
  })

  await new Promise<void>((resolve, reject) => {
    cos.putObject(
      { Bucket: token.bucket, Region: token.region, Key: token.key, Body: body },
      (error) => {
        if (error) {
          reject(error)
          return
        }
        resolve()
      },
    )
  })

  return {
    url: buildPublicFileURL(token.bucket_domain, token.bucket, token.region, token.key),
    key: token.key,
    token,
  }
}
```

Replace `resolveUploadBody` with a Blob-only implementation:

```ts
async function resolveUploadBody(path: string): Promise<Blob> {
  if (readUploadRuntimePlatform() === 'app') {
    return readAppLocalFileAsBlob(path)
  }

  if (typeof fetch === 'function') {
    const response = await fetch(path)
    return response.blob()
  }

  throw new Error('upload.file_read_failed')
}

function readUploadRuntimePlatform(): 'h5' | 'app' {
  try {
    return uni.getSystemInfoSync().uniPlatform === 'app' ? 'app' : 'h5'
  } catch {
    return 'h5'
  }
}

function readAppLocalFileAsBlob(path: string): Promise<Blob> {
  return new Promise((resolve, reject) => {
    if (typeof plus === 'undefined' || !plus.io?.resolveLocalFileSystemURL) {
      reject(new Error('upload.file_read_failed'))
      return
    }

    plus.io.resolveLocalFileSystemURL(
      path,
      (entry) => {
        const fileEntry = entry as unknown as PlusIoFileEntry
        if (!fileEntry.isFile || typeof fileEntry.file !== 'function') {
          reject(new Error('upload.file_read_failed'))
          return
        }
        fileEntry.file(
          (file) => readPlusFileAsDataURL(file).then((dataUrl) => resolve(dataURLToBlob(dataUrl))).catch(reject),
          () => reject(new Error('upload.file_read_failed')),
        )
      },
      () => reject(new Error('upload.file_read_failed')),
    )
  })
}

function readPlusFileAsDataURL(file: PlusIoFile): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new plus.io.FileReader()
    reader.onloadend = () => {
      if (typeof reader.result === 'string' && reader.result.startsWith('data:')) {
        resolve(reader.result)
        return
      }
      reject(new Error('upload.file_read_failed'))
    }
    reader.onerror = () => reject(new Error('upload.file_read_failed'))
    reader.readAsDataURL(file)
  })
}

function dataURLToBlob(dataUrl: string): Blob {
  const [header, base64 = ''] = dataUrl.split(',')
  const contentType = /^data:([^;]+)/.exec(header)?.[1] || 'application/octet-stream'
  const binary = atob(base64)
  const bytes = new Uint8Array(binary.length)
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index)
  }
  return new Blob([bytes], { type: contentType })
}

function validateUploadTokenRule(payload: AppUploadTokenPayload, rule: AppUploadTokenResult['rule']): void {
  if (rule.max_size_mb > 0 && payload.file_size > rule.max_size_mb * 1024 * 1024) {
    throw new Error('upload.file_invalid')
  }

  const ext = payload.file_name.split('?')[0].split('.').pop()?.toLowerCase() || ''
  const allowedExts = payload.file_kind === 'image' ? rule.image_exts : rule.file_exts
  if (!ext || !allowedExts.some((item) => item.toLowerCase() === ext)) {
    throw new Error('upload.file_invalid')
  }
}
```

The important invariant is: `cos.putObject.Body` receives `Blob`, never an App local path string.

- [x] **Step 4: Run upload runtime tests**

Run:

```powershell
cd E:\admin_go\admin_app
npm run test:unit -- tests/app-upload-runtime.test.ts tests/app-upload-permission.test.ts
```

Expected: PASS.

---

### Task 5: Migrate profile avatar edit to AppMediaUploader

**Files:**
- Modify: `admin_app/src/pages/profile/edit.vue`
- Modify: `admin_app/tests/app-profile-ui.test.ts`
- Modify: `admin_app/src/locales/zh-CN.ts`
- Modify: `admin_app/src/locales/en-US.ts`
- Delete: `admin_app/src/components/AppUpload/index.ts`
- Delete: `admin_app/src/components/AppUpload/src/AppAvatarUploader.vue`

- [x] **Step 1: Update import**

In `admin_app/src/pages/profile/edit.vue`, replace:

```ts
import { AppAvatarUploader } from '@/components/AppUpload'
```

with:

```ts
import { AppMediaUploader } from '@/components/AppMediaUploader'
```

- [x] **Step 2: Update template**

Replace:

```vue
<AppAvatarUploader v-model="profileForm.avatar" />
```

with:

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

- [x] **Step 3: Delete old avatar-only shared component**

After `profile/edit.vue` imports `AppMediaUploader`, remove the old component:

```text
admin_app/src/components/AppUpload/index.ts
admin_app/src/components/AppUpload/src/AppAvatarUploader.vue
```

- [x] **Step 4: Remove old avatar-only upload status locale keys**

After deleting `AppUpload`, remove these now-dead keys from `mine` in both locale files:

```ts
uploadingAvatar
avatarUploadSuccess
avatarUploadFailed
```

Keep `mine.avatarUpload` and `mine.avatarUploadHint`; they are still passed by `profile/edit.vue` as avatar-specific title/hint.

- [x] **Step 5: Run profile UI tests**

Run:

```powershell
cd E:\admin_go\admin_app
npm run test:unit -- tests/app-profile-ui.test.ts
```

Expected: PASS.

---

### Task 6: Update App docs and API notes

**Files:**
- Modify: `admin_app/docs/architecture.md`
- Modify: `admin_app/docs/app-api-v1.md`

- [x] **Step 1: Update architecture component flow**

In `admin_app/docs/architecture.md`, replace:

```text
pages/profile/edit.vue -> appProfileClient.profile/updateProfile + AppAvatarUploader
```

with:

```text
pages/profile/edit.vue -> appProfileClient.profile/updateProfile + AppMediaUploader
AppMediaUploader -> App permission preflight on APP-PLUS, no native permission preflight on H5
AppMediaUploader -> /api/app/v1/upload-tokens + COS-only upload runtime
```

- [x] **Step 2: Add upload platform rule**

Add this section to `admin_app/docs/architecture.md` after `UI 选型`:

```markdown
## 上传平台规则

上传只支持 H5 + App，不做小程序。

`AppMediaUploader` 是 App 侧共享上传组件。它可以使用 `uview-plus` 的 `up-upload` 做移动端预览和选择 UI，但不使用 `up-upload` 的 `autoUpload`；真实上传继续走 `/api/app/v1/upload-tokens` 和项目 COS-only runtime。

H5 不做 native permission preflight，由浏览器文件选择器接管。App 打开相册或相机前必须先检查是否已授权；已授权直接打开选择器，未授权或未知状态才展示用途说明并请求对应权限。权限拒绝时不打开选择器、不请求 upload token、不改变表单值。`manifest.json` 必须声明 Android CAMERA/READ_MEDIA_IMAGES/READ_MEDIA_VIDEO/READ_EXTERNAL_STORAGE 和 iOS NSCameraUsageDescription/NSPhotoLibraryUsageDescription。
```

- [x] **Step 3: Update app API upload token note**

In `admin_app/docs/app-api-v1.md`, under `Upload token`, replace the existing rule with:

```markdown
规则：头像等 App 侧媒体上传走当前 COS-only upload token runtime。前端统一通过 `AppMediaUploader` 选择文件并上传；H5 由浏览器文件选择器接管权限，App 在打开相册/相机前必须先走权限前置。前端用 `cos-js-sdk-v5` 直传，不走 Vite 反代，不使用 uview-plus `autoUpload`。App 本地路径必须先通过 `plus.io` 读取成 Blob，获取 upload token 后、PUT COS 前再按 `token.rule` 做一次大小和后缀校验。
```

- [x] **Step 4: Re-run docs-related tests**

Run:

```powershell
cd E:\admin_go\admin_app
npm run test:unit -- tests/app-platform-scope.test.ts tests/app-upload-runtime.test.ts tests/app-profile-ui.test.ts
```

Expected: PASS.

---

### Task 7: Full verification and root governance checks

**Files:**
- Verify only.

- [x] **Step 1: Run full app unit tests**

Run:

```powershell
cd E:\admin_go\admin_app
npm run test:unit
```

Expected: all Vitest suites PASS.

- [x] **Step 2: Run app typecheck**

Run:

```powershell
cd E:\admin_go\admin_app
npm run type-check
```

Expected: PASS with no TypeScript errors.

- [x] **Step 3: Run H5 build**

Run:

```powershell
cd E:\admin_go\admin_app
npm run build:h5
```

Expected: H5 build PASS.

- [x] **Step 4: Run App build**

Run:

```powershell
cd E:\admin_go\admin_app
npm run build:app
```

Expected: App build PASS. If local CLI lacks native packaging prerequisites, record the exact failure and do not claim App upload runtime is fully verified.

- [x] **Step 5: Run root whitespace and governance gates**

Run:

```powershell
cd E:\admin_go
git diff --check
powershell -ExecutionPolicy Bypass -File .\scripts\check-agent-governance.ps1 -Mode working
```

Expected:

```text
git diff --check: no output
check-agent-governance.ps1: no blocking governance violations
```

- [ ] **Step 6: Manual smoke note for App permissions**

Record this manual smoke once a device/emulator is available:

```text
1. Install App build.
2. Login.
3. Open 我的 -> 修改资料。
4. Tap 上传头像.
5. Choose 相册: app shows permission rationale before picker; deny path does not call upload token.
6. Choose 相机: app shows permission rationale before camera; deny path does not call upload token.
7. Grant permission and upload one image; profileForm.avatar receives COS URL.
```

This manual smoke is required before updating `docs/status/current-status.md` to say App permission upload is implemented.

---

## Plan Self-Review

Coverage check:

```text
Component name issue -> Task 2/4/5 create AppMediaUploader and remove AppAvatarUploader usage.
App permission requirement -> Task 1/2/3/4 add manifest permissions, resolver, granted-check skip, and pre-choose ensureAppMediaPermission.
H5/App/no-mini platform concept -> Task 1 and Task 6.
uview-plus upload decision -> Task 4 uses up-upload with autoUpload=false and project COS runtime.
COS Body / file_size safety -> Task 4 converts App local paths to Blob, rejects unknown size, and validates token.rule before PUT.
i18n path / plus typing safety -> Task 3 imports named i18n from src/i18n.ts and reuses global @dcloudio plus type without redeclare.
Task ordering safety -> Task 5 deletes AppUpload only after profile/edit import/template migration.
Verification -> Task 7.
```

Placeholder scan:

```text
No executable TBD/TODO remains.
Every task has exact files and commands.
```

Type consistency:

```text
AppMediaUploader, ensureAppMediaPermission, resolveAppMediaPermissionPlan, AppMediaSource, AppMediaKind, AppUploadFileLike, readAppLocalFileAsBlob, and validateUploadTokenRule names are consistent across tasks.
```
