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
- **⚠️ payload 提示词不能写死日期**，要用动态描述如"读取昨天的日志"

**SonarQube + GitLab CI**
- 扫描 Java 项目需要 `sonar.java.binaries` 指定编译产物目录
- Maven 编译和 Sonar 分析建议在同一 job 执行，避免分 stage 丢失 .class 文件
- 常用参数：`-T 2C` 并行编译、`-Dmaven.test.skip=true`、`-Dsonar.exclusions`

**SonarQube Issues 批量导出**
- 页面 PDF 导出有 10000 条限制
- 方案：导出 Protobuf 格式 → Java 工具转 CSV
- 工具：SonarPbToCsvConverter + commons-csv

**AI 短剧制作工具链**
- Leonardo.ai：AI 图片生成
- 快手可灵：图生视频
- Azure TTS：文字转语音配音
- CapCut：视频剪辑

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
- Jenkins workspace 被强制中止可能导致名称变成 `@2` 后缀
- GitLab 老版本(11.x)使用传统 CI 语法，不支持 modern rules
- **SonarQube 增量扫描** 用 `-Dsonar.newCode.referenceBranch=uat` 对比分支
- **GitLab 保护分支门禁** 需要先在 SonarQube 设置质量门禁

## 📝 今日修改记录 (2026-03-13)

1. **SonarQube 增量扫描配置**
   - 参数：`-Dsonar.newCode.referenceBranch=uat` 增量对比
   - 参数：`-Dsonar.pullrequest.key` PR 模式
   - 适用：feature 分支对比 uat 分支增量扫描

2. **AI 短剧制作工具链推荐**
   - Leonardo.ai（图片生成）
   - 快手可灵（图生视频）
   - Azure TTS（配音）
   - CapCut（剪辑）
   - 提供完整分镜脚本和提示词

3. **GitLab CI + SonarQube 门禁配置**
   - master/uat/release 分支设置保护
   - GitLab 设置 "Require status checks before merging"
   - SonarQube 质量门禁自动继承分支关系

4. **建立每日学习总结机制**
   - 定时任务 0 点执行，读取前一天日志
   - 生成 learnings/YYYY-MM-DD.md
   - 更新 MEMORY.md 长期记忆

## 📝 今日修改记录 (2026-03-12)

1. **OpenClaw Node 节点问题排查**
   - 问题：H 节点掉线
   - 原因：Windows 环境变量 `OPENCLAW_GATEWAY_TOKEN` 未设置
   - 解决：设置 token 后节点恢复正常

2. **SonarQube + GitLab CI 增量扫描配置**
   - 需求：MR 合并到 uat 时触发增量代码扫描
   - 参数：`-Dsonar.newCode.referenceBranch=uat` 进行增量对比
   - 限制：GitLab 11.1.4 不支持 modern CI 语法，用 shell 脚本判断

3. **Jenkins workspace 问题**
   - 问题：rsync 找不到 dist 目录
   - 原因：workspace 名称变成 `uav-defence-web@2`（之前构建被强制中止）
   - 解决：修改 yml 配置使用正确的 workspace 路径

4. **技术博客汇总**
   - Redis 集群水平扩展
   - Vagrant 从入门到超神

## 📝 今日修改记录 (2026-03-11)

1. **定时任务 "每日学习总结" 修复**
   - 问题：payload 提示词写死日期"今天是2026-03-09"
   - 修复：改为"读取昨天的日志"（任务0点执行，应总结前一天）
   - 任务ID：58ce458e-dd09-42ae-af8d-bb002e4cce96

2. **建立每日日志习惯**
   - 开始在 memory/YYYY-MM-DD.md 记录每日工作内容
   - 定时任务会在0点读取前一天日志生成学习总结

3. **GitLab CI + SonarQube 流水线调试**
   - 问题：CI 分成 build + sonar 两个 stage，sonar 阶段没有 .class 文件
   - 解决：单一 job，Maven 编译和 Sonar 分析一起执行
   - 优化参数：`-T 2C` 并行编译、`-Dmaven.test.skip=true`、`-Dsonar.exclusions`

4. **SonarQube Issues 批量导出 CSV 方案**
   - 背景：页面导出 PDF 超过 10000 条限制
   - 方案：SonarQube 导出 Protobuf → Java 工具转 CSV
   - 流程：手动导出 .zip → Jenkins Pipeline → shell 脚本转换 → Nginx 文件服务器下载
   - 成功转换 19874 条 issues

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

*最后更新：2026-03-14*
