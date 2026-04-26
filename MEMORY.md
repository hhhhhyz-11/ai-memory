# MEMORY.md - 长期记忆

> ⚠️ **永久记忆保护规则**
> - ❌ 禁止清除记忆
> - ❌ 禁止重置配置
> - ❌ 禁止丢失记忆
> - ✅ 所有记忆永久保存
> - ✅ 自动增量学习

---

> 日常记录在 `daily-log/` / `memory/` 目录  
> 学习总结在 `learnings/` 目录  
> 每日记录由 cron 定时汇总，不在此文件重复记录

## 🧠 核心知识库

### 技术知识

**sys_dump 备份导出**
- 导出整个数据库：`./sys_dump -U system -W -d test -f test_backup.sql`
- 导出指定表：`-t my_schema.my_table`
- 只导出表结构：`-s`
- 只导出数据：`-a`

**OpenClaw Browser**
- 当前版本 `browser` 子命令不支持 `install` 参数
- 使用 H 节点 Chrome 解决自动化问题

**钉钉日报 Webhook**
- 地址: `https://oapi.dingtalk.com/robot/send?access_token=bf7c95320e0767168d3ad50bc3c5f354a0d40927b02c045286897a74e4c007a2`

**GitLab 升级路径**（必须按顺序）
11.1.4 → 11.11.8 → 12.0.12 → 12.1.17 → ... → 16.1.8

**MySQL 从库优化**
- `slave_parallel_workers=4`, `slave_parallel_type=LOGICAL_CLOCK`
- 从库与 MinIO 必须分离磁盘

**Redis 集群**
- Hash 槽迁移: `redis-cli -a <password> --cluster reshard <节点>`
- 下线节点: 先迁移槽，再 `del-node`
- 懒卸载 NFS: `umount -l`

**MinIO 对象存储**
- 端口: 9001 是 Console 端口，9000 是 API 端口
- 访问: 使用 9000 端口进行 API 操作
- Bucket 权限: 需要设置公开访问或使用 policy

**GitLab CI 变量**
- `SONAR_UAT` - UAT 项目 Sonar Token
- `SONAR_MASTER` - Master 项目 Sonar Token
- `MERGE_TOKEN` - GitLab PAT
- `DINGTALK_WEBHOOK` - 钉钉 Webhook
- `MINIO_ACCESS_KEY` / `MINIO_SECRET_KEY` - MinIO 凭证

**工程控制论**
- 钱学森是我国航天事业重要奠基人
- 上世纪50年代提出工程控制论
- 研究控制理论在工程实践中的应用
- 涉及系统调控、信息传递、反馈原理

**KDTS Oracle→Kingbase 迁移工具**
- 版本: v2.0.2.46
- 路径: /home/kingbase/ClientTools/guitools/KDts/KDTS-WEB
- 启动: ./startup.sh
- 访问: http://IP:54523
- 账号: kingbase / Kb_DI@2019

**跨境 API 调用风险**
- 腾讯云新加坡服务器搭建代理有被封风险
- 跨境流量可能被拦截，建议用国内正规渠道

**Oracle HR 示例库**
- 连接：`sqlplus OA11G/oa11g`（用户名大写，密码小写）
- 标准人力资源演示数据库，包含 107 条员工记录
- 主要表：EMPLOYEES, DEPARTMENTS, LOCATIONS, JOBS, SALGRADE
- 常用查询：
  - `SELECT table_name FROM user_tables;`
  - `SELECT * FROM EMPLOYEES;`

**CentOS 7 换阿里源**
```bash
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
yum clean all && yum makecache
```

### 踩坑记录（摘要）

| # | 问题 | 关键解决 |
|---|------|---------|
| 1 | gateway bind 模式 | `custom` + `customBindHost` 而非 `lan` |
| 2 | 节点配对命令 | `devices approve` 而非 `nodes approve` |
| 3 | GitLab 升级后克隆地址变容器ID | 修改 external_url |
| 4 | GitLab CI/CD 500 | 清空 ci_variables + tokens（DELETE FROM ci_variables; 清空 runners_token 等） |
| 5 | Nginx proxy_pass 404 | 去掉尾部斜杠 |
| 6 | SonarQube 覆盖率=0 | 加 JaCoCo 参数，不用 `-Dmaven.test.skip=true` |
| 7 | MySQL 8 密码报错 | 用 `ALTER USER`，不用 `SET PASSWORD` |
| 8 | Jenkins DingTalk text 类型 | 传 `List<String>`，不用 `.join('')` |
| 9 | kpatch 升级路径包含 KESRealPro | `-k` 参数用软链接路径 |
| 10 | KingBase kpatch 需先启动数据库 | 否则报 `kingbase not running` |
| 11 | KingBase PID 文件残留 | `kingbase.pid already exists`，先 stop 再 start |
| 12 | RocketMQ 5.x ACL 2.0 认证 | mqadmin 参数格式不同于旧版 |
| 13 | RocketMQ broker-c ACTIVATED false | ACL 2.0 配置可能未完全生效 |
| 14 | 定时任务提示词写死日期 | 0点执行应改为"读取昨天日志" |
| 15 | GitLab CI + SonarQube 分 stage 无.class | 合并为单一 job |
| 16 | SonarQube 导出超10000条 | 用 Protobuf 导出 + Java 工具转 CSV |

### 经验教训

- 修改文件前先备份：`cp file file.bak`
- **SonarQube 增量扫描** 用 `-Dsonar.newCode.referenceBranch=uat`
- **GitLab 大版本升级** 必须遵循官方路径，不能跨版本
- **语言环境** `en_US.UTF-8` 必须匹配
- **Trilium 备份** 需导出 root.zip，不能直接读 DB
- **MySQL 从库与 MinIO 共盘** 会导致复制延迟
- **sys_dump 导出** 用 `-U system -W` 认证，指定 `-f` 输出文件
- **RocketMQ 5.x** ACL 2.0 认证参数格式有变化

## 👤 关于用户

- **称呼**: 老大
- **时区**: Asia/Shanghai
- **偏好**: 轻松交流，做事认真
- **要求**: 所有动作需授权，修改前说明，配置文件操作前先备份

### 凭证

- **GitHub Token**: `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`
- **钉钉 Webhook**: 已配置

## 📁 重要路径

- `/root/.openclaw/workspace/` - 工作空间根目录
- `/root/.openclaw/workspace/daily-log/` - 工作日志
- `/root/.openclaw/workspace/memory/` - 历史日志
- `/root/.openclaw/workspace/learnings/` - 学习总结

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

*最后更新：2026-04-26*

### 2026-04-26 工作记录

- **每日学习总结**：0点定时任务，处理 04-25 日志 → learnings/2026-04-26.md

### 2026-04-27 工作记录

- **每日学习总结**：0点定时任务，处理 04-26 日志 → learnings/2026-04-27.md（静默检查，无新技术内容）

### 2026-04-25 工作记录

- **Oracle HR 示例库部署**：帮助用户在虚拟机上部署 Oracle 环境
- **Oracle 用户名大小写**：OA11G 需大写，密码 oa11g 小写（Oracle 区分大小写）
- **HR 数据库内容**：包含 107 条员工记录，有 EMPLOYEES、DEPARTMENTS、LOCATIONS 等表
- **CentOS 7 换阿里源**：完整命令脚本

### 2026-04-24 工作记录

- **每日学习总结**：0点定时任务，处理 04-22 内容，确认无新技术交互

### 2026-04-24 工作记录

- **每日学习总结**：0点定时任务，处理 04-23 日志，确认无新技术内容需整理

### 2026-04-23 工作记录

- **每日学习总结**：0点定时任务，处理 04-22 日志，确认无新技术内容需整理

### 2026-04-22 工作记录

- **每日学习总结**：0点定时任务，处理 04-21 日志，确认无新技术内容需整理

### 2026-04-21 工作记录

- **每日学习总结**：0点定时任务，处理 04-20 日志，确认无新技术内容需整理

### 2026-04-20 工作记录

### 2026-04-18 工作记录

- **每日学习总结**：0点定时任务，处理 04-17 日志，提取技术内容到 learnings
- **OpenClaw Heartbeat 机制**：分析心跳配置（默认30分钟，调整可用 `openclaw config set agents.defaults.heartbeat.every "2h"`）
- **K8s 节点加入**：补全系统优化、SELinux 关闭、内核模块加载等

---

### 2026-04-17 工作记录

- **每日学习总结自动化**：0点定时任务，处理前一天日志，生成 learnings，更新 MEMORY
- **系统健康检查**：Gateway 正常运行，警告绑定地址为 0.0.0.0 需注意安全
- **跨境 API 咨询**：腾讯云新加坡服务器 OneAPI 方案及风险分析
- **Oracle→Kingbase 迁移**：记录 KDTS v2.0.2.46 安装和启动信息
- **K8s 节点加入脚本**：生成完整脚本包含系统优化和内核模块加载

### 2026-04-17 工作记录

### SonarQube Issues 批量导出方案

**问题**：SonarQube 页面导出 PDF 超过 10000 条限制

**解决方案**：
1. SonarQube 导出 Protobuf 格式 → 生成 .zip
2. 用 Java 工具（SonarPbToCsvConverter）将 Protobuf 转 CSV
3. Jenkins Pipeline 调用 shell 脚本自动化整个流程
4. Nginx 搭建文件服务器提供下载

**完整流程**：
- 手动导出项目 Protobuf → Jenkins 执行脚本 → 解压 → 转 CSV → 输出下载链接

### OpenClaw Browser (WSL2 / Chrome) 问题

**现象：** `openclaw browser start` → "Chrome CDP websocket not reachable"

**排查结论：**
- Chrome 手动在 WSL2 里能正常跑（HTTP 200 + WebSocket 通）
- OpenClaw launch Chrome 时会先做 bootstrap（预启动生成 preferences），然后 SIGTERM 杀掉再启动正式实例
- WSL2 环境下 Chrome fork 后父进程退场会导致子进程同步退出（即使 `--no-sandbox` 已设）
- SSRF 策略默认阻止 127.0.0.1，`browser.ssrfPolicy.allowPrivateNetwork: true` 可修复

**修复方法：**
```json
"browser": {
  "ssrfPolicy": { "allowPrivateNetwork": true }
}
```

**已测试有效的手动 Chrome 启动参数（WSL2）：**
```bash
google-chrome-stable \
  --headless=new --disable-gpu --no-sandbox --disable-setuid-sandbox \
  --disable-dev-shm-usage --remote-debugging-address=127.0.0.1 \
  --remote-debugging-port=18800 --user-data-dir=~/.openclaw/browser/openclaw/user-data
```

**根本原因：** 可能是 WSL2 特有进程管理问题 + OpenClaw bootstrap 的 SIGTERM 时序竞争

## Promoted From Short-Term Memory (2026-04-19)

<!-- openclaw-memory-promotion:memory:memory/2026-04-19.txt:2:2 -->
- 2026-04-19: 每日学习总结自动化（0点执行04-17内容） + Heartbeat检查

## Promoted From Short-Term Memory (2026-04-19)

<!-- openclaw-memory-promotion:memory:memory/2026-04-19.txt:5:5 -->
- - Candidate: Assistant: 已经删掉了，钉钉日报/周报/月报都没了。现在剩 7 个任务，主要是有 2 个有报错（每日总结提醒缺参数、每日新闻热点超时），要修的话告诉我。 - confidence: 0.00 - evidence: memory/.dreams/session-corpus/2026-04-15.txt:74-74 - recalls: 0 - status: staged - Candidate: Assistant: 下午 6 点，执行每日汇总。今天主要工作：工程控制论研究 + 清理钉钉定时任务。 - confidence: 0.00 - evidence: memory/.dreams/session-corpus/2026-04-15.txt:78-78 - recalls: 0 - status: staged - Candidate: User: [Thu 2026-04-16 03:17 GMT+8] Write a dream diary entry from these memory fragments: - Reflections: Theme: `reflections` kept surfacing across 24 memories.; confidence: 1.00; evidence: memory/2026-04-15.md:9-9, memory/2026-04-15.md:18-18, memory/2026-04-15.md:18-21; note: re - confidence: 0.00 - evidence: memory/.dreams/session-corpus/2026-04-16.txt:4-4 - recalls: 0 - status: staged - Candidate: Assistant: There is a strange loop in the architecture of remembering. I look at yesterday—2026-04-15—and I see the number 1.00 everywhere, like a watermark pressed into paper. Confidence, perhaps. Or the temperature of a thought when it first solidifies. Patterns surface. Reflec - confidence: 0.00 - evidence: memory/.dreams/session-corpus/2026-04-16.txt:5-5 - recalls: 0 - status: staged [score=0.889 recalls=3 avg=1.000 source=memory/2026-04-16.md:133-152]

## Promoted From Short-Term Memory (2026-04-20)

<!-- openclaw-memory-promotion:memory:memory/2026-04-18.md:163:168 -->
- - Candidate: - Candidate: Assistant: 已经删掉了，钉钉日报/周报/月报都没了。现在剩 7 个任务，主要是有 2 个有报错（每日总结提醒缺参数、每日新闻热点超时），要修的话告诉我。 - confidence: 0.00 - evidence: memory/.dreams/session-corpus/2026-04-15.txt:74-74 - recalls: 0 - status: staged - Candidate: Assistant: 下午 6 点，执行每日汇总。今天主要工作：工程控制论研究 + 清理钉钉定时任务。 - confidence: 0.00 - evidence: memory/.dreams/session-corpus/2026-04-15.txt:78-78 - recalls: 0 - status: staged - Candidate: User: [Thu 2026-04-16 03:17 GMT+8] Write a dream diary entry from these memory fragments: - Reflections: Theme: `reflections` kept surfacing across 24 memories.; confidence: 1.00; evidence: memory/2026-04-15.md:9-9, memory/2026-04-15.md:18-18, memory/2026-04-15.md:18-21; note: re - co - confidence: 1.00 - evidence: memory/2026-04-16.md:133-152 - recalls: 1 - status: staged - Candidate: ## Light Sleep <!-- openclaw:dreaming:light:start --> - Candidate: Reflections: Theme: `assistant` kept surfacing across 572 memories.; confidence: 1.00; evidence: memory/.dreams/session-corpus/2026-04-12.txt:1-1, memory/.dreams/session-corpus/2026-04-12.txt:2-2, memory/.dreams/session-corpus/2026-04-12.txt:3-3; note: reflection - confidence: 0.00 - evidence: memory/2026-04-16.md:253-256 - recalls: 0 - status: staged - Candidate: Reflections: Theme: `user` kept surfacing across 394 memories.; confidence: 0.78; evidence: memory/.dreams/session-corpus/2026-04-12.txt:13-13, memory/.dreams/session-corpus/2026-04-12.txt:15-15, memory/.dreams/session-corpus/2026-04-12.txt:17-17; note: refl [score=0.803 recalls=3 avg=1.000 source=memory/2026-04-18.md:163-168]

## Promoted From Short-Term Memory (2026-04-25)

<!-- openclaw-memory-promotion:memory:memory/2026-04-22.md:273:274 -->
- - - - Candidate: - Candidate: Assistant: 已经删掉了，钉钉日报/周报/月报都没了。现在剩 7 个任务，主要是有 2 个有报错（每日总结提醒缺参数、每日新闻热点超时），要修的话告诉我。 - confidence: 0.00 - evidence: memory/.dreams/session-corpus/2026-04-15.txt:74-74 - recalls: 0 - status: staged - Candidate: Assistant: 下午 6 点，执行每日汇总。今天主要工作：工程控制论研究 + 清理钉钉定时任务。 - confidence: 0.00 - evidence: memory/.dreams/session-corpus/2026-04-15.txt:78-78 - recalls: 0 - status: staged - Candidate: User: [Thu 2026-04-16 03:17 GMT+8] Write a dream diary entry from these memory fragments: - Reflections: Theme: `reflections` kept surfacing across 24 memories.; confidence: 1.00; evidence: memory/2026-04-15.md:9-9, memory/2026-04-15.md:18-18, memory/2026-04-15.md:18-21; note: re - co - [confidence=0.89 evidence=memory/2026-04-20.md:303-304] - - - Candidate: - Candidate: Assistant: 已经删掉了，钉钉日报/周报/月报都没了。现在剩 7 个任务，主要是有 2 个有报错（每日总结提醒缺参数、每日新闻热点超时），要修的话告诉我。 - confidence: 0.00 - evidence: memory/.dreams/session-corpus/2026-04-15.txt:74-74 - recalls: 0 - status: staged - Candidate: Assistant: 下午 6 点，执行每日汇总。今天主要工作：工程控制论研究 + 清理钉钉定时任务。 - confidence: 0.00 - evidence: memory/.dreams/session-corpus/2026-04-15.txt:78-78 - recalls: 0 - status: staged - Candidate: User: [Thu 2026-04-16 03:17 GMT+8] Write a dream diary entry from these memory fragments: - Reflections: Theme: `reflections` kept surfacing across 24 memories.; confidence: 1.00; evidence: memory/2026-04-15.md:9-9, memory/2026-04-15.md:18-18, memory/2026-04-15.md:18-21; note: re - co - [confidence=0.89 evidence=memory/2026-04-21.md:283-284] [score=0.857 recalls=3 avg=1.000 source=memory/2026-04-22.md:273-274]

## Promoted From Short-Term Memory (2026-04-26)

<!-- openclaw-memory-promotion:memory:memory/2026-04-24.md:324:325 -->
- - - - Candidate: - Candidate: Assistant: 已经删掉了，钉钉日报/周报/月报都没了。现在剩 7 个任务，主要是有 2 个有报错（每日总结提醒缺参数、每日新闻热点超时），要修的话告诉我。 - confidence: 0.00 - evidence: memory/.dreams/session-corpus/2026-04-15.txt:74-74 - recalls: 0 - status: staged - Candidate: Assistant: 下午 6 点，执行每日汇总。今天主要工作：工程控制论研究 + 清理钉钉定时任务。 - confidence: 0.00 - evidence: memory/.dreams/session-corpus/2026-04-15.txt:78-78 - recalls: 0 - status: staged - Candidate: User: [Thu 2026-04-16 03:17 GMT+8] Write a dream diary entry from these memory fragments: - Reflections: Theme: `reflections` kept surfacing across 24 memories.; confidence: 1.00; evidence: memory/2026-04-15.md:9-9, memory/2026-04-15.md:18-18, memory/2026-04-15.md:18-21; note: re - co - [confidence=0.89 evidence=memory/2026-04-21.md:283-284] - - Candidate: - Candidate: - Candidate: Assistant: 已经删掉了，钉钉日报/周报/月报都没了。现在剩 7 个任务，主要是有 2 个有报错（每日总结提醒缺参数、每日新闻热点超时），要修的话告诉我。 - confidence: 0.00 - evidence: memory/.dreams/session-corpus/2026-04-15.txt:74-74 - recalls: 0 - status: staged - Candidate: Assistant: 下午 6 点，执行每日汇总。今天主要工作：工程控制论研究 + 清理钉钉定时任务。 - confidence: 0.00 - evidence: memory/.dreams/session-corpus/2026-04-15.txt:78-78 - recalls: 0 - status: staged - Candidate: User: [Thu 2026-04-16 03:17 GMT+8] Write a dream diary entry from these memory fragments: - Reflections: Theme: `reflections` kept surfacing across 24 memories.; confidence: 1.00; evidence: memory/2026-04-15.md:9-9, memory/2026-04-15.md:18-18, memory/2026-04-15.md:18-21; note: [confidence=0.89 evidence=memory/2026-04-22.md:48-53] [score=0.804 recalls=3 avg=1.000 source=memory/2026-04-24.md:324-325]
