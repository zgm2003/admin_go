/*
 Navicat Premium Dump SQL

 Source Server         : localhost
 Source Server Type    : MySQL
 Source Server Version : 80408 (8.4.8)
 Source Host           : localhost:3306
 Source Schema         : admin

 Target Server Type    : MySQL
 Target Server Version : 80408 (8.4.8)
 File Encoding         : 65001

 Date: 19/05/2026 22:33:30
*/

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------
-- Table structure for address
-- ----------------------------
DROP TABLE IF EXISTS `address`;
CREATE TABLE `address`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Region id',
  `parent_id` int UNSIGNED NOT NULL DEFAULT 0 COMMENT 'parent region id; 0 means root',
  `code` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '区划编码',
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '区划名称',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT 'soft delete: 1 deleted 2 normal',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uniq_address_code`(`code` ASC) USING BTREE,
  INDEX `idx_address_parent`(`parent_id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 43132 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '区域表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_agent_knowledge_bases
-- ----------------------------
DROP TABLE IF EXISTS `ai_agent_knowledge_bases`;
CREATE TABLE `ai_agent_knowledge_bases`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '绑定ID',
  `agent_id` bigint UNSIGNED NOT NULL COMMENT 'ai_agents.id',
  `knowledge_base_id` bigint UNSIGNED NOT NULL COMMENT 'ai_knowledge_bases.id',
  `top_k` int UNSIGNED NOT NULL DEFAULT 5 COMMENT '本智能体对此知识库召回条数',
  `min_score` decimal(8, 4) NOT NULL DEFAULT 0.1000 COMMENT '本智能体对此知识库最低命中分',
  `max_context_chars` int UNSIGNED NOT NULL DEFAULT 6000 COMMENT '本智能体对此知识库最大注入字符数',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1启用 2禁用；运行时只加载启用绑定',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '1删除 2正常',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_ai_agent_knowledge_base`(`agent_id` ASC, `knowledge_base_id` ASC, `is_del` ASC) USING BTREE,
  INDEX `idx_ai_agent_knowledge_agent`(`agent_id` ASC, `status` ASC, `is_del` ASC) USING BTREE,
  INDEX `idx_ai_agent_knowledge_base`(`knowledge_base_id` ASC, `status` ASC, `is_del` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 2 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI智能体知识库绑定' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_agent_tools
-- ----------------------------
DROP TABLE IF EXISTS `ai_agent_tools`;
CREATE TABLE `ai_agent_tools`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '绑定ID',
  `agent_id` bigint UNSIGNED NOT NULL COMMENT 'ai_agents.id',
  `tool_id` bigint UNSIGNED NOT NULL COMMENT 'ai_tools.id',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1启用 2禁用；运行时只加载启用绑定',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_ai_agent_tools_agent_tool`(`agent_id` ASC, `tool_id` ASC) USING BTREE,
  INDEX `idx_ai_agent_tools_agent_status`(`agent_id` ASC, `status` ASC, `id` ASC) USING BTREE,
  INDEX `idx_ai_agent_tools_tool_status`(`tool_id` ASC, `status` ASC, `id` ASC) USING BTREE,
  CONSTRAINT `fk_ai_agent_tools_agent` FOREIGN KEY (`agent_id`) REFERENCES `ai_agents` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `fk_ai_agent_tools_tool` FOREIGN KEY (`tool_id`) REFERENCES `ai_tools` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `chk_ai_agent_tools_status` CHECK (`status` in (1,2))
) ENGINE = InnoDB AUTO_INCREMENT = 5 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI智能体工具绑定' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_agents
-- ----------------------------
DROP TABLE IF EXISTS `ai_agents`;
CREATE TABLE `ai_agents`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `provider_id` bigint UNSIGNED NOT NULL,
  `name` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `model_id` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `model_display_name` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `scenes_json` json NULL,
  `system_prompt` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `avatar` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1,
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_ai_agents_provider`(`provider_id` ASC, `status` ASC, `is_del` ASC) USING BTREE,
  INDEX `idx_ai_agents_model`(`provider_id` ASC, `model_id` ASC, `status` ASC, `is_del` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 7 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI agent mappings' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_conversations
-- ----------------------------
DROP TABLE IF EXISTS `ai_conversations`;
CREATE TABLE `ai_conversations`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '会话ID',
  `user_id` int UNSIGNED NOT NULL COMMENT '当前用户ID',
  `agent_id` int UNSIGNED NOT NULL COMMENT 'ai_agents.id',
  `title` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '会话标题',
  `last_message_at` datetime NULL DEFAULT NULL COMMENT '上次对话时间',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '1删除 2正常',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_ai_conversations_user_agent_del_last_message`(`user_id` ASC, `agent_id` ASC, `is_del` ASC, `last_message_at` ASC, `id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 5 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI会话' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_image_assets
-- ----------------------------
DROP TABLE IF EXISTS `ai_image_assets`;
CREATE TABLE `ai_image_assets`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '图片资产ID',
  `user_id` bigint UNSIGNED NOT NULL COMMENT '归属用户ID',
  `storage_provider` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT 'cos/remote_url',
  `storage_key` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '对象存储key',
  `storage_url` varchar(1000) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '可访问URL',
  `mime_type` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT 'MIME类型',
  `width` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '图片宽度',
  `height` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '图片高度',
  `size_bytes` bigint UNSIGNED NOT NULL DEFAULT 0 COMMENT '文件字节数',
  `source_type` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT 'upload/mask/generated',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '1删除2正常',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_ai_image_assets_user_created`(`user_id` ASC, `is_del` ASC, `created_at` ASC, `id` ASC) USING BTREE,
  INDEX `idx_ai_image_assets_storage`(`storage_provider` ASC, `storage_key` ASC) USING BTREE,
  CONSTRAINT `chk_ai_image_assets_del` CHECK (`is_del` in (1,2)),
  CONSTRAINT `chk_ai_image_assets_source` CHECK (`source_type` in (_utf8mb4'upload',_utf8mb4'mask',_utf8mb4'generated'))
) ENGINE = InnoDB AUTO_INCREMENT = 2 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI图片资产' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_image_task_assets
-- ----------------------------
DROP TABLE IF EXISTS `ai_image_task_assets`;
CREATE TABLE `ai_image_task_assets`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '任务资产关系ID',
  `task_id` bigint UNSIGNED NOT NULL COMMENT 'ai_image_tasks.id',
  `asset_id` bigint UNSIGNED NOT NULL COMMENT 'ai_image_assets.id',
  `role` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT 'input/mask/output',
  `sort_order` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '排序',
  `related_asset_id` bigint UNSIGNED NULL DEFAULT NULL COMMENT 'mask 对应的被编辑资产',
  `actual_params_json` json NULL COMMENT '单图实际参数摘要',
  `revised_prompt` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL COMMENT 'provider 返回的修订提示词',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '1删除2正常',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_ai_image_task_assets_task_role`(`task_id` ASC, `role` ASC, `sort_order` ASC, `id` ASC) USING BTREE,
  INDEX `idx_ai_image_task_assets_asset`(`asset_id` ASC, `is_del` ASC) USING BTREE,
  INDEX `idx_ai_image_task_assets_related`(`related_asset_id` ASC) USING BTREE,
  CONSTRAINT `fk_ai_image_task_assets_asset` FOREIGN KEY (`asset_id`) REFERENCES `ai_image_assets` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `fk_ai_image_task_assets_task` FOREIGN KEY (`task_id`) REFERENCES `ai_image_tasks` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `chk_ai_image_task_assets_del` CHECK (`is_del` in (1,2)),
  CONSTRAINT `chk_ai_image_task_assets_role` CHECK (`role` in (_utf8mb4'input',_utf8mb4'mask',_utf8mb4'output'))
) ENGINE = InnoDB AUTO_INCREMENT = 2 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI图片任务资产关系' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_image_tasks
-- ----------------------------
DROP TABLE IF EXISTS `ai_image_tasks`;
CREATE TABLE `ai_image_tasks`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '图片任务ID',
  `user_id` bigint UNSIGNED NOT NULL COMMENT '发起用户ID',
  `agent_id` bigint UNSIGNED NOT NULL COMMENT 'ai_agents.id',
  `agent_name_snapshot` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '任务创建时智能体名称',
  `provider_id_snapshot` bigint UNSIGNED NOT NULL COMMENT '任务创建时供应商ID',
  `provider_name_snapshot` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '任务创建时供应商名称',
  `model_id_snapshot` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '任务创建时模型ID',
  `model_display_name_snapshot` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '任务创建时模型展示名',
  `prompt` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '图片提示词',
  `size` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '图片尺寸',
  `quality` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '质量参数',
  `output_format` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '输出格式',
  `output_compression` int UNSIGNED NULL DEFAULT NULL COMMENT '输出压缩率，仅部分格式有效',
  `moderation` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '安全审核参数',
  `n` int UNSIGNED NOT NULL DEFAULT 1 COMMENT '输出张数',
  `status` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT 'pending/running/success/failed',
  `error_message` varchar(1000) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '失败原因',
  `actual_params_json` json NULL COMMENT 'provider 实际参数摘要',
  `raw_response_json` json NULL COMMENT 'provider 原始响应摘要，不保存图片bytes',
  `is_favorite` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '1是2否',
  `finished_at` datetime NULL DEFAULT NULL COMMENT '完成时间',
  `elapsed_ms` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '耗时毫秒',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '1删除2正常',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_ai_image_tasks_user_created`(`user_id` ASC, `is_del` ASC, `created_at` ASC, `id` ASC) USING BTREE,
  INDEX `idx_ai_image_tasks_user_status`(`user_id` ASC, `status` ASC, `is_del` ASC, `created_at` ASC, `id` ASC) USING BTREE,
  INDEX `idx_ai_image_tasks_user_favorite`(`user_id` ASC, `is_favorite` ASC, `is_del` ASC, `created_at` ASC, `id` ASC) USING BTREE,
  INDEX `idx_ai_image_tasks_agent_created`(`agent_id` ASC, `created_at` ASC, `id` ASC) USING BTREE,
  INDEX `idx_ai_image_tasks_status_created`(`status` ASC, `created_at` ASC, `id` ASC) USING BTREE,
  CONSTRAINT `chk_ai_image_tasks_del` CHECK (`is_del` in (1,2)),
  CONSTRAINT `chk_ai_image_tasks_favorite` CHECK (`is_favorite` in (1,2)),
  CONSTRAINT `chk_ai_image_tasks_status` CHECK (`status` in (_utf8mb4'pending',_utf8mb4'running',_utf8mb4'success',_utf8mb4'failed'))
) ENGINE = InnoDB AUTO_INCREMENT = 6 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI图片生成任务' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_knowledge_bases
-- ----------------------------
DROP TABLE IF EXISTS `ai_knowledge_bases`;
CREATE TABLE `ai_knowledge_bases`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '知识库ID',
  `name` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '知识库名称，列表、绑定、监控展示',
  `code` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '知识库唯一编码，用于种子幂等和人工识别',
  `description` varchar(1024) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '知识库说明，管理页展示和智能体绑定时辅助选择',
  `chunk_size_chars` int UNSIGNED NOT NULL DEFAULT 1200 COMMENT '默认分块字符数，重建文档分块时使用',
  `chunk_overlap_chars` int UNSIGNED NOT NULL DEFAULT 120 COMMENT '默认分块重叠字符数，重建文档分块时使用',
  `default_top_k` int UNSIGNED NOT NULL DEFAULT 5 COMMENT '检索测试和智能体绑定默认召回条数',
  `default_min_score` decimal(8, 4) NOT NULL DEFAULT 0.1000 COMMENT '检索测试和智能体绑定默认最低分',
  `default_max_context_chars` int UNSIGNED NOT NULL DEFAULT 6000 COMMENT '检索测试和智能体绑定默认上下文字符预算',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1启用 2禁用；运行时只读取启用知识库',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '1删除 2正常；所有查询默认 is_del=2',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_ai_knowledge_bases_code`(`code` ASC, `is_del` ASC) USING BTREE,
  INDEX `idx_ai_knowledge_bases_status`(`status` ASC, `is_del` ASC, `updated_at` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 3 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI知识库' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_knowledge_chunks
-- ----------------------------
DROP TABLE IF EXISTS `ai_knowledge_chunks`;
CREATE TABLE `ai_knowledge_chunks`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '分块ID',
  `knowledge_base_id` bigint UNSIGNED NOT NULL COMMENT 'ai_knowledge_bases.id，检索时直接过滤',
  `document_id` bigint UNSIGNED NOT NULL COMMENT 'ai_knowledge_documents.id',
  `chunk_index` int UNSIGNED NOT NULL COMMENT '同一文档内分块序号，从1开始',
  `title` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '分块标题，默认继承文档标题',
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '分块内容，检索和上下文注入使用',
  `content_chars` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '分块字符数，用于 max_context_chars 预算',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1启用 2禁用；运行时只读取启用分块',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '1删除 2正常',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_ai_knowledge_chunks_doc_index`(`document_id` ASC, `chunk_index` ASC, `is_del` ASC) USING BTREE,
  INDEX `idx_ai_knowledge_chunks_base`(`knowledge_base_id` ASC, `status` ASC, `is_del` ASC, `id` ASC) USING BTREE,
  INDEX `idx_ai_knowledge_chunks_document`(`document_id` ASC, `status` ASC, `is_del` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 9 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI知识库分块' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_knowledge_documents
-- ----------------------------
DROP TABLE IF EXISTS `ai_knowledge_documents`;
CREATE TABLE `ai_knowledge_documents`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '文档ID',
  `knowledge_base_id` bigint UNSIGNED NOT NULL COMMENT 'ai_knowledge_bases.id',
  `title` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文档标题，列表、分块、监控展示',
  `source_type` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'text' COMMENT '来源类型：text/markdown/file；第一版写 text/markdown',
  `source_ref` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '来源标识，如 docs/architecture/04-go-backend-framework.md 或上传文件URL；与 knowledge_base_id、is_del 组成同来源幂等唯一键',
  `content` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文档原文，编辑和重建分块使用',
  `index_status` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'pending' COMMENT 'pending/indexing/indexed/failed；分块状态展示和运行过滤',
  `error_message` varchar(1024) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '分块失败原因，管理页展示',
  `last_indexed_at` datetime NULL DEFAULT NULL COMMENT '最近成功重建分块时间',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1启用 2禁用；运行时只读取启用文档',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '1删除 2正常',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_ai_knowledge_documents_source`(`knowledge_base_id` ASC, `source_ref` ASC, `is_del` ASC) USING BTREE,
  INDEX `idx_ai_knowledge_documents_base`(`knowledge_base_id` ASC, `status` ASC, `is_del` ASC, `updated_at` ASC) USING BTREE,
  INDEX `idx_ai_knowledge_documents_index`(`index_status` ASC, `is_del` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 8 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI知识库文档' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_knowledge_retrieval_hits
-- ----------------------------
DROP TABLE IF EXISTS `ai_knowledge_retrieval_hits`;
CREATE TABLE `ai_knowledge_retrieval_hits`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '命中ID',
  `retrieval_id` bigint UNSIGNED NOT NULL COMMENT 'ai_knowledge_retrievals.id',
  `knowledge_base_id` bigint UNSIGNED NOT NULL COMMENT '命中知识库ID',
  `knowledge_base_name` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '命中时知识库名称快照',
  `document_id` bigint UNSIGNED NOT NULL COMMENT '命中文档ID',
  `document_title` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '命中时文档标题快照',
  `chunk_id` bigint UNSIGNED NOT NULL COMMENT '命中分块ID',
  `chunk_index` int UNSIGNED NOT NULL COMMENT '命中分块序号快照',
  `score` decimal(10, 6) NOT NULL DEFAULT 0.000000 COMMENT '检索评分',
  `rank_no` int UNSIGNED NOT NULL COMMENT '本次检索排序，从1开始',
  `content_snapshot` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '命中内容快照，运行监控和问题复盘使用',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1进入上下文 2跳过',
  `skip_reason` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '跳过原因：low_score/context_limit',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '1删除 2正常',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_ai_knowledge_hits_retrieval`(`retrieval_id` ASC, `status` ASC, `rank_no` ASC) USING BTREE,
  INDEX `idx_ai_knowledge_hits_chunk`(`chunk_id` ASC, `is_del` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 13 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI知识库检索命中' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_knowledge_retrievals
-- ----------------------------
DROP TABLE IF EXISTS `ai_knowledge_retrievals`;
CREATE TABLE `ai_knowledge_retrievals`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '检索ID',
  `run_id` bigint UNSIGNED NOT NULL COMMENT 'ai_runs.id',
  `query` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '本轮检索查询文本，通常为用户消息正文',
  `status` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT 'success/failed/skipped',
  `total_hits` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '原始命中数量',
  `selected_hits` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '进入上下文的命中数量',
  `duration_ms` int UNSIGNED NULL DEFAULT NULL COMMENT '检索耗时毫秒',
  `error_message` varchar(1024) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '失败原因',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '1删除 2正常；运行监控默认只读正常记录',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_ai_knowledge_retrievals_run`(`run_id` ASC, `is_del` ASC, `created_at` ASC) USING BTREE,
  INDEX `idx_ai_knowledge_retrievals_status`(`status` ASC, `is_del` ASC, `created_at` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 3 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI知识库检索记录' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_messages
-- ----------------------------
DROP TABLE IF EXISTS `ai_messages`;
CREATE TABLE `ai_messages`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '消息ID',
  `conversation_id` int UNSIGNED NOT NULL COMMENT 'ai_conversations.id',
  `role` tinyint UNSIGNED NOT NULL COMMENT '1用户 2助手',
  `content_type` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'text' COMMENT '内容类型，MVP只写text',
  `content` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '消息内容',
  `meta_json` json NULL COMMENT '消息扩展元数据：attachments/runtime_params/blocks/feedback',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '1删除 2正常',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_ai_messages_conversation_del_id`(`conversation_id` ASC, `is_del` ASC, `id` ASC) USING BTREE,
  CONSTRAINT `fk_ai_messages_conversation` FOREIGN KEY (`conversation_id`) REFERENCES `ai_conversations` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 51 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI消息' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_provider_models
-- ----------------------------
DROP TABLE IF EXISTS `ai_provider_models`;
CREATE TABLE `ai_provider_models`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `provider_id` bigint UNSIGNED NOT NULL,
  `model_id` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `display_name` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_ai_provider_models_provider_model`(`provider_id` ASC, `model_id` ASC) USING BTREE,
  INDEX `idx_ai_provider_models_provider_status`(`provider_id` ASC, `status` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 14 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI provider enabled model catalog' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_providers
-- ----------------------------
DROP TABLE IF EXISTS `ai_providers`;
CREATE TABLE `ai_providers`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `engine_type` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `base_url` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `api_key_enc` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `api_key_hint` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `health_status` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'unknown',
  `last_checked_at` datetime NULL DEFAULT NULL,
  `last_check_error` varchar(1024) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `last_model_sync_at` datetime NULL DEFAULT NULL,
  `last_model_sync_status` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'unknown',
  `last_model_sync_error` varchar(1024) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1,
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_ai_providers_type_name`(`engine_type` ASC, `name` ASC, `is_del` ASC) USING BTREE,
  INDEX `idx_ai_providers_status`(`status` ASC, `is_del` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 4 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI engine connection configs' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_run_events
-- ----------------------------
DROP TABLE IF EXISTS `ai_run_events`;
CREATE TABLE `ai_run_events`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '事件ID',
  `run_id` bigint UNSIGNED NOT NULL COMMENT 'ai_runs.id',
  `seq` int UNSIGNED NOT NULL COMMENT '同一run内事件序号',
  `event_type` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT 'start/completed/failed/canceled/timeout',
  `message` varchar(1024) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '事件说明或错误原因',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '事件时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_ai_run_events_run_seq`(`run_id` ASC, `seq` ASC) USING BTREE,
  INDEX `idx_ai_run_events_run_id`(`run_id` ASC, `id` ASC) USING BTREE,
  INDEX `idx_ai_run_events_type_created`(`event_type` ASC, `created_at` ASC, `id` ASC) USING BTREE,
  CONSTRAINT `fk_ai_run_events_run` FOREIGN KEY (`run_id`) REFERENCES `ai_runs` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `chk_ai_run_events_type` CHECK (`event_type` in (_utf8mb4'start',_utf8mb4'completed',_utf8mb4'failed',_utf8mb4'canceled',_utf8mb4'timeout'))
) ENGINE = InnoDB AUTO_INCREMENT = 33 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI运行监控事件' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_runs
-- ----------------------------
DROP TABLE IF EXISTS `ai_runs`;
CREATE TABLE `ai_runs`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '运行ID',
  `conversation_id` int UNSIGNED NOT NULL COMMENT 'ai_conversations.id',
  `request_id` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '客户端本轮请求ID',
  `user_message_id` bigint UNSIGNED NOT NULL COMMENT '本轮用户消息ID',
  `assistant_message_id` bigint UNSIGNED NULL DEFAULT NULL COMMENT '完成后写入的助手消息ID',
  `user_id` int UNSIGNED NOT NULL COMMENT '发起用户ID',
  `agent_id` bigint UNSIGNED NOT NULL COMMENT 'ai_agents.id',
  `provider_id` bigint UNSIGNED NOT NULL COMMENT 'ai_providers.id',
  `model_id` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '实际调用模型ID',
  `model_display_name` varchar(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '实际调用模型展示名',
  `status` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT 'queued/running/success/failed/canceled/timeout',
  `prompt_tokens` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '输入token',
  `completion_tokens` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '输出token',
  `total_tokens` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '总token',
  `duration_ms` int UNSIGNED NULL DEFAULT NULL COMMENT '运行耗时毫秒，终态后写入',
  `error_message` varchar(1024) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '失败/取消/超时原因',
  `started_at` datetime NULL DEFAULT NULL COMMENT '开始调用模型时间',
  `finished_at` datetime NULL DEFAULT NULL COMMENT '进入终态时间',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_ai_runs_conversation_request`(`conversation_id` ASC, `request_id` ASC) USING BTREE,
  UNIQUE INDEX `uk_ai_runs_user_message`(`user_message_id` ASC) USING BTREE,
  INDEX `idx_ai_runs_created`(`created_at` ASC, `id` ASC) USING BTREE,
  INDEX `idx_ai_runs_status_created`(`status` ASC, `created_at` ASC, `id` ASC) USING BTREE,
  INDEX `idx_ai_runs_user_created`(`user_id` ASC, `created_at` ASC, `id` ASC) USING BTREE,
  INDEX `idx_ai_runs_agent_created`(`agent_id` ASC, `created_at` ASC, `id` ASC) USING BTREE,
  INDEX `idx_ai_runs_provider_created`(`provider_id` ASC, `created_at` ASC, `id` ASC) USING BTREE,
  INDEX `idx_ai_runs_conversation_created`(`conversation_id` ASC, `created_at` ASC, `id` ASC) USING BTREE,
  INDEX `fk_ai_runs_assistant_message`(`assistant_message_id` ASC) USING BTREE,
  CONSTRAINT `fk_ai_runs_assistant_message` FOREIGN KEY (`assistant_message_id`) REFERENCES `ai_messages` (`id`) ON DELETE SET NULL ON UPDATE RESTRICT,
  CONSTRAINT `fk_ai_runs_conversation` FOREIGN KEY (`conversation_id`) REFERENCES `ai_conversations` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `fk_ai_runs_user_message` FOREIGN KEY (`user_message_id`) REFERENCES `ai_messages` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `chk_ai_runs_status` CHECK (`status` in (_utf8mb4'running',_utf8mb4'success',_utf8mb4'failed',_utf8mb4'canceled',_utf8mb4'timeout'))
) ENGINE = InnoDB AUTO_INCREMENT = 17 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI运行监控记录' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_tool_calls
-- ----------------------------
DROP TABLE IF EXISTS `ai_tool_calls`;
CREATE TABLE `ai_tool_calls`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '工具调用ID',
  `run_id` bigint UNSIGNED NOT NULL COMMENT 'ai_runs.id',
  `tool_id` bigint UNSIGNED NOT NULL COMMENT 'ai_tools.id',
  `tool_code` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '调用时工具编码快照',
  `tool_name` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '调用时工具名称快照',
  `call_id` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '模型返回的tool_call_id/call_id，用于回传工具结果',
  `status` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT 'running/success/failed/timeout',
  `arguments_json` json NOT NULL COMMENT '模型传入参数',
  `result_json` json NULL COMMENT '工具返回结果',
  `error_message` varchar(1024) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '失败或超时原因',
  `duration_ms` int UNSIGNED NULL DEFAULT NULL COMMENT '执行耗时毫秒，终态后写入',
  `started_at` datetime NOT NULL COMMENT '开始执行时间',
  `finished_at` datetime NULL DEFAULT NULL COMMENT '结束时间',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_ai_tool_calls_run_call`(`run_id` ASC, `call_id` ASC) USING BTREE,
  INDEX `idx_ai_tool_calls_run_id`(`run_id` ASC, `id` ASC) USING BTREE,
  INDEX `idx_ai_tool_calls_tool_created`(`tool_id` ASC, `created_at` ASC, `id` ASC) USING BTREE,
  INDEX `idx_ai_tool_calls_status_created`(`status` ASC, `created_at` ASC, `id` ASC) USING BTREE,
  CONSTRAINT `fk_ai_tool_calls_run` FOREIGN KEY (`run_id`) REFERENCES `ai_runs` (`id`) ON DELETE CASCADE ON UPDATE RESTRICT,
  CONSTRAINT `fk_ai_tool_calls_tool` FOREIGN KEY (`tool_id`) REFERENCES `ai_tools` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `chk_ai_tool_calls_status` CHECK (`status` in (_utf8mb4'running',_utf8mb4'success',_utf8mb4'failed',_utf8mb4'timeout'))
) ENGINE = InnoDB AUTO_INCREMENT = 2 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI工具调用记录' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_tools
-- ----------------------------
DROP TABLE IF EXISTS `ai_tools`;
CREATE TABLE `ai_tools`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '工具ID',
  `name` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '工具名称，管理页和运行监控展示',
  `code` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '工具唯一编码，传给模型作为function name',
  `description` varchar(1024) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '工具说明，传给模型作为function description',
  `parameters_json` json NOT NULL COMMENT '工具参数JSON Schema，传给模型并用于入参校验',
  `result_schema_json` json NOT NULL COMMENT '工具返回JSON Schema，用于结果校验和运行监控展示',
  `risk_level` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '风险等级：low/medium/high',
  `timeout_ms` int UNSIGNED NOT NULL DEFAULT 3000 COMMENT '执行超时毫秒，运行时context timeout',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1启用 2禁用',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '1删除 2正常',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_ai_tools_code`(`code` ASC) USING BTREE,
  INDEX `idx_ai_tools_status_del`(`status` ASC, `is_del` ASC, `id` ASC) USING BTREE,
  CONSTRAINT `chk_ai_tools_is_del` CHECK (`is_del` in (1,2)),
  CONSTRAINT `chk_ai_tools_risk_level` CHECK (`risk_level` in (_utf8mb4'low',_utf8mb4'medium',_utf8mb4'high')),
  CONSTRAINT `chk_ai_tools_status` CHECK (`status` in (1,2))
) ENGINE = InnoDB AUTO_INCREMENT = 3 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI工具定义' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for auth_platforms
-- ----------------------------
DROP TABLE IF EXISTS `auth_platforms`;
CREATE TABLE `auth_platforms`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `code` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '平台标识（如 admin, app）',
  `name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '平台名称',
  `login_types` json NOT NULL COMMENT '允许的登录方式 [\"password\",\"email\",\"phone\"]',
  `captcha_type` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'slide' COMMENT '验证码类型: slide',
  `access_ttl` int UNSIGNED NOT NULL DEFAULT 14400 COMMENT 'access_token 有效期（秒）',
  `refresh_ttl` int UNSIGNED NOT NULL DEFAULT 1209600 COMMENT 'refresh_token 有效期（秒）',
  `bind_platform` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '绑定平台 1=是 2=否',
  `bind_device` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '绑定设备 1=是 2=否',
  `bind_ip` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '绑定IP 1=是 2=否',
  `single_session` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '单端登录 1=是 2=否',
  `max_sessions` int UNSIGNED NOT NULL DEFAULT 5 COMMENT '最大会话数（0=不限）',
  `allow_register` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '允许注册 1=是 2=否',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '状态 1=启用 2=禁用',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '软删除 1=已删 2=正常',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_code`(`code` ASC) USING BTREE,
  INDEX `idx_status_del`(`status` ASC, `is_del` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 3 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '认证平台管理' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for client_versions
-- ----------------------------
DROP TABLE IF EXISTS `client_versions`;
CREATE TABLE `client_versions`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `version` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '版本号',
  `notes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL COMMENT '更新说明',
  `file_url` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文件地址',
  `signature` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '签名',
  `platform` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'windows-x86_64' COMMENT '平台',
  `file_size` int UNSIGNED NULL DEFAULT NULL COMMENT '文件大小(字节)',
  `is_latest` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `force_update` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT 'soft delete: 1 deleted 2 normal',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_version_platform_del`(`version` ASC, `platform` ASC, `is_del` ASC) USING BTREE,
  INDEX `idx_platform_latest`(`platform` ASC, `is_latest` ASC) USING BTREE COMMENT '平台最新版本索引',
  INDEX `idx_force_update`(`force_update` ASC) USING BTREE COMMENT '强制更新索引',
  INDEX `idx_created_at`(`created_at` ASC) USING BTREE COMMENT '创建时间索引'
) ENGINE = InnoDB AUTO_INCREMENT = 9 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '客户端版本管理' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for cron_task
-- ----------------------------
DROP TABLE IF EXISTS `cron_task`;
CREATE TABLE `cron_task`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '任务标识（唯一）',
  `title` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '任务名称',
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '任务描述',
  `cron` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT 'Cron表达式',
  `cron_readable` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT 'Cron可读描述',
  `handler` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '处理类',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1,
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uniq_cron_task_name`(`name` ASC) USING BTREE,
  INDEX `idx_status_del`(`status` ASC, `is_del` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 15 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '定时任务配置表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for cron_task_log
-- ----------------------------
DROP TABLE IF EXISTS `cron_task_log`;
CREATE TABLE `cron_task_log`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `task_id` bigint UNSIGNED NOT NULL COMMENT '任务ID',
  `task_name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '任务标识',
  `start_time` datetime(3) NOT NULL COMMENT '开始时间',
  `end_time` datetime(3) NULL DEFAULT NULL COMMENT '结束时间',
  `duration_ms` int UNSIGNED NULL DEFAULT NULL COMMENT '执行耗时(毫秒)',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1,
  `result` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL COMMENT '执行结果',
  `error_msg` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL COMMENT '错误信息',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT 'soft delete: 1 deleted 2 normal',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_task_del_id`(`task_id` ASC, `is_del` ASC) USING BTREE,
  INDEX `idx_name_del_id`(`task_name` ASC, `is_del` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 50684 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '定时任务执行日志表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for export_tasks
-- ----------------------------
DROP TABLE IF EXISTS `export_tasks`;
CREATE TABLE `export_tasks`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int UNSIGNED NOT NULL COMMENT '创建用户ID',
  `title` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '任务标题',
  `file_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '文件名',
  `file_url` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '文件下载URL',
  `file_size` int UNSIGNED NULL DEFAULT NULL COMMENT '文件大小（字节）',
  `row_count` int UNSIGNED NULL DEFAULT NULL COMMENT '数据行数',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1处理中 2成功 3失败',
  `error_msg` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '失败原因',
  `expire_at` datetime NULL DEFAULT NULL COMMENT '过期时间（定时任务清理）',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '2正常 1删除',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_user_status`(`user_id` ASC, `status` ASC, `is_del` ASC) USING BTREE,
  INDEX `idx_expire`(`expire_at` ASC) USING BTREE,
  INDEX `idx_created`(`created_at` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 117 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '导出任务记录' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for mail_configs
-- ----------------------------
DROP TABLE IF EXISTS `mail_configs`;
CREATE TABLE `mail_configs`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `config_key` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'default',
  `secret_id_enc` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `secret_id_hint` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `secret_key_enc` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `secret_key_hint` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `region` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'ap-guangzhou',
  `endpoint` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'ses.tencentcloudapi.com',
  `from_email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `from_name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `reply_to` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `last_test_at` datetime NULL DEFAULT NULL,
  `last_test_error` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_mail_configs_config_key`(`config_key` ASC) USING BTREE,
  INDEX `idx_mail_configs_status_del`(`status` ASC, `is_del` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 2 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for mail_logs
-- ----------------------------
DROP TABLE IF EXISTS `mail_logs`;
CREATE TABLE `mail_logs`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `scene` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `template_id` bigint UNSIGNED NULL DEFAULT NULL,
  `to_email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `subject` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `tencent_request_id` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `tencent_message_id` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `status` tinyint UNSIGNED NOT NULL,
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `error_code` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `error_message` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `duration_ms` bigint UNSIGNED NOT NULL DEFAULT 0,
  `sent_at` datetime NULL DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_mail_logs_scene_created`(`is_del` ASC, `scene` ASC, `created_at` ASC) USING BTREE,
  INDEX `idx_mail_logs_status_created`(`is_del` ASC, `status` ASC, `created_at` ASC) USING BTREE,
  INDEX `idx_mail_logs_to_email_created`(`is_del` ASC, `to_email` ASC, `created_at` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 6 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for mail_templates
-- ----------------------------
DROP TABLE IF EXISTS `mail_templates`;
CREATE TABLE `mail_templates`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `scene` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `subject` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `tencent_template_id` bigint UNSIGNED NOT NULL,
  `variables_json` json NOT NULL,
  `sample_variables_json` json NOT NULL,
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1,
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_mail_templates_scene`(`scene` ASC) USING BTREE,
  INDEX `idx_mail_templates_status_del`(`status` ASC, `is_del` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 5 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for notification_task
-- ----------------------------
DROP TABLE IF EXISTS `notification_task`;
CREATE TABLE `notification_task`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `title` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '标题',
  `content` mediumtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL COMMENT '内容',
  `type` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT 'type: 1 info 2 success 3 warning 4 error',
  `level` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT 'level: 1 normal 2 urgent',
  `link` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '' COMMENT '跳转链接',
  `platform` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'all' COMMENT '平台 all/admin/app',
  `target_type` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT 'target type: 1 all 2 users 3 roles',
  `target_ids` json NULL COMMENT '目标ID列表',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1,
  `total_count` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '目标用户数',
  `sent_count` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '已发送数',
  `send_at` datetime NULL DEFAULT NULL COMMENT '定时发送时间（空=立即发送）',
  `error_msg` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '错误信息',
  `created_by` int UNSIGNED NOT NULL COMMENT 'Creator user id',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT 'soft delete: 1 deleted 2 normal',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_status_del_send`(`status` ASC, `is_del` ASC, `send_at` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 13 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for notifications
-- ----------------------------
DROP TABLE IF EXISTS `notifications`;
CREATE TABLE `notifications`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int UNSIGNED NOT NULL COMMENT '接收用户ID',
  `title` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '标题',
  `content` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '' COMMENT '内容',
  `type` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT 'type: 1 normal 2 success 3 warning 4 error',
  `level` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT 'level: 1 normal 2 urgent',
  `link` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '' COMMENT '跳转路由',
  `platform` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'all' COMMENT '平台 all/admin/app',
  `is_read` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '1 read 2 unread',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_user_platform_del_id`(`user_id` ASC, `is_del` ASC, `id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 3079 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '用户通知表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for operation_logs
-- ----------------------------
DROP TABLE IF EXISTS `operation_logs`;
CREATE TABLE `operation_logs`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `user_id` int UNSIGNED NOT NULL DEFAULT 0,
  `action` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '操作行为/接口名称',
  `request_data` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL COMMENT '请求入参',
  `response_data` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL COMMENT '响应出参',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '2正常 1删除',
  `is_success` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1 success 2 fail',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_action`(`action` ASC) USING BTREE,
  INDEX `idx_created_at`(`created_at` ASC) USING BTREE,
  INDEX `idx_del_created_id`(`is_del` ASC, `created_at` ASC, `id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 102350 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '操作日志表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for payment_configs
-- ----------------------------
DROP TABLE IF EXISTS `payment_configs`;
CREATE TABLE `payment_configs`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `provider` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'alipay',
  `code` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `app_id` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `private_key_enc` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `private_key_hint` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `app_cert_path` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `platform_cert_path` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `root_cert_path` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `notify_url` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `environment` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'sandbox',
  `enabled_methods_json` json NOT NULL,
  `sort` int NOT NULL DEFAULT 100,
  `status` tinyint NOT NULL DEFAULT 2,
  `remark` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `is_del` tinyint NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_payment_configs_code`(`code` ASC) USING BTREE,
  INDEX `idx_payment_configs_provider_status`(`provider` ASC, `status` ASC, `is_del` ASC) USING BTREE,
  INDEX `idx_payment_configs_environment`(`environment` ASC, `is_del` ASC) USING BTREE,
  INDEX `idx_payment_configs_provider_status_sort`(`provider` ASC, `status` ASC, `is_del` ASC, `sort` ASC, `id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 2 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for payment_orders
-- ----------------------------
DROP TABLE IF EXISTS `payment_orders`;
CREATE TABLE `payment_orders`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `order_no` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `config_id` bigint NOT NULL,
  `config_code` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `provider` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'alipay',
  `pay_method` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `subject` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `amount_cents` bigint NOT NULL,
  `status` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `pay_url` varchar(2048) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `return_url` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `alipay_trade_no` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `expired_at` datetime NOT NULL,
  `paid_at` datetime NULL DEFAULT NULL,
  `closed_at` datetime NULL DEFAULT NULL,
  `failure_reason` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `is_del` tinyint NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_payment_order_no`(`order_no` ASC) USING BTREE,
  INDEX `idx_payment_order_status_created`(`is_del` ASC, `status` ASC, `created_at` ASC) USING BTREE,
  INDEX `idx_payment_order_config_created`(`config_id` ASC, `created_at` ASC, `is_del` ASC) USING BTREE,
  CONSTRAINT `fk_payment_order_config` FOREIGN KEY (`config_id`) REFERENCES `payment_configs` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 3 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for payment_recharge_packages
-- ----------------------------
DROP TABLE IF EXISTS `payment_recharge_packages`;
CREATE TABLE `payment_recharge_packages`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `code` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `amount_cents` bigint NOT NULL,
  `badge` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `sort` int NOT NULL DEFAULT 100,
  `status` tinyint NOT NULL DEFAULT 1,
  `is_del` tinyint NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_payment_recharge_package_code`(`code` ASC) USING BTREE,
  INDEX `idx_payment_recharge_package_status_sort`(`status` ASC, `is_del` ASC, `sort` ASC, `id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 9 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for payment_recharges
-- ----------------------------
DROP TABLE IF EXISTS `payment_recharges`;
CREATE TABLE `payment_recharges`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `recharge_no` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_id` bigint NOT NULL,
  `package_code` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `package_name` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `amount_cents` bigint NOT NULL,
  `payment_order_id` bigint NOT NULL,
  `status` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `paid_at` datetime NULL DEFAULT NULL,
  `credited_at` datetime NULL DEFAULT NULL,
  `failure_reason` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `is_del` tinyint NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_payment_recharge_no`(`recharge_no` ASC) USING BTREE,
  UNIQUE INDEX `uk_payment_recharge_order`(`payment_order_id` ASC) USING BTREE,
  INDEX `idx_payment_recharge_user_status_created`(`user_id` ASC, `is_del` ASC, `status` ASC, `created_at` ASC) USING BTREE,
  INDEX `idx_payment_recharge_created`(`is_del` ASC, `created_at` ASC) USING BTREE,
  CONSTRAINT `fk_payment_recharge_order` FOREIGN KEY (`payment_order_id`) REFERENCES `payment_orders` (`id`) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE = InnoDB AUTO_INCREMENT = 3 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for permissions
-- ----------------------------
DROP TABLE IF EXISTS `permissions`;
CREATE TABLE `permissions`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '权限名',
  `path` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '' COMMENT '路由',
  `icon` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '' COMMENT '图标',
  `parent_id` int UNSIGNED NOT NULL DEFAULT 0 COMMENT 'parent permission id; 0 means root',
  `component` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '组件路径',
  `platform` varchar(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'admin' COMMENT '平台：admin=PC后台, app=H5/APP',
  `type` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT 'type: 1 dir 2 page 3 button',
  `sort` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '排序',
  `code` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '权限标识',
  `i18n_key` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT 'i18n键',
  `show_menu` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT 'show menu: 1 yes 2 no',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1,
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_permissions_platform_code`(`platform` ASC, `code` ASC) USING BTREE,
  INDEX `idx_permissions_platform`(`platform` ASC) USING BTREE,
  INDEX `idx_permissions_parent_sort`(`parent_id` ASC, `sort` ASC) USING BTREE,
  INDEX `idx_permissions_status_del_platform_type`(`is_del` ASC, `status` ASC, `platform` ASC, `type` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 586 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '菜单权限表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for role_permissions
-- ----------------------------
DROP TABLE IF EXISTS `role_permissions`;
CREATE TABLE `role_permissions`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `role_id` int UNSIGNED NOT NULL COMMENT 'role.id',
  `permission_id` int UNSIGNED NOT NULL COMMENT 'permission.id',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uniq_role_permission`(`role_id` ASC, `permission_id` ASC) USING BTREE,
  INDEX `idx_role_permissions_permission_del_role`(`permission_id` ASC, `is_del` ASC, `role_id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 777 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'role permission pivot' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for roles
-- ----------------------------
DROP TABLE IF EXISTS `roles`;
CREATE TABLE `roles`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT 'role name',
  `is_default` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_roles_name`(`name` ASC) USING BTREE,
  INDEX `idx_roles_default_del`(`is_default` ASC, `is_del` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 9 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '角色' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for sms_configs
-- ----------------------------
DROP TABLE IF EXISTS `sms_configs`;
CREATE TABLE `sms_configs`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `config_key` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'default',
  `secret_id_enc` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `secret_id_hint` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `secret_key_enc` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `secret_key_hint` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `sms_sdk_app_id` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `sign_name` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `region` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'ap-guangzhou',
  `endpoint` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'sms.tencentcloudapi.com',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `last_test_at` datetime NULL DEFAULT NULL,
  `last_test_error` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_sms_configs_config_key`(`config_key` ASC) USING BTREE,
  INDEX `idx_sms_configs_status_del`(`status` ASC, `is_del` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for sms_logs
-- ----------------------------
DROP TABLE IF EXISTS `sms_logs`;
CREATE TABLE `sms_logs`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `scene` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `template_id` bigint UNSIGNED NULL DEFAULT NULL,
  `to_phone` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `status` tinyint UNSIGNED NOT NULL,
  `tencent_request_id` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `tencent_serial_no` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `tencent_fee` bigint UNSIGNED NOT NULL DEFAULT 0,
  `error_code` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `error_message` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `duration_ms` bigint UNSIGNED NOT NULL DEFAULT 0,
  `sent_at` datetime NULL DEFAULT NULL,
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_sms_logs_scene_created`(`is_del` ASC, `scene` ASC, `created_at` ASC) USING BTREE,
  INDEX `idx_sms_logs_status_created`(`is_del` ASC, `status` ASC, `created_at` ASC) USING BTREE,
  INDEX `idx_sms_logs_to_phone_created`(`is_del` ASC, `to_phone` ASC, `created_at` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for sms_templates
-- ----------------------------
DROP TABLE IF EXISTS `sms_templates`;
CREATE TABLE `sms_templates`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `scene` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `tencent_template_id` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `variables_json` json NOT NULL,
  `sample_variables_json` json NOT NULL,
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1,
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_sms_templates_scene`(`scene` ASC) USING BTREE,
  INDEX `idx_sms_templates_status_del`(`status` ASC, `is_del` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for system_settings
-- ----------------------------
DROP TABLE IF EXISTS `system_settings`;
CREATE TABLE `system_settings`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `setting_key` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '配置键：如 user.default_avatar',
  `setting_value` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '配置值（字符串/JSON字符串均可）',
  `value_type` tinyint UNSIGNED NOT NULL DEFAULT 1,
  `remark` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '备注说明',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1,
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uniq_setting_key`(`setting_key` ASC) USING BTREE,
  INDEX `idx_status_del`(`status` ASC, `is_del` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 15 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '系统设置（key-value）' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for upload_driver
-- ----------------------------
DROP TABLE IF EXISTS `upload_driver`;
CREATE TABLE `upload_driver`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `driver` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT 'cos / oss / s3 / qiniu 等',
  `secret_id_enc` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `secret_id_hint` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `secret_key_enc` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL,
  `secret_key_hint` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL,
  `bucket` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `region` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `appid` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT 'COS 特有',
  `endpoint` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT 'OSS/S3/AP custom domain',
  `bucket_domain` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '返回给前端用于访问的域名（可配 CDN）',
  `role_arn` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT 'OSS AssumeRole / AWS role arn',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uniq_driver_bucket`(`driver` ASC, `bucket` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 41 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for upload_rule
-- ----------------------------
DROP TABLE IF EXISTS `upload_rule`;
CREATE TABLE `upload_rule`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `title` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '规则标题',
  `max_size_mb` int UNSIGNED NOT NULL DEFAULT 5 COMMENT '最大 MB',
  `image_exts` json NOT NULL COMMENT '允许的图片扩展名',
  `file_exts` json NOT NULL COMMENT '允许的通用文件扩展名',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 37 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for upload_setting
-- ----------------------------
DROP TABLE IF EXISTS `upload_setting`;
CREATE TABLE `upload_setting`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `driver_id` int UNSIGNED NOT NULL,
  `rule_id` int UNSIGNED NOT NULL,
  `status` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `remark` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '备注',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uniq_driver_rule`(`driver_id` ASC, `rule_id` ASC) USING BTREE,
  INDEX `idx_status`(`status` ASC) USING BTREE,
  INDEX `idx_rule`(`rule_id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 43 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '上传设置：驱动+规则组合与启用状态' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for user_profiles
-- ----------------------------
DROP TABLE IF EXISTS `user_profiles`;
CREATE TABLE `user_profiles`  (
  `user_id` int UNSIGNED NOT NULL,
  `avatar` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'https://zgm-1314542588.cos.ap-nanjing.myqcloud.com/defaultAvatar%2Favatar.jpg' COMMENT '头像',
  `bio` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL COMMENT '个人简介',
  `sex` tinyint UNSIGNED NOT NULL DEFAULT 0 COMMENT 'sex: 0 unknown 1 male 2 female',
  `birthday` date NULL DEFAULT NULL COMMENT '生日',
  `address_id` int UNSIGNED NULL DEFAULT NULL COMMENT '地址ID',
  `detail_address` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '详细地址',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT 'soft delete: 1 deleted 2 normal',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`user_id`) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '用户资料表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for user_sessions
-- ----------------------------
DROP TABLE IF EXISTS `user_sessions`;
CREATE TABLE `user_sessions`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int UNSIGNED NOT NULL,
  `access_token_hash` char(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT 'access token sha256',
  `refresh_token_hash` char(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT 'refresh token sha256',
  `platform` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT 'pc/h5/app/mini',
  `device_id` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '设备标识(前端生成uuid即可)',
  `ip` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '登录IP',
  `ua` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT 'User-Agent',
  `last_seen_at` datetime NULL DEFAULT NULL COMMENT '最后活跃时间',
  `expires_at` datetime NOT NULL COMMENT 'access过期时间',
  `refresh_expires_at` datetime NOT NULL COMMENT 'refresh过期时间',
  `revoked_at` datetime NULL DEFAULT NULL COMMENT '注销/踢下线时间',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '2 normal 1 deleted',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uniq_access_hash`(`access_token_hash` ASC) USING BTREE,
  UNIQUE INDEX `uniq_refresh_hash`(`refresh_token_hash` ASC) USING BTREE,
  INDEX `idx_user_platform`(`user_id` ASC, `platform` ASC) USING BTREE,
  INDEX `idx_expires_at`(`expires_at` ASC) USING BTREE,
  INDEX `idx_refresh_expires_at`(`refresh_expires_at` ASC) USING BTREE,
  INDEX `idx_active_stats`(`is_del` ASC, `revoked_at` ASC, `expires_at` ASC, `platform` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 913 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '用户会话表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for user_wallets
-- ----------------------------
DROP TABLE IF EXISTS `user_wallets`;
CREATE TABLE `user_wallets`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `user_id` bigint NOT NULL,
  `balance_cents` bigint NOT NULL DEFAULT 0,
  `total_recharge_cents` bigint NOT NULL DEFAULT 0,
  `is_del` tinyint NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_user_wallet_user`(`user_id` ASC) USING BTREE,
  INDEX `idx_user_wallet_isdel`(`is_del` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 2 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for users
-- ----------------------------
DROP TABLE IF EXISTS `users`;
CREATE TABLE `users`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `role_id` int UNSIGNED NOT NULL DEFAULT 1,
  `username` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '用户名',
  `email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '邮箱',
  `password` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '密码(可空: 首次第三方/邮箱免密创建)',
  `phone` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '手机号',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1,
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uniq_users_email`(`email` ASC) USING BTREE,
  UNIQUE INDEX `uniq_users_phone`(`phone` ASC) USING BTREE,
  INDEX `idx_users_role_del`(`role_id` ASC, `is_del` ASC) USING BTREE,
  INDEX `idx_users_active`(`is_del` ASC, `status` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 3068 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '用户表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for users_login_log
-- ----------------------------
DROP TABLE IF EXISTS `users_login_log`;
CREATE TABLE `users_login_log`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int UNSIGNED NULL DEFAULT NULL,
  `login_account` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '登录账号',
  `login_type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'email' COMMENT '登录类型',
  `platform` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '平台',
  `ip` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT 'IP地址',
  `ua` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT 'User-Agent',
  `is_success` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '1 success 2 fail',
  `reason` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '失败原因',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT 'soft delete: 1 deleted 2 normal',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'updated at',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_user_created`(`user_id` ASC, `created_at` DESC) USING BTREE,
  INDEX `idx_account_created`(`login_account` ASC, `created_at` DESC) USING BTREE,
  INDEX `idx_ip_created`(`ip` ASC, `created_at` DESC) USING BTREE,
  INDEX `idx_created`(`created_at` DESC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 951 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '登录日志' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for users_quick_entry
-- ----------------------------
DROP TABLE IF EXISTS `users_quick_entry`;
CREATE TABLE `users_quick_entry`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int UNSIGNED NOT NULL,
  `permission_id` int UNSIGNED NOT NULL COMMENT 'Permission menu ID (permission.id)',
  `sort` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '排序',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '1 deleted 2 normal',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_user_del_sort`(`user_id` ASC, `is_del` ASC, `sort` ASC) USING BTREE,
  INDEX `idx_user_permission_del`(`user_id` ASC, `permission_id` ASC, `is_del` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 108 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '用户快捷入口' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for wallet_transactions
-- ----------------------------
DROP TABLE IF EXISTS `wallet_transactions`;
CREATE TABLE `wallet_transactions`  (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `transaction_no` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `wallet_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `direction` varchar(16) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `amount_cents` bigint NOT NULL,
  `balance_before_cents` bigint NOT NULL,
  `balance_after_cents` bigint NOT NULL,
  `source_type` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `source_id` bigint NOT NULL,
  `remark` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT '',
  `is_del` tinyint NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_wallet_transaction_no`(`transaction_no` ASC) USING BTREE,
  UNIQUE INDEX `uk_wallet_transaction_source`(`source_type` ASC, `source_id` ASC) USING BTREE,
  INDEX `idx_wallet_transaction_user_created`(`user_id` ASC, `is_del` ASC, `created_at` ASC) USING BTREE,
  INDEX `idx_wallet_transaction_wallet_created`(`wallet_id` ASC, `is_del` ASC, `created_at` ASC) USING BTREE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_unicode_ci ROW_FORMAT = Dynamic;

SET FOREIGN_KEY_CHECKS = 1;
