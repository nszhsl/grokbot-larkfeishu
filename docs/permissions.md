# IM 权限清单（飞书应用机器人）

面向本脚手架使用的官方 MCP 工具：`im.v1.message.create`、`im.v1.message.list`、`im.v1.chat.list`。

权限须在[飞书开放平台](https://open.feishu.cn/app) → 应用 → **权限管理** 开通，并经**版本发布**后才会对企业生效。仅「开通」未「发布」会导致线上 230027 / 权限类错误。

## 必备能力

| 项 | 说明 |
|----|------|
| 机器人能力 | 应用需开启**机器人**；否则无法代发 / 拉消息 / 列群 |
| 可用范围 | 目标用户须在应用可用范围内 |
| 入群 | 机器人须已加入目标群，且群内允许机器人发言 |

## 推荐权限（应用身份 / tenant_access_token）

以下为「至少开通其一」的官方语义；脚手架建议直接勾选**较完整**的组合，减少调试往返。

### 发送消息 — `im.v1.message.create`

| 权限标识（常见） | 中文名（界面可能略有差异） | 用途 |
|------------------|----------------------------|------|
| `im:message` | 获取与发送单聊、群组消息 | 读写一体，代发够用 |
| `im:message:send_as_bot` | 以应用的身份发消息 | 明确「机器人身份发送」（若控制台有此项） |

官方文档：[发送消息](https://open.feishu.cn/document/server-docs/im-v1/message/create)

### 获取会话历史 — `im.v1.message.list`

| 场景 | 需要开通（满足文档「任一」规则） |
|------|----------------------------------|
| 单聊历史 | `im:message` **或** `im:message:readonly` **或** `im:message.history:readonly` |
| 群聊历史 | 在上列任一基础上，**额外**需要 `im:message.group_msg`（读取用户在群中的所有消息） |

官方文档：[获取会话历史消息](https://open.feishu.cn/document/server-docs/im-v1/message/list)

> 群聊轮询是本模板主路径：务必确认 `im:message.group_msg`（或控制台等价文案）已开通并发布。

### 列出机器人所在群 — `im.v1.chat.list`

开通以下**任一**：

| 权限标识（常见） | 说明 |
|------------------|------|
| `im:chat` | 获取与更新群组信息 |
| `im:chat:readonly` | 获取群组信息 |
| `im:chat:read` | 查看群信息 |
| `im:chat.group_info:readonly` | 读取群信息（旧版） |

官方文档：[获取用户或机器人所在的群列表](https://open.feishu.cn/document/server-docs/group/chat/list)

**注意**：该接口返回的列表**不包含单聊（p2p）**。单聊需自行记录 `chat_id`（例如首次代发成功后从回包 / 业务侧保存）。

## 最小勾选建议（机器人 + 群轮询 + 代发）

一次性建议开通并发布：

1. **机器人能力**
2. `im:message`（或分别具备发送 + 读历史能力）
3. `im:message.group_msg`（群历史）
4. `im:chat:readonly`（或 `im:chat`）

若控制台显示的是中文权限名而非标识，以开放平台权限搜索「消息」「群组」为准，对照上表。

## 用户身份（可选，本模板默认不用）

若 MCP 启用 OAuth / `user_access_token`，拉单聊 / 群聊历史还可能需要：

- `im:message.p2p_msg:get_as_user`
- `im:message.group_msg:get_as_user`

本脚手架默认 **应用身份（机器人）**，配置里不必开 `--oauth`，除非你明确要以用户身份操作。

## 发布与验收

1. 权限变更 → **创建版本 → 申请发布 → 管理员通过**（视企业流程）。
2. 用 MCP 试调：
   - `im.v1.chat.list` 能看到目标群
   - `im.v1.message.create` 能发到该群
   - `im.v1.message.list`（`container_id_type=chat`）能拉到该群消息
3. 常见失败：
   - 机器人不在群 / 无发言权
   - 权限未发布
   - 目标用户不在可用范围（单聊）
   - 把 Secret 配错或仍用旧版本凭证

## 安全

- App Secret、token **禁止**写入 git。
- 权限遵循最小必要；不要为「顺便」开通通讯录写权限等无关 scope。
- 对外自动回复内容需有人工可审计的策略（见 `docs/polling.md`）。
