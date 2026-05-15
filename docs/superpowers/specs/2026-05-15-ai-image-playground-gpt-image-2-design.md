# AI Image Playground（gpt-image-2）Admin Integration Design

日期：2026-05-15  
状态：accepted for implementation  
范围：`admin_back_go`、`admin_front_ts`、`docs/contracts/admin-api-v1.md`

## 1. 你这次真正要表达的产品规则

1. 这不是把 `E:\cine\gpt_image_playground` 原样搬进来。
   - 这个仓库是纯前端、IndexedDB 本地存储、前端直连 provider 的玩具形态。
   - admin 里必须变成后端托管、DB 入库、账号配置归 admin 管的正式模块。

2. 第一版只做 **gpt-image-2**。
   - 不做 fal。
   - 不做自定义 provider manifest。
   - 不做多模型自由切换。
   - 只吃已经在 `ai_providers` / `ai_provider_models` 里配置好的 OpenAI-compatible provider，且模型必须是 `gpt-image-2`。

3. API Key 只能留在后端。
   - 继续沿用 `ai_providers.api_key_enc` / `api_key_hint`。
   - 前端永远拿不到明文 key。
   - 图片任务页只消费 provider 配置，不负责保存账号秘密。

4. Playground 的核心是“生成 + 历史 + 复用”。
   - 文生图 / 图生图 / 遮罩编辑。
   - 任务历史、详情、收藏、删除、重新复用。
   - 输出图片、参考图、遮罩图都要入库。

5. 本地 IndexedDB 不再是主存储。
   - 前端只负责交互、上传、展示。
   - 任务、资产、状态、历史都进数据库。

## 2. Linus 三问

### 1）这是真问题吗？

是。现在 admin 已经有：

```text
ai_providers / ai_provider_models
upload-tokens / COS 上传
operation log
WebSocket / queue / worker / 运行态
```

但没有一个正式的“图像生成工作台”。而 gpt-image-2 这种能力如果还留在纯前端本地配置里，就是把真实业务交给浏览器保存，脆得很。

### 2）有更简单的方法吗？

有：只做一个 **admin 原生的图片 playground**，直接复用现有 provider 配置和上传能力。

```text
provider 配置 = 现有 ai_providers
模型 = 只认 gpt-image-2
参考图上传 = 现有 upload-tokens + COS
任务历史 = 新表
输出图片 = 新表 + 对象存储
```

不要在这个阶段发明新的账号系统，也不要把 React 那套状态机搬进 Vue。

### 3）会破坏什么吗？

会，前提是你乱搬。

```text
如果继续前端直连 provider：会破坏密钥边界
如果继续 IndexedDB 当主库：会破坏历史一致性
如果把 fal/custom provider 一起塞进来：会破坏第一版复杂度
如果把大 base64 塞进操作日志：会破坏可维护性
```

所以第一版必须收口到 gpt-image-2 + 后端托管。

## 3. 范围锁定

### In

- 只支持 `gpt-image-2`
- OpenAI-compatible **Images API** 图像生成 / 编辑
- 参考图上传、拖拽、粘贴
- 遮罩编辑
- 任务历史
- 任务详情
- 收藏 / 删除 / 复用
- 输出图下载
- 当前用户维度的任务归属
- provider / model 继续复用现有 admin 配置

### Out

- fal
- custom provider manifest
- ZIP 导入导出
- PWA / service worker
- React 组件移植
- IndexedDB 作为主存储
- SSE / streamable
- chat / tool / RAG
- 批量运维型大屏

## 4. 架构决策

### 4.1 业务边界

新模块建议叫：

```text
backend: internal/module/aiimage
frontend: /ai/image-playground
menu code: ai_image_playground
```

它不接管 provider 配置，也不改 agent/chat/run 的既有语义。

### 4.2 运行时边界

```text
Vue -> admin_back_go REST
admin_back_go -> provider config / upload runtime / COS / OpenAI-compatible Images API
worker -> 处理图片任务
browser -> 只负责上传和展示
```

### 4.3 为什么不用 Responses API

因为这一版只做 gpt-image-2。

```text
Images API 足够直接
参数更少
编辑语义更清楚
比把图片能力硬塞到 Responses API 里更干净
```

如果未来要扩展别的 OpenAI-compatible 图片服务，再在平台层补 adapter，不改这次的业务表。

## 5. 表设计

### 5.1 `ai_image_tasks`

一条任务对应一次图片生成/编辑请求。

建议字段：

```text
id
user_id
provider_id
provider_name_snapshot
model_id
model_display_name_snapshot
prompt
size
quality
output_format
output_compression
moderation
n
status
error_message
actual_params_json
raw_response_json
is_favorite
finished_at
elapsed_ms
created_at
updated_at
is_del
```

字段用途：

| 字段 | 用途 |
| --- | --- |
| `user_id` | 当前用户归属，任务历史只看自己的。 |
| `provider_id` | 关联现有 `ai_providers.id`。 |
| `provider_name_snapshot` | 历史快照，避免 provider 改名后看不懂旧任务。 |
| `model_id` | 只允许 `gpt-image-2`。 |
| `model_display_name_snapshot` | 历史展示名。 |
| `prompt` | 任务主提示词。 |
| `size/quality/output_format/output_compression/moderation/n` | 请求参数快照。 |
| `status` | `running/success/failed/canceled/timeout`。 |
| `actual_params_json` | provider 实际生效参数。 |
| `raw_response_json` | 只在解析失败或需要排障时保留。 |
| `is_favorite` | 历史收藏。 |
| `elapsed_ms` | 前端列表/详情展示。 |

### 5.2 `ai_image_assets`

一条资产对应一个图片文件。

建议字段：

```text
id
user_id
storage_provider
storage_key
storage_url
mime_type
width
height
size_bytes
source_type
created_at
updated_at
is_del
```

字段用途：

| 字段 | 用途 |
| --- | --- |
| `storage_provider` | 当前第一版只会是 `cos`。 |
| `storage_key` | 对象存储主键。 |
| `storage_url` | 前端预览/下载使用。 |
| `source_type` | `upload/generated/mask`。 |
| `width/height/size_bytes` | 列表与详情展示。 |

### 5.3 `ai_image_task_assets`

一条任务可以挂多个输入、一个 mask、多个输出。

建议字段：

```text
id
task_id
asset_id
role
sort_order
actual_params_json
revised_prompt
created_at
updated_at
is_del
```

字段用途：

| 字段 | 用途 |
| --- | --- |
| `role` | `input/mask/output`。 |
| `sort_order` | 参考图顺序。 |
| `actual_params_json` | 输出图片实际参数快照。 |
| `revised_prompt` | provider 返回的修正提示词。 |

这套结构比把一堆数组和 base64 硬塞进任务表干净。

## 6. 运行流

### 6.1 页面初始化

`page-init` 返回：

```text
provider options
gpt-image-2 model options
status options
size / quality / format / moderation options
```

规则：

- 只显示已启用 provider
- 只显示拥有 `gpt-image-2` 模型的 provider
- 如果没有可用 provider，页面给出明确空态

### 6.2 创建任务

前端提交：

```text
prompt
provider_id
model_id = gpt-image-2
params
reference images
mask asset
```

后端做：

1. 校验当前用户权限
2. 校验 provider / model
3. 校验参考图数量、尺寸、格式
4. 写 `ai_image_tasks`
5. 写 `ai_image_assets`
6. 写 `ai_image_task_assets`
7. 入队执行

### 6.3 执行任务

worker 做：

1. 读 provider 明文 key
2. 组装 OpenAI Images API 请求
3. 上传或获取 reference / mask 资源
4. 调用 provider
5. 把输出图存对象存储
6. 写 output assets 和 task 终态

### 6.4 历史展示

前端只看数据库。

```text
task list -> task detail -> asset preview -> download / reuse / favorite
```

## 7. 前端 UX

第一版保留这些：

- prompt 编辑器
- 参考图上传 / 粘贴 / 拖拽
- 参考图排序
- 遮罩编辑
- 参数栏
- 任务网格
- 详情弹窗
- 图片预览 / 下载
- 收藏
- 重新使用配置

第一版先不做：

- batch 大批量管理
- 导入导出
- prompt gallery
- 独立 PWA

## 8. 权限和审计

### Route 权限

建议新权限码：

```text
ai_image_playground_page
ai_image_task_add
ai_image_task_favorite
ai_image_task_del
```

### OperationLog

要记：

- 创建任务
- 收藏/取消收藏
- 删除任务

不要记：

- 图片 bytes
- provider 明文 key
- 超大 raw response

## 9. 非目标

这次不碰：

```text
chat runtime
tool runtime
knowledge base
run monitor 扩展
fal / custom provider
```

不要把这次又写成“AI 全家桶”。

## 10. 验收标准

至少满足：

1. 管理员能在后台配置好 provider，并选到 `gpt-image-2`。
2. 能上传参考图并生成图片。
3. 任务刷新后仍在 DB 中。
4. 输出图可预览、下载、复用。
5. 收藏和删除能工作。
6. API Key 从不出后端。
7. 没有 React / IndexedDB 依赖混进 admin 正式运行时。
