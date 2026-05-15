# AI Image Playground（Agent-Driven, gpt-image-2）Admin Design

日期：2026-05-15  
状态：implemented（automated verification passed；manual provider/worker smoke pending）  
范围：`admin_back_go`、`admin_front_ts`、`docs/contracts/admin-api-v1.md`、`docs/status/current-status.md`

## 1. 这次真正要做什么

1. 不再单独造一套 provider / playground 体系。
   - 现有 `ai_providers` / `ai_provider_models` 继续做账号和模型事实源。
   - 现有 `ai_agents` 继续做智能体事实源。
   - 图片工作台只复用一个已启用的智能体，不直接让前端选 provider 或 model。

2. 新增一个专用智能体场景：`image_generate`。
   - `ai_agents.scenes_json` 继续是场景数组。
   - 第一版图片工作台只消费 `scene=image_generate` 的智能体。
   - 这个智能体的模型仍然必须由现有模型配置选出，第一版只接受 `gpt-image-2`。

3. 图片工作台是 admin 原生的图片任务面。
   - 前端负责交互、上传、预览、历史操作。
   - 后端负责任务入库、资产入库、provider 调用、结果归档。
   - 历史数据必须进数据库，不再把 IndexedDB 当主存储。

4. 这不是 AI 全家桶扩张。
   - 不碰 chat / tool / knowledge / run monitor 的语义。
   - 不碰 fal / custom provider / 多 provider 工作台。
   - 不把图片能力塞进现有 chat 页面。

## 2. Linus 三问

### 1）这是真问题吗？

是。`gpt_image_playground` 已经证明图片工作流本身成立，但它把核心状态和历史放在浏览器里，密钥和历史边界都太脆。

### 2）更简单的方法是什么？

复用现有智能体配置，新增一个 `image_generate` 场景，然后单独做一个图片工作台。

- agent 负责 provider / model 绑定
- task 负责历史
- asset 负责图片文件
- playground 只管操作

### 3）会破坏什么吗？

会，前提是你乱改。

- 如果再造 provider/playground 配置，会和现有 `ai_providers` 重叠
- 如果让浏览器直接持有 API key，会破坏密钥边界
- 如果把图片历史塞回 IndexedDB，会破坏 admin 侧一致性

## 3. 范围锁定

### In

- `ai_agents` 新增 `image_generate` 场景
- 图片工作台按 `agent_id` 运行
- 任务、资产、历史、收藏、删除、复用、下载
- 参考图上传
- 遮罩编辑
- 输出图持久化
- 只支持 `gpt-image-2`

### Out

- 新 provider 管理面
- fal / custom provider
- 多模型自由切换
- chat / tool / knowledge 语义改造
- SSE / streamable
- IndexedDB 主存储
- PWA / 导入导出

## 4. 架构决策

### 4.1 配置边界

现有智能体仍然是唯一入口：

```text
ai_providers -> ai_provider_models -> ai_agents
```

图片工作台只挑一个启用的 image scene 智能体，不自己再收集 provider 配置。

`GET /api/admin/v1/ai-agents/options` 需要支持 scene 过滤，图片工作台用 `scene=image_generate`。

### 4.2 运行边界

```text
Vue -> admin_back_go REST
admin_back_go -> ai agent config -> OpenAI-compatible Images API
admin_back_go -> COS / upload runtime
admin_back_go -> DB task/asset tables
browser -> 只负责上传、编辑、预览
cmd/admin-api -> Redis-backed Asynq -> cmd/admin-worker
```

图片生成是慢任务，不能把 provider 调用压在 HTTP 请求里。HTTP 只创建 `pending`
任务并投递 `ai:image-generate:v1`；真正调用 Images API、保存输出、更新终态由
`cmd/admin-worker` 消费 Asynq 完成。

### 4.3 为什么用 `image_generate`

`agent_generate` 现在已经有工具草稿语义，不能拿来再混图片工作流。新场景单独叫 `image_generate`，边界最清楚，也最不容易把后续功能搅成一锅粥。

### 4.4 任务主键是什么

任务入口必须是 `agent_id`，不是 `provider_id`。

原因很简单：

- 智能体已经绑定 provider / model
- 历史任务要保留快照
- playground 只应关心“用哪个图片智能体”，不该让前端手动拼 provider 和 model

## 5. 数据模型

### 5.1 `ai_agents` 扩展

`scenes_json` 增加 `image_generate`。  
现有 `chat` / `agent_generate` 保持不变。

### 5.2 `ai_image_tasks`

一条记录是一轮图片生成或编辑请求。

建议字段：

```text
id
user_id
agent_id
agent_name_snapshot
provider_id_snapshot
provider_name_snapshot
model_id_snapshot
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

作用：

- 保存当前用户历史
- 保存 agent / provider / model 快照
- 保存请求参数和终态
- 保存失败信息，但不保存密钥

### 5.3 `ai_image_assets`

一条记录是一张图，不管它是上传图、遮罩图还是生成图。

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

作用：

- 图片文件入库
- 任务输出图可复用
- 参考图和遮罩图也用同一张资产表

### 5.4 `ai_image_task_assets`

一条记录表示任务和资产的关系。

建议字段：

```text
id
task_id
asset_id
role
sort_order
related_asset_id
actual_params_json
revised_prompt
created_at
updated_at
is_del
```

作用：

- `role=input/mask/output`
- `sort_order` 保持参考图顺序
- `related_asset_id` 让 mask 能指向被编辑的输入图
- `revised_prompt` 保存 provider 返回的改写提示词

## 6. 运行流

### 6.1 智能体配置

管理员先在 `ai_agents` 里建一个图片智能体：

- provider 选现有 OpenAI-compatible 账号
- model 选 `gpt-image-2`
- scenes 勾选 `image_generate`

### 6.2 页面初始化

图片工作台打开时：

1. 取 `scene=image_generate` 的启用智能体选项
2. 取图片任务参数字典
3. 初始化当前用户历史列表

### 6.3 资产注册

前端先把参考图 / 遮罩图上传到现有上传体系，再调用图片资产入库接口注册成 `ai_image_assets`。

这样任务复用时只需要引用资产 ID，不需要重传原图。

### 6.4 创建任务

前端提交：

```text
agent_id
prompt
size / quality / output_format / output_compression / moderation / n
input_asset_ids[]
mask_asset_id
mask_target_asset_id
```

后端做：

1. 校验当前用户
2. 校验 agent 存在、启用、且包含 `image_generate`
3. 校验 agent 绑定的 provider / model 存在且启用
4. 校验 model_id = `gpt-image-2`
5. 校验资产归属和数量
6. 创建 task 记录
7. 投递 Redis-backed Asynq 任务 `ai:image-generate:v1`
8. 立即返回 task id 和 `pending` 状态

worker 做：

1. 幂等 claim `pending` task 为 `running`
2. 重新加载 agent / provider / model / assets 运行时事实
3. 调用 OpenAI-compatible Images API
4. 保存输出图资产
5. 写 task / task_assets 终态

### 6.5 历史和复用

列表、详情、收藏、删除、复用都只读数据库。前端通过轮询列表/详情看到
`pending -> running -> success/failed`，不走 SSE，不走 WebSocket。

复用不需要新 provider 配置，只是把旧 task 的参数和资产重新塞回 composer 再生成一次。

## 7. 前端 UX

第一版保留这些：

- agent 选择器
- prompt 编辑器
- 参考图上传 / 排序
- 遮罩编辑
- 参数栏
- 任务网格
- 详情弹窗
- 图片预览 / 下载
- 收藏
- 重新使用配置

第一版不要这些：

- provider 选择器
- model 选择器
- 导入导出
- prompt gallery
- 独立 PWA

## 8. 权限和审计

### Route 权限

建议新权限码：

```text
ai_image_playground_page
ai_image_asset_add
ai_image_task_add
ai_image_task_favorite
ai_image_task_del
```

### OperationLog

要记：

- 创建任务
- 注册资产
- 收藏 / 取消收藏
- 删除任务

不要记：

- 图片 bytes
- prompt 全文
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

1. 管理员能创建一个 `image_generate` 智能体。
2. 图片工作台只认 `scene=image_generate` 的 agent。
3. 能上传参考图并生成图片。
4. 任务刷新后仍在 DB 中。
5. 输出图可预览、下载、复用。
6. 收藏和删除能工作。
7. API Key 从不出后端。
8. 没有 React / IndexedDB 依赖混进 admin 正式运行时。
