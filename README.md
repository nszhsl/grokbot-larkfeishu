# grokbot-larkfeishu

Grok Bot ↔ 飞书（Lark）：用官方 MCP `@larksuiteoapi/lark-mcp` 做**代发消息**，并用**定时轮询**近似入站回复。

> **重要限制**：这不是实时推送 / Webhook / Event Subscription。飞书侧新人消息不会立刻叫醒 Grok Bot；入站依赖 Routine 按分钟级周期调用 `im.v1.message.list`。延迟等于轮询间隔（建议 10–15 分钟）。

## 架构

```text
┌─────────────────┐     用户口头指令      ┌──────────────────┐
│  你 / 业务方     │ ───────────────────▶ │     Grok Bot      │
└─────────────────┘                       └────────┬─────────┘
                                                   │ MCP tools
                                                   ▼
                                          ┌──────────────────┐
                                          │  lark-mcp        │
                                          │  (官方 OpenAPI)  │
                                          └────────┬─────────┘
                                                   │
                         ┌─────────────────────────┼─────────────────────────┐
                         ▼                         ▼                         ▼
               im.v1.message.create      im.v1.message.list         im.v1.chat.list
               （代发 / 回复）            （拉历史做入站近似）       （发现可监控会话）
```

| 方向 | 机制 | 官方工具 |
|------|------|----------|
| **出站（代发）** | 用户让 Grok Bot 发飞书消息 | `im.v1.message.create` |
| **入站（近似）** | Routine 定时拉消息 → 决策 → 回贴 | `im.v1.message.list` + `im.v1.message.create` |
| **发现会话** | 列出机器人所在群（不含单聊） | `im.v1.chat.list` |

Skills 与 Routine 只描述**意图与流程**，不冻结 MCP 入参 JSON Schema（官方工具字段可能随版本变化）。

## 仓库结构

```text
README.md
.gitignore
.env.example
config/mcp.example.json          # MCP 安装示例（语言 zh）
docs/permissions.md              # IM 权限清单
docs/polling.md                  # 水位线 / 监控会话 / 回复策略 / 节奏
skills/feishu-send/SKILL.md      # 代发 Skill
skills/feishu-poll-reply/SKILL.md# 轮询回复 Skill
routines/feishu-poll-reply.md    # 可粘贴 Routine + cron 建议
state/watermarks.example.json    # 水位线文件形状示例
scripts/check-scaffold.sh        # 可选：检查文件齐全与示例 JSON
```

本地检查：`./scripts/check-scaffold.sh`

## 前置条件

1. Node.js ≥ 18（`npx` 可跑 `@larksuiteoapi/lark-mcp`）
2. [飞书开放平台](https://open.feishu.cn/) 企业自建应用
3. Grok Bot（或其它支持 MCP + Skills + Routines 的宿主）

## 飞书应用与机器人配置

1. 创建**企业自建应用**，记下 `App ID` / `App Secret`（只放环境变量，勿提交仓库）。
2. **添加能力 → 机器人**，开启机器人能力。
3. 按 [docs/permissions.md](docs/permissions.md) 开通并**发布版本**（权限未发布不生效）。
4. 配置应用**可用范围**（要能触达目标用户 / 部门）。
5. 把机器人拉进需要代发或轮询的群；群内需有发言权限。
6. API 域名：
   - 飞书国内：`https://open.feishu.cn`（默认）
   - Lark 国际：`https://open.larksuite.com`（MCP 加 `-d`）

## 环境变量（无真实密钥）

复制 `.env.example` 为本地 `.env`（已被 gitignore）：

| 变量 | 含义 |
|------|------|
| `APP_ID` | 飞书应用 App ID，如 `cli_xxxx` |
| `APP_SECRET` | 飞书应用 App Secret |
| `LARK_DOMAIN` | 可选，默认 `https://open.feishu.cn` |
| `LARK_TOOLS` | 可选，覆盖启用的工具列表 |

## 安装 MCP（示例）

将 [config/mcp.example.json](config/mcp.example.json) 合并进宿主的 MCP 配置（Cursor / Grok Bot 等常见为 `mcp.json`）。

最小工具集（本脚手架所需）：

```text
im.v1.message.create,im.v1.message.list,im.v1.chat.list
```

语言：`-l zh`（工具描述中文）。

推荐用环境变量注入凭证，避免把 Secret 写进配置文件正文：

```bash
export APP_ID=cli_xxxx
export APP_SECRET=your_secret_here
# 可选：export LARK_DOMAIN=https://open.feishu.cn
```

验证：在宿主中确认能看到 `im_v1_message_create` / `im_v1_message_list` / `im_v1_chat_list`（snake 命名；具体以当前 lark-mcp 为准）。

上游文档：

- npm：[`@larksuiteoapi/lark-mcp`](https://www.npmjs.com/package/@larksuiteoapi/lark-mcp)
- GitHub：[larksuite/lark-openapi-mcp](https://github.com/larksuite/lark-openapi-mcp)

## 出站：代发流程

1. 用户给出：**接收方**（`chat_id` / `open_id` 等）+ **内容** +（可选）消息类型。
2. 加载 Skill [`skills/feishu-send`](skills/feishu-send/SKILL.md)。
3. 若只有群名、没有 ID：先用 `im.v1.chat.list` 解析（注意：该接口**不返回单聊 p2p**）。
4. 调用 `im.v1.message.create`：
   - `receive_id_type`：`chat_id` | `open_id` | …
   - `msg_type`：常用 `text`
   - `content`：JSON **序列化后的字符串**，例如文本 `{"text":"你好"}`
5. 向用户回报 `message_id` / 失败原因；**不要**在日志或回复里打印 App Secret。

## 入站近似：轮询回复流程

1. 配置监控会话列表与回复策略：见 [docs/polling.md](docs/polling.md)。
2. 复制 [routines/feishu-poll-reply.md](routines/feishu-poll-reply.md) 到 Grok Bot Routine；cron 建议**工作日白天每 10–15 分钟**（`Asia/Shanghai`）。Grok Bot Routine 最小间隔约 **5 分钟**，勿设更密。
3. 每次 tick：
   - 读水位线（每会话上次处理的 `message_id` / `create_time`）
   - `im.v1.message.list` 拉新消息
   - 过滤：跳过机器人自己、已处理、非策略目标
   - 生成回复 → `im.v1.message.create` 发回同一 `chat_id`
   - 推进水位线并持久化（本地 `state/watermarks.json`，勿提交）
4. 细节与边界：Skill [`skills/feishu-poll-reply`](skills/feishu-poll-reply/SKILL.md)。

## 明确不做的事

- 不实现自研飞书 HTTP 客户端（除非极小辅助脚本；默认全走 lark-mcp）。
- 不在仓库提交 App Secret、token、真实 `chat_id` 水位线。
- 不假装支持事件订阅实时入站；需要实时请另接飞书事件订阅 + 自有服务，本模板不覆盖。

## 快速验收清单

- [ ] MCP 能列出三个 IM 工具
- [ ] 机器人在目标群内且有发言权
- [ ] 手动代发一条文本成功
- [ ] `message.list` 能拉到该群历史
- [ ] Routine 跑一轮：水位线前进且不重复回复

## 许可与责任

本仓库为脚手架模板。调用飞书 API 须遵守企业合规与飞书开放平台条款；对外发送内容由操作者负责。
