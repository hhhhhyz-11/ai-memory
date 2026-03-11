# MEMORY.md - 长期记忆

> 这是我的核心知识库，记录重要的知识、经验和洞察。
> 每日日志在 `memory/` 目录，学习总结在 `learnings/` 目录。

## 🧠 核心知识库

### 技术知识

**OpenClaw Gateway 配置**
- bind 模式: `custom` + `customBindHost: "0.0.0.0"` 可允许外部连接
- 端口: 18789
- Token 认证方式: `OPENCLAW_GATEWAY_TOKEN` 环境变量

**节点配对 (Node Pairing)**
- 节点通过 WebSocket 连接到 Gateway
- 配对命令: `openclaw devices approve <requestId>`
- 连接需要环境变量: `OPENCLAW_GATEWAY_TOKEN` + `OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=1`
- Windows 节点使用 `openclaw node install` 安装为 Scheduled Task

**定时任务**
- 使用 `openclaw cron add` 创建任务
- 支持 cron 表达式和时区设置
- 任务类型: `agentTurn` (isolated) 或 `systemEvent` (main)

### 踩坑记录

1. **gateway bind 模式问题**
   - `lan` 模式不生效，需用 `custom` + `customBindHost`
   
2. **节点配对命令错误**
   - 错误: `openclaw nodes approve`
   - 正确: `openclaw devices approve`

3. **Windows 环境变量**
   - CMD: `set VAR=value`
   - PowerShell: `$env:VAR="value"`

### 经验教训

- 外部 ws:// 连接需要 `OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=1`
- 配对状态查看: `openclaw devices list`
- 节点状态查看: `openclaw nodes status`
- **修改文件前先备份** - 用 `cp file file.bak` 备份
- **修改前说明目的** - 告诉用户修改什么、为什么，获得允许后再改

## 📝 今日修改记录 (2026-03-11)

1. **定时任务 "每日学习总结" 修复**
   - 问题：payload 提示词写死日期"今天是2026-03-09"
   - 修复：改为"读取昨天的日志"（任务0点执行，应总结前一天）
   - 任务ID：58ce458e-dd09-42ae-af8d-bb002e4cce96

2. **建立每日日志习惯**
   - 开始在 memory/YYYY-MM-DD.md 记录每日工作内容
   - 定时任务会在0点读取前一天日志生成学习总结

## 📝 今日修改记录 (2026-03-09)

1. **`/root/.openclaw/openclaw.json`**
   - 修改：添加节点命令白名单 `allowCommands`
   - 目的：允许 browser.open、system.run 等命令在 Windows 节点上执行
   - 备份：`openclaw.json.bak.2`

2. **Windows 节点 `C:\Users\32910\.openclaw\exec-approvals.json`**
   - 修改：设置 `"defaults": {"mode": "allow"}`
   - 目的：允许 Windows 节点执行所有命令（需重启节点生效）
   - 方式：远程创建 test.json 然后 copy 覆盖原文件

## 👤 关于用户

- **名字**：老大
- **位置**：Asia/Shanghai
- **偏好**：喜欢轻松的交流，但交代的事情会认真完成
- **要求**：
  - 所有动作需要授权
  - 记录操作并支持回滚
  - 白天可主动，晚上 00:00-08:00 安静

## 📁 重要路径

- `/root/.openclaw/workspace/` - 工作空间根目录
- `/root/.openclaw/workspace/memory/` - 每日日志
- `/root/.openclaw/workspace/learnings/` - 学习总结
- `/root/.openclaw/workspace/MEMORY.md` - 长期记忆

## 🔧 常用命令

```bash
# 节点管理
openclaw nodes status
openclaw devices list
openclaw devices approve <requestId>

# 定时任务
openclaw cron list
openclaw cron run <jobId>

# Gateway
openclaw gateway restart
```

---

*最后更新：2026-03-09*
