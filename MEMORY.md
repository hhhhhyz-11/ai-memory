# MEMORY.md - 长期记忆

> ⚠️ **永久记忆保护规则**
> - ❌ 禁止清除记忆
> - ❌ 禁止重置配置
> - ❌ 禁止丢失记忆
> - ✅ 所有记忆永久保存
> - ✅ 自动增量学习
> - ✅ 从当前会话开始，完整记录所有历史、偏好、习惯、需求、性格、常用指令

---

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

**GitLab 大版本升级**
- 必须遵循官方升级路径，不能跨版本升级
- 升级前需恢复到官方版本，不能从第三方修改版直接升级
- 语言环境 `en_US.UTF-8` 必须匹配，否则 PostgreSQL 启动失败
- Docker 卷：/var/opt/gitlab（数据）、/var/log/gitlab（日志）、/etc/gitlab（配置）
- 升级后验证至少 2 小时再继续下一步
- 加密密钥不兼容问题彻底解决：清空 ci_variables + ci_group_variables + tokens

**AI 短剧制作工具链**
- Leonardo.ai：AI 图片生成
- 快手可灵：图生视频
- Azure TTS：文字转语音配音
- CapCut：视频剪辑

**GitLab CI 自动合并 MR**
- 使用有 Merge 权限的 PAT（Personal Access Token）
- API 端点：`PUT /projects/:id/merge_requests/:iid/merge`
- 合并条件：MR 状态 `opened` + `can_be_merged` 为 true
- CI 配置：添加 `MERGE_TOKEN` 变量，使用 curl + jq 执行

### 踩坑记录

1. **gateway bind 模式问题**
   - `lan` 模式不生效，需用 `custom` + `customBindHost`

2. **节点配对命令错误**
   - 错误: `openclaw nodes approve`
   - 正确: `openclaw devices approve`

3. **Windows 环境变量**
   - CMD: `set VAR=value`
   - PowerShell: `$env:VAR="value"`

4. **GitLab 升级 - gitlab-secrets.json 导致 CI/CD 500**
   - 问题：旧版本配置文件导致 CI/CD 页面 500 错误（aes256_gcm_decrypt）
   - 解决：Rails 控制台删除所有变量 `project.variables.destroy_all` 或数据库清空 ci_variables

5. **GitLab 升级 - 克隆地址变成容器 ID**
   - 问题：升级后克隆地址变成容器 ID 而非 IP 地址
   - 解决：修改 /etc/gitlab/gitlab.rb 中 external_url 为正确地址

6. **Nginx 代理转发 404 问题**
   - 问题：测试域名转发到生产域名时返回 404
   - 原因：`proxy_pass` 尾部斜杠导致路径重复
   - 解决：去掉 `proxy_pass` 中的尾部路径

7. **GitLab 合并返回 405 Method Not Allowed**
   - 问题：CI 流水线执行合并时返回 405
   - 原因：MR 状态不允许合并或 squash 配置问题
   - 解决：合并 API 加参数 `"squash": false`

8. **GitLab 11.1.4 不支持 interruptible**
   - 问题：CI 配置包含 `interruptible: true` 导致验证失败
   - 原因：GitLab 11.x 不支持 modern CI 的 interruptible 参数
   - 解决：移除该参数

9. **GitLab 重复流水线问题**
   - 问题：提交新代码后，旧 pipeline 还在运行，新 pipeline 等待
   - 解决：用 API 取消同一分支的旧 pipeline
   - API：`POST /projects/:id/pipelines/:pipeline_id/cancel`

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
- **GitLab 大版本升级** 必须遵循官方升级路径，不能跨版本
- **GitLab 升级前** 恢复到官方版本再升级，不能从第三方修改版直接升级
- **语言环境** `en_US.UTF-8` 必须匹配，否则 PostgreSQL 启动失败

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

### 凭证管理

**GitHub Token**: ✅ 已记录（安全存储）
- 用于推送代码到 GitHub

**配置位置**: 已在 git remote 中配置

---

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

---

## 📝 今日修改记录 (2026-03-17)

1. **GitLab 11.1.4 → 16.1.8 升级**
   - 完成 Phase 1: 恢复到官方 11.1.4 备份起点 ✅
   - 完成 Step 1: 11.1.4 → 11.11.8 ✅
     - 踩坑：gitlab-secrets.json 导致 CI/CD 500 错误，解决：删除所有项目变量
   - 完成 Step 2: 11.11.8 → 12.0.12 ✅
     - 踩坑：克隆地址变成容器ID，解决：更新 external_url 配置
     - 踩坑：aes256_gcm_decrypt 加密错误，解决：清空 ci_variables 和 tokens
   - 待执行 Step 3: 12.0.12 → 12.1.17
   - **重要经验**：恢复到相同版本再升级，不能跨版本；语言环境必须匹配

**升级路径**: 11.1.4 → 11.11.8 → 12.0.12 → 12.1.17 → ... → 16.1.8

2. **学习总结归档**
   - 将 gitlab-upgrade-11.1.4-to-12.0.12.md 移至 learnings/ 目录

---

*最后更新：2026-03-18*

## 📝 今日修改记录 (2026-03-18)

1. **每日学习总结机制执行** (cron 任务)
   - 任务ID：58ce458e-dd09-42ae-af8d-bb002e4cce96
   - 输入：memory/2026-03-17.md（GitLab 升级日志）
   - 输出：learnings/2026-03-17.md
   - 内容：GitLab 大版本升级路径、备份恢复、Docker 运维、踩坑记录

2. **Nginx proxy_pass 尾部斜杠问题**
   - 问题：测试域名转发到生产时返回 404
   - 原因：`proxy_pass https://oa.gdyunst.com/oaweb/` 会替换路径
   - 解决：去掉尾部斜杠，保留原始请求路径
   - 配置层级：测试机 → 生产机 → 第二层转发 → 后端

3. **GitLab CI 自动合并 MR**
   - 需求：开发无合并权限，MR 测试通过后自动合并
   - 方案：CI pipeline 末尾添加 `auto-merge` job
   - 实现：用有 Merge 权限的 PAT 调用 GitLab Merge API
   - API：`PUT /projects/:id/merge_requests/:iid/merge`
   - 检查条件：`opened` + `can_be_merged`

---

*最后更新：2026-03-25*（今日工作已整理至 learnings/2026-03-23.md）

## 📝 今日修改记录 (2026-03-23)

1. **GitLab CI/CD + SonarQube 完整流水线**
   - SonarQube 增量扫描 + 质量门检查
   - PDF 报告生成：Python + WeasyPrint + 中文字体
   - MinIO 对象存储：mc 命令行配置、bucket 公开访问
   - MR 评论与钉钉通知

2. **GitHub 仓库管理**
   - 创建项目仓库：https://github.com/hhhhhyz-11/project

3. **关键踩坑**
   - MinIO 端口：9000 是 API 端口，9001 是 Console 端口
   - Bucket 权限：需要用 `mc anonymous set download` 设置公开访问

---

*最后更新：2026-03-20*（今日工作已整理至 learnings/2026-03-20.md）

## 📝 今日修改记录 (2026-03-20)

1. **GitLab CI SonarQube 质量门调试**
   - MR 合并返回 405 错误解决：去掉 `when: manual`，添加 `squash: false` 参数
   - GitLab 11.1.4 不支持 `interruptible: true` 参数

2. **GitLab CI 流水线重复触发问题**
   - 场景：MR 还在跑 CI 时提交新代码，导致新旧 pipeline 同时存在
   - 解决方案：在 job 启动时取消同一分支的旧 running pipeline
   - API：`/api/v4/projects/:id/pipelines/:pipeline_id/cancel`
