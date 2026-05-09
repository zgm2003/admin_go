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

 Date: 08/05/2026 12:53:19
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
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `agent_id` int UNSIGNED NOT NULL COMMENT 'ai_agents.id',
  `knowledge_base_id` int UNSIGNED NOT NULL COMMENT 'ai_knowledge_bases.id',
  `config_json` json NULL COMMENT '绑定级配置',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1启用 2禁用',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT 'soft delete: 1 deleted, 2 normal',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'created time',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'updated time',
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_ai_agent_knowledge_bases_agent_kb`(`agent_id` ASC, `knowledge_base_id` ASC) USING BTREE,
  INDEX `idx_ai_agent_knowledge_bases_kb_status`(`knowledge_base_id` ASC, `status` ASC, `is_del` ASC) USING BTREE,
  INDEX `idx_ai_agent_knowledge_bases_agent_status`(`agent_id` ASC, `status` ASC, `is_del` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 3 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI智能体知识库绑定' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_agent_scenes
-- ----------------------------
DROP TABLE IF EXISTS `ai_agent_scenes`;
CREATE TABLE `ai_agent_scenes`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `agent_id` int UNSIGNED NOT NULL COMMENT 'ai_agents.id',
  `scene_code` varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '场景编码，如 goods_script/cine_project/cine_keyframe',
  `prompt_overlay` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL COMMENT '该场景追加提示词',
  `config_json` json NULL COMMENT '该场景运行配置覆盖',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1启用 2禁用',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '2正常 1删除',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uniq_agent_scene`(`agent_id` ASC, `scene_code` ASC) USING BTREE,
  INDEX `idx_scene_status_del`(`scene_code` ASC, `status` ASC, `is_del` ASC) USING BTREE,
  INDEX `idx_agent_del`(`agent_id` ASC, `is_del` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 5 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI智能体多场景绑定' ROW_FORMAT = Dynamic;

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
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI智能体' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_assistant_tools
-- ----------------------------
DROP TABLE IF EXISTS `ai_assistant_tools`;
CREATE TABLE `ai_assistant_tools`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `assistant_id` int UNSIGNED NOT NULL COMMENT 'ai_agents.id',
  `tool_id` int UNSIGNED NOT NULL COMMENT 'ai_tools.id',
  `config_json` json NULL COMMENT '该助手下工具的个性化配置',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1启用 2禁用',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '2正常 1删除',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uniq_assistant_tool`(`assistant_id` ASC, `tool_id` ASC) USING BTREE,
  INDEX `idx_tool_id`(`tool_id` ASC) USING BTREE,
  INDEX `idx_assistant_del_status`(`assistant_id` ASC, `is_del` ASC, `status` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 11 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '助手绑定工具' ROW_FORMAT = Dynamic;

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
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI会话' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_knowledge_bases
-- ----------------------------
DROP TABLE IF EXISTS `ai_knowledge_bases`;
CREATE TABLE `ai_knowledge_bases`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `name` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '知识库名称',
  `description` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '描述',
  `owner_user_id` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '创建用户ID，第一版权限预留',
  `visibility` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'private' COMMENT 'private/team/public，第一版权限预留',
  `permission_json` json NULL COMMENT '权限配置预留',
  `chunk_size` int UNSIGNED NOT NULL DEFAULT 800 COMMENT '切片长度',
  `chunk_overlap` int UNSIGNED NOT NULL DEFAULT 120 COMMENT '切片重叠',
  `top_k` int UNSIGNED NOT NULL DEFAULT 5 COMMENT '默认召回数量',
  `score_threshold` decimal(8, 2) NOT NULL DEFAULT 0.00 COMMENT '关键词分数阈值',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1启用 2禁用',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT 'soft delete: 1 deleted, 2 normal',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'created time',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'updated time',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_ai_knowledge_bases_status_id`(`status` ASC, `is_del` ASC, `id` ASC) USING BTREE,
  INDEX `idx_ai_knowledge_bases_owner_id`(`owner_user_id` ASC, `id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 4 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI知识库' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_knowledge_chunks
-- ----------------------------
DROP TABLE IF EXISTS `ai_knowledge_chunks`;
CREATE TABLE `ai_knowledge_chunks`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `knowledge_base_id` int UNSIGNED NOT NULL COMMENT 'ai_knowledge_bases.id',
  `document_id` int UNSIGNED NOT NULL COMMENT 'ai_knowledge_documents.id',
  `chunk_no` int UNSIGNED NOT NULL COMMENT '文档内切片序号，从1开始',
  `content` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '切片内容',
  `token_estimate` int UNSIGNED NOT NULL DEFAULT 1 COMMENT '粗略 token 估算',
  `metadata_json` json NULL COMMENT '切片元数据',
  `embedding_model` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '预留：embedding 模型',
  `embedding_dim` int UNSIGNED NULL DEFAULT NULL COMMENT '预留：向量维度',
  `embedding_json` json NULL COMMENT '预留：小规模向量存储',
  `vector_store` varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '预留：外部向量库',
  `vector_point_id` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '预留：外部向量点ID',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1启用 2禁用',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT 'soft delete: 1 deleted, 2 normal',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'created time',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'updated time',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_ai_knowledge_chunks_kb_status_id`(`knowledge_base_id` ASC, `status` ASC, `is_del` ASC, `id` ASC) USING BTREE,
  INDEX `idx_ai_knowledge_chunks_doc_no`(`document_id` ASC, `chunk_no` ASC) USING BTREE,
  FULLTEXT INDEX `ft_ai_knowledge_chunks_content`(`content`)
) ENGINE = InnoDB AUTO_INCREMENT = 9 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI知识库切片' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_knowledge_documents
-- ----------------------------
DROP TABLE IF EXISTS `ai_knowledge_documents`;
CREATE TABLE `ai_knowledge_documents`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `knowledge_base_id` int UNSIGNED NOT NULL COMMENT 'ai_knowledge_bases.id',
  `title` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文档标题',
  `source_type` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT 'manual' COMMENT 'manual/text/file/url',
  `content` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '文档原文',
  `chunk_count` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '切片数量',
  `index_status` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '1已索引 2索引失败',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1启用 2禁用',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT 'soft delete: 1 deleted, 2 normal',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'created time',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'updated time',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_ai_knowledge_documents_kb_id`(`knowledge_base_id` ASC, `id` ASC) USING BTREE,
  INDEX `idx_ai_knowledge_documents_kb_status_id`(`knowledge_base_id` ASC, `status` ASC, `is_del` ASC, `id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 8 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI知识库文档' ROW_FORMAT = Dynamic;

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
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '1删除 2正常',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_ai_messages_conversation_del_id`(`conversation_id` ASC, `is_del` ASC, `id` ASC) USING BTREE,
  CONSTRAINT `fk_ai_messages_conversation` FOREIGN KEY (`conversation_id`) REFERENCES `ai_conversations` (`id`) ON DELETE CASCADE
) ENGINE = InnoDB CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI消息' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_models
-- ----------------------------
DROP TABLE IF EXISTS `ai_models`;
CREATE TABLE `ai_models`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '模型名称，如 gpt-4o / qwen2.5',
  `driver` varchar(30) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '驱动 openai/claude/qwen/wenxin...',
  `model_code` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '真实模型标识（API传参用）',
  `endpoint` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '自定义接口地址（可空）',
  `api_key_enc` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL COMMENT '加密后的 API Key（不要明文）',
  `api_key_hint` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT 'Key 提示（后4位/别名）',
  `modalities` json NULL COMMENT '支持的多模态能力 {\"image\":true,\"audio\":false,\"video\":false,\"file\":false}',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1启用 2禁用',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '2正常 1删除',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uniq_driver_name_del`(`driver` ASC, `name` ASC, `is_del` ASC) USING BTREE,
  INDEX `idx_model_code`(`model_code` ASC) USING BTREE,
  INDEX `idx_status_del`(`status` ASC, `is_del` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 68 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI 模型配置' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_prompt
-- ----------------------------
DROP TABLE IF EXISTS `ai_prompt`;
CREATE TABLE `ai_prompt`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int UNSIGNED NOT NULL COMMENT '用户ID',
  `title` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '标题',
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '提示词内容',
  `category` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '' COMMENT '分类',
  `tags` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '' COMMENT '标签，逗号分隔',
  `variables` json NULL COMMENT '变量定义 [{key,label,default}]',
  `is_favorite` tinyint(1) NOT NULL DEFAULT 2 COMMENT '是否收藏 1是 2否',
  `use_count` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '使用次数',
  `sort` int NOT NULL DEFAULT 0 COMMENT '排序，越大越前',
  `is_del` tinyint(1) NOT NULL DEFAULT 2 COMMENT '软删除 1是 2否',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_category`(`category` ASC) USING BTREE,
  INDEX `idx_is_favorite`(`is_favorite` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 6 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI提示词' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_prompts
-- ----------------------------
DROP TABLE IF EXISTS `ai_prompts`;
CREATE TABLE `ai_prompts`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int UNSIGNED NOT NULL COMMENT '用户ID',
  `title` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '标题',
  `content` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '提示词内容',
  `category` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '' COMMENT '分类',
  `tags` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '' COMMENT '标签，逗号分隔',
  `variables` json NULL COMMENT '变量定义 [{key,label,default}]',
  `is_favorite` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `use_count` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '使用次数',
  `sort` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '排序，越大越前',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_user_id`(`user_id` ASC) USING BTREE,
  INDEX `idx_category`(`category` ASC) USING BTREE,
  INDEX `idx_is_favorite`(`is_favorite` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 12 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI提示词' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_run_steps
-- ----------------------------
DROP TABLE IF EXISTS `ai_run_steps`;
CREATE TABLE `ai_run_steps`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `run_id` bigint UNSIGNED NOT NULL COMMENT '关联 ai_runs.id',
  `step_no` int UNSIGNED NOT NULL COMMENT '步骤序号，从1开始',
  `step_type` tinyint UNSIGNED NOT NULL COMMENT '1prompt 2rag 3llm 4tool_call 5tool_result 6finalize',
  `agent_id` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '执行该步骤的智能体ID',
  `model_snapshot` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT '' COMMENT '该步骤使用的模型代码',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1成功 2失败（注意：这里是step内部状态，不是系统启用禁用）',
  `error_msg` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '步骤错误',
  `latency_ms` int UNSIGNED NULL DEFAULT NULL COMMENT '步骤耗时ms',
  `payload_json` json NULL COMMENT '步骤数据（参数/片段/工具入参出参/引用）',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '2正常 1删除',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uniq_run_step`(`run_id` ASC, `step_no` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 4063 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI 运行步骤明细' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_runs
-- ----------------------------
DROP TABLE IF EXISTS `ai_runs`;
CREATE TABLE `ai_runs`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `request_id` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '幂等/追踪ID（建议UUID）',
  `user_id` int UNSIGNED NOT NULL COMMENT '用户ID',
  `agent_id` int UNSIGNED NOT NULL COMMENT '智能体ID',
  `conversation_id` int UNSIGNED NOT NULL COMMENT '会话ID',
  `user_message_id` bigint UNSIGNED NULL DEFAULT NULL COMMENT '本次用户消息ID（可空）',
  `assistant_message_id` bigint UNSIGNED NULL DEFAULT NULL COMMENT '本次AI消息ID（可空）',
  `run_status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1running 2success 3fail 4canceled',
  `error_msg` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '错误信息（简短）',
  `prompt_tokens` int UNSIGNED NULL DEFAULT NULL,
  `completion_tokens` int UNSIGNED NULL DEFAULT NULL,
  `total_tokens` int UNSIGNED NULL DEFAULT NULL,
  `cost` decimal(12, 6) NULL DEFAULT NULL,
  `latency_ms` int UNSIGNED NULL DEFAULT NULL COMMENT '总耗时ms',
  `model_snapshot` varchar(80) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '实际模型',
  `meta_json` json NULL COMMENT '扩展：参数快照、客户端信息等',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '2正常 1删除',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uniq_request_id`(`request_id` ASC) USING BTREE,
  INDEX `idx_user_created`(`user_id` ASC, `created_at` ASC) USING BTREE,
  INDEX `idx_del_agent_created`(`is_del` ASC, `agent_id` ASC, `created_at` ASC) USING BTREE,
  INDEX `idx_del_status_id`(`is_del` ASC, `run_status` ASC, `id` ASC) USING BTREE,
  INDEX `idx_conv_status_del_id`(`conversation_id` ASC, `run_status` ASC, `is_del` ASC, `id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 612 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI 运行记录（一次send）' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for ai_tools
-- ----------------------------
DROP TABLE IF EXISTS `ai_tools`;
CREATE TABLE `ai_tools`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '工具名称',
  `code` varchar(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '工具唯一编码，如 search_user',
  `description` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '描述',
  `schema_json` json NULL COMMENT '参数JSON Schema',
  `executor_type` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1internal 2http_whitelist 3sql_readonly',
  `executor_config` json NULL COMMENT '执行器配置（白名单域名/SQL限制等）',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1启用 2禁用',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '2正常 1删除',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uniq_code`(`code` ASC) USING BTREE,
  INDEX `idx_del_status_id`(`is_del` ASC, `status` ASC, `id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 14 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'AI 工具定义' ROW_FORMAT = Dynamic;

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
) ENGINE = InnoDB AUTO_INCREMENT = 13 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '定时任务配置表' ROW_FORMAT = Dynamic;

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
) ENGINE = InnoDB AUTO_INCREMENT = 49202 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '定时任务执行日志表' ROW_FORMAT = Dynamic;

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
) ENGINE = InnoDB AUTO_INCREMENT = 101696 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '操作日志表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for order_fulfillments
-- ----------------------------
DROP TABLE IF EXISTS `order_fulfillments`;
CREATE TABLE `order_fulfillments`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `fulfill_no` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '履约单号',
  `order_id` bigint UNSIGNED NOT NULL COMMENT '订单ID',
  `order_no` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '订单号',
  `user_id` int UNSIGNED NOT NULL COMMENT '用户ID',
  `biz_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '业务类型',
  `biz_id` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '业务实体ID',
  `action_type` tinyint UNSIGNED NOT NULL COMMENT '1充值入账 2消费履约 3商品回调',
  `source_txn_id` bigint UNSIGNED NOT NULL DEFAULT 0 COMMENT '来源支付流水ID',
  `idempotency_key` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '业务幂等键',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1待执行 2执行中 3成功 4失败 5人工处理',
  `retry_count` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '重试次数',
  `next_retry_at` datetime NULL DEFAULT NULL COMMENT '下次重试时间',
  `executed_at` datetime NULL DEFAULT NULL COMMENT '执行成功时间',
  `last_error` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '最后错误',
  `request_payload` json NULL COMMENT '请求快照',
  `result_payload` json NULL COMMENT '结果快照',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_fulfill_no`(`fulfill_no` ASC) USING BTREE,
  UNIQUE INDEX `uk_idempotency_key`(`idempotency_key` ASC) USING BTREE,
  INDEX `idx_order_action`(`order_id` ASC, `action_type` ASC) USING BTREE,
  INDEX `idx_status_retry`(`status` ASC, `next_retry_at` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 2 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '支付后业务履约记录' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for order_items
-- ----------------------------
DROP TABLE IF EXISTS `order_items`;
CREATE TABLE `order_items`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_id` bigint UNSIGNED NOT NULL COMMENT '订单ID',
  `item_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '项目类型',
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '标题快照',
  `price` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '单价(分)',
  `quantity` int UNSIGNED NOT NULL DEFAULT 1 COMMENT '数量',
  `amount` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '小计(分)',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_order_id`(`order_id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 4 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '订单明细' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for orders
-- ----------------------------
DROP TABLE IF EXISTS `orders`;
CREATE TABLE `orders`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `order_no` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '订单号',
  `user_id` int UNSIGNED NOT NULL COMMENT '用户ID',
  `order_type` tinyint UNSIGNED NOT NULL COMMENT '1=充值 2=消费 3=商品',
  `biz_type` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '业务类型',
  `biz_id` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '业务实体ID',
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '订单标题',
  `item_count` int UNSIGNED NOT NULL DEFAULT 1 COMMENT '件数',
  `total_amount` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '订单总额(分)',
  `discount_amount` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '优惠金额(分)',
  `pay_amount` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '应付金额(分)',
  `pay_status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1待支付 2支付中 3已支付 4已关闭 5支付异常',
  `biz_status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1初始化 2待履约 3履约中 4履约成功 5履约失败 6人工处理',
  `success_transaction_id` bigint UNSIGNED NOT NULL DEFAULT 0 COMMENT '成功支付流水ID',
  `channel_id` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '成功支付渠道ID',
  `pay_method` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '支付方式',
  `pay_time` datetime NULL DEFAULT NULL COMMENT '支付成功时间',
  `expire_time` datetime NOT NULL COMMENT '支付过期时间',
  `close_time` datetime NULL DEFAULT NULL COMMENT '关闭时间',
  `biz_done_at` datetime NULL DEFAULT NULL COMMENT '业务履约成功时间',
  `close_reason` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '关闭原因',
  `fail_reason` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '失败原因',
  `extra` json NULL COMMENT '扩展字段',
  `admin_remark` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '管理员备注',
  `ip` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '下单IP',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_order_no`(`order_no` ASC) USING BTREE,
  INDEX `idx_user_pay_created`(`user_id` ASC, `pay_status` ASC, `created_at` ASC) USING BTREE,
  INDEX `idx_biz`(`biz_type` ASC, `biz_id` ASC) USING BTREE,
  INDEX `idx_expire`(`pay_status` ASC, `expire_time` ASC) USING BTREE,
  INDEX `idx_txn`(`success_transaction_id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 4 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '统一订单表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for pay_channel
-- ----------------------------
DROP TABLE IF EXISTS `pay_channel`;
CREATE TABLE `pay_channel`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '渠道名称',
  `channel` tinyint UNSIGNED NOT NULL COMMENT '1=微信 2=支付宝',
  `mch_id` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '商户号',
  `app_id` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '应用ID',
  `notify_url` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '异步回调地址',
  `app_private_key_enc` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL COMMENT '应用私钥密文',
  `app_private_key_hint` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '私钥提示',
  `public_cert_path` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '公钥证书路径',
  `platform_cert_path` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '平台证书路径',
  `root_cert_path` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '根证书路径',
  `extra_config` json NULL COMMENT '扩展配置',
  `is_sandbox` tinyint UNSIGNED NOT NULL DEFAULT 2 COMMENT '1=是 2=否',
  `sort` int UNSIGNED NOT NULL DEFAULT 0,
  `remark` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1=启用 2=禁用',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_channel_mch_app`(`channel` ASC, `mch_id` ASC, `app_id` ASC) USING BTREE,
  INDEX `idx_channel_status_sort`(`channel` ASC, `status` ASC, `sort` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 2 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '支付渠道配置' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for pay_notify_logs
-- ----------------------------
DROP TABLE IF EXISTS `pay_notify_logs`;
CREATE TABLE `pay_notify_logs`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `channel` tinyint UNSIGNED NOT NULL COMMENT '1=微信 2=支付宝',
  `notify_type` tinyint UNSIGNED NOT NULL COMMENT '1=支付回调',
  `transaction_no` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '系统支付流水号',
  `trade_no` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '第三方交易号',
  `headers` json NULL COMMENT '回调请求头',
  `raw_data` json NOT NULL COMMENT '原始回调内容',
  `process_status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1待处理 2成功 3失败 4忽略',
  `process_msg` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '处理结果',
  `ip` varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '回调来源IP',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  INDEX `idx_txn_no`(`transaction_no` ASC) USING BTREE,
  INDEX `idx_created`(`created_at` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '支付回调日志' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for pay_reconcile_tasks
-- ----------------------------
DROP TABLE IF EXISTS `pay_reconcile_tasks`;
CREATE TABLE `pay_reconcile_tasks`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `reconcile_date` date NOT NULL COMMENT '对账日期',
  `channel` tinyint UNSIGNED NOT NULL COMMENT '1=微信 2=支付宝',
  `channel_id` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '渠道ID',
  `bill_type` tinyint UNSIGNED NOT NULL COMMENT '1支付',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1待执行 2下载中 3对比中 4成功 5有差异 6失败',
  `platform_count` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '平台笔数',
  `platform_amount` bigint UNSIGNED NOT NULL DEFAULT 0 COMMENT '平台金额(分)',
  `local_count` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '本地笔数',
  `local_amount` bigint UNSIGNED NOT NULL DEFAULT 0 COMMENT '本地金额(分)',
  `diff_count` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '差异笔数',
  `diff_amount` bigint NOT NULL DEFAULT 0 COMMENT '差异金额(分)',
  `platform_file_url` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '平台账单文件URL',
  `local_file_url` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '本地账单文件URL',
  `diff_file_url` varchar(512) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '差异文件URL',
  `started_at` datetime NULL DEFAULT NULL COMMENT '开始时间',
  `finished_at` datetime NULL DEFAULT NULL COMMENT '结束时间',
  `error_msg` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '失败信息',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_reconcile_unique`(`reconcile_date` ASC, `channel` ASC, `channel_id` ASC, `bill_type` ASC) USING BTREE,
  INDEX `idx_status_date`(`status` ASC, `reconcile_date` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 5 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '支付对账任务' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for pay_refunds
-- ----------------------------
DROP TABLE IF EXISTS `pay_refunds`;
CREATE TABLE `pay_refunds`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `refund_no` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '退款单号',
  `order_id` bigint UNSIGNED NOT NULL COMMENT '订单ID',
  `order_no` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '订单号',
  `user_id` int UNSIGNED NOT NULL COMMENT '用户ID（冗余，用于钱包操作）',
  `transaction_id` bigint UNSIGNED NOT NULL COMMENT '原支付流水ID',
  `channel_id` int UNSIGNED NOT NULL COMMENT '渠道ID',
  `channel` tinyint UNSIGNED NOT NULL COMMENT '1=微信 2=支付宝',
  `refund_amount` int UNSIGNED NOT NULL COMMENT '退款金额(分)',
  `wallet_freeze_amount` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '钱包冻结金额(分)',
  `trade_refund_no` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '第三方退款单号',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1已创建 2退款中 3成功 4失败 5已关闭 6人工处理',
  `reason` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '退款原因',
  `fail_reason` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '失败原因',
  `operator_id` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '操作人',
  `frozen_at` datetime NULL DEFAULT NULL COMMENT '冻结成功时间',
  `refunded_at` datetime NULL DEFAULT NULL COMMENT '退款成功时间',
  `raw_request` json NULL COMMENT '退款请求快照',
  `raw_notify` json NULL COMMENT '退款回调快照',
  `remark` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_refund_no`(`refund_no` ASC) USING BTREE,
  INDEX `idx_order_id`(`order_id` ASC) USING BTREE,
  INDEX `idx_status_created`(`status` ASC, `created_at` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 1 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '退款记录' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for pay_transactions
-- ----------------------------
DROP TABLE IF EXISTS `pay_transactions`;
CREATE TABLE `pay_transactions`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `transaction_no` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '系统支付流水号',
  `order_id` bigint UNSIGNED NOT NULL COMMENT '订单ID',
  `order_no` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '订单号',
  `attempt_no` int UNSIGNED NOT NULL DEFAULT 1 COMMENT '第几次支付尝试',
  `channel_id` int UNSIGNED NOT NULL COMMENT '渠道ID',
  `channel` tinyint UNSIGNED NOT NULL COMMENT '1=微信 2=支付宝',
  `pay_method` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '支付方式',
  `amount` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '支付金额(分)',
  `trade_no` varchar(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '第三方交易号',
  `trade_status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '第三方原始状态',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1 COMMENT '1已创建 2等待支付 3成功 4失败 5关闭',
  `paid_at` datetime NULL DEFAULT NULL COMMENT '支付成功时间',
  `closed_at` datetime NULL DEFAULT NULL COMMENT '关闭时间',
  `channel_resp` json NULL COMMENT '第三方下单原始响应',
  `raw_notify` json NULL COMMENT '原始回调数据',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_transaction_no`(`transaction_no` ASC) USING BTREE,
  UNIQUE INDEX `uk_order_attempt`(`order_id` ASC, `attempt_no` ASC) USING BTREE,
  INDEX `idx_order_id`(`order_id` ASC) USING BTREE,
  INDEX `idx_trade_no`(`trade_no` ASC) USING BTREE,
  INDEX `idx_status_created`(`status` ASC, `created_at` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 4 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '支付流水' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for permission_backup_20260306_cleanup
-- ----------------------------
DROP TABLE IF EXISTS `permission_backup_20260306_cleanup`;
CREATE TABLE `permission_backup_20260306_cleanup`  (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(50) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NOT NULL DEFAULT '' COMMENT '权限名',
  `path` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NULL DEFAULT '' COMMENT '路由',
  `icon` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NULL DEFAULT '' COMMENT '图标',
  `parent_id` int NOT NULL DEFAULT -1 COMMENT '父级ID',
  `component` varchar(255) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NULL DEFAULT NULL COMMENT '组件路径',
  `platform` varchar(10) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NOT NULL DEFAULT 'admin' COMMENT '平台：admin=PC后台, app=H5/APP',
  `type` tinyint(1) NOT NULL DEFAULT 1 COMMENT '类型：1=目录, 2=页面, 3=按钮',
  `sort` int NOT NULL DEFAULT 1 COMMENT '排序',
  `code` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NULL DEFAULT NULL COMMENT '权限标识',
  `i18n_key` varchar(128) CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NOT NULL DEFAULT '' COMMENT 'i18n键',
  `keep_alive` tinyint(1) NOT NULL DEFAULT 0 COMMENT 'keep-alive',
  `show_menu` tinyint(1) NOT NULL DEFAULT 1 COMMENT '显示菜单：1=显示, 2=隐藏',
  `status` tinyint(1) NOT NULL DEFAULT 1 COMMENT '状态',
  `is_del` tinyint(1) NOT NULL DEFAULT 2 COMMENT '删除标记',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uniq_platform_code`(`platform` ASC, `code` ASC) USING BTREE,
  INDEX `idx_platform`(`platform` ASC) USING BTREE,
  INDEX `idx_parent_sort`(`parent_id` ASC, `sort` ASC) USING BTREE,
  INDEX `idx_status_del`(`is_del` ASC, `status` ASC, `platform` ASC, `type` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 96 CHARACTER SET = utf8mb3 COLLATE = utf8mb3_general_ci COMMENT = '菜单权限表' ROW_FORMAT = Dynamic;

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
) ENGINE = InnoDB AUTO_INCREMENT = 371 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '菜单权限表' ROW_FORMAT = Dynamic;

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
) ENGINE = InnoDB AUTO_INCREMENT = 525 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = 'role permission pivot' ROW_FORMAT = Dynamic;

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
) ENGINE = InnoDB AUTO_INCREMENT = 14 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '系统设置（key-value）' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for test
-- ----------------------------
DROP TABLE IF EXISTS `test`;
CREATE TABLE `test`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `title` varchar(200) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '标题',
  `username` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '用户名',
  `nickname` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '昵称',
  `email` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '邮箱',
  `phone` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '手机号',
  `password` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '密码',
  `avatar` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '头像',
  `cover_image` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '封面图',
  `status` tinyint UNSIGNED NOT NULL DEFAULT 1,
  `type` tinyint UNSIGNED NULL DEFAULT NULL,
  `sex` tinyint UNSIGNED NOT NULL DEFAULT 0,
  `age` int NULL DEFAULT NULL COMMENT '年龄',
  `score` decimal(10, 2) NULL DEFAULT NULL COMMENT '分数',
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL COMMENT '描述',
  `content` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL COMMENT '内容',
  `remark` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '备注',
  `url` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NULL DEFAULT NULL COMMENT '网址',
  `published_at` datetime NULL DEFAULT NULL COMMENT '发布时间',
  `birthday` date NULL DEFAULT NULL COMMENT '生日',
  `is_vip` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `is_hot` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 3 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '测试表' ROW_FORMAT = Dynamic;

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
) ENGINE = InnoDB AUTO_INCREMENT = 17 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

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
) ENGINE = InnoDB AUTO_INCREMENT = 17 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci ROW_FORMAT = Dynamic;

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
) ENGINE = InnoDB AUTO_INCREMENT = 19 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '上传设置：驱动+规则组合与启用状态' ROW_FORMAT = Dynamic;

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
) ENGINE = InnoDB AUTO_INCREMENT = 751 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '用户会话表' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for user_wallets
-- ----------------------------
DROP TABLE IF EXISTS `user_wallets`;
CREATE TABLE `user_wallets`  (
  `id` int UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` int UNSIGNED NOT NULL COMMENT '用户ID',
  `balance` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '可用余额(分)',
  `frozen` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '冻结余额(分)',
  `total_recharge` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '累计充值(分)',
  `total_consume` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '累计消费(分)',
  `version` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '乐观锁版本号',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_user_id`(`user_id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 2 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '用户钱包' ROW_FORMAT = Dynamic;

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
) ENGINE = InnoDB AUTO_INCREMENT = 778 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '登录日志' ROW_FORMAT = Dynamic;

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
) ENGINE = InnoDB AUTO_INCREMENT = 25 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '用户快捷入口' ROW_FORMAT = Dynamic;

-- ----------------------------
-- Table structure for wallet_transactions
-- ----------------------------
DROP TABLE IF EXISTS `wallet_transactions`;
CREATE TABLE `wallet_transactions`  (
  `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT,
  `biz_action_no` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '业务幂等键',
  `user_id` int UNSIGNED NOT NULL COMMENT '用户ID',
  `wallet_id` int UNSIGNED NOT NULL COMMENT '钱包ID',
  `type` tinyint UNSIGNED NOT NULL COMMENT '1充值入账 2消费扣款 3系统调账',
  `available_delta` int NOT NULL DEFAULT 0 COMMENT '可用余额变化',
  `frozen_delta` int NOT NULL DEFAULT 0 COMMENT '冻结余额变化',
  `balance_before` int UNSIGNED NOT NULL COMMENT '变动前可用余额',
  `balance_after` int UNSIGNED NOT NULL COMMENT '变动后可用余额',
  `frozen_before` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '变动前冻结余额',
  `frozen_after` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '变动后冻结余额',
  `order_id` bigint UNSIGNED NOT NULL DEFAULT 0 COMMENT '关联订单ID',
  `order_no` varchar(32) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '' COMMENT '关联订单号',
  `source_type` tinyint UNSIGNED NOT NULL DEFAULT 0 COMMENT '0未关联 1履约 2人工',
  `source_id` bigint UNSIGNED NOT NULL DEFAULT 0 COMMENT '来源记录ID',
  `title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL COMMENT '流水标题',
  `remark` varchar(500) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL DEFAULT '',
  `operator_id` int UNSIGNED NOT NULL DEFAULT 0 COMMENT '操作人',
  `ext` json NULL COMMENT '扩展信息',
  `is_del` tinyint UNSIGNED NOT NULL DEFAULT 2,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE INDEX `uk_biz_action_no`(`biz_action_no` ASC) USING BTREE,
  INDEX `idx_user_created`(`user_id` ASC, `created_at` ASC) USING BTREE,
  INDEX `idx_order_id`(`order_id` ASC) USING BTREE,
  INDEX `idx_source`(`source_type` ASC, `source_id` ASC) USING BTREE
) ENGINE = InnoDB AUTO_INCREMENT = 42 CHARACTER SET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '钱包流水' ROW_FORMAT = Dynamic;

SET FOREIGN_KEY_CHECKS = 1;

