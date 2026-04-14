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

**OpenClaw Gateway**
- bind 模式: `custom` + `customBindHost: "0.0.0.0"` 可允许外部连接
- 端口: 18789
- Token 认证: `OPENCLAW_GATEWAY_TOKEN` 环境变量
- 节点配对命令: `openclaw devices approve <requestId>`
- 外部 ws:// 连接需要 `OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=1`

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

### 踩坑记录（摘要）

| # | 问题 | 关键解决 |
|---|------|---------|
| 1 | gateway bind 模式 | `custom` + `customBindHost` 而非 `lan` |
| 2 | 节点配对命令 | `devices approve` 而非 `nodes approve` |
| 3 | GitLab 升级后克隆地址变容器ID | 修改 external_url |
| 4 | GitLab CI/CD 500 | 清空 ci_variables + tokens |
| 5 | Nginx proxy_pass 404 | 去掉尾部斜杠 |
| 6 | SonarQube 覆盖率=0 | 加 JaCoCo 参数，不用 `-Dmaven.test.skip=true` |
| 7 | MySQL 8 密码报错 | 用 `ALTER USER`，不用 `SET PASSWORD` |
| 8 | Jenkins DingTalk text 类型 | 传 `List<String>`，不用 `.join('')` |
| 9 | kpatch 升级路径包含 KESRealPro | `-k` 参数用软链接路径 |
| 10 | KingBase kpatch 需先启动数据库 | 否则报 `kingbase not running` |

### 经验教训

- 修改文件前先备份：`cp file file.bak`
- **SonarQube 增量扫描** 用 `-Dsonar.newCode.referenceBranch=uat`
- **GitLab 大版本升级** 必须遵循官方路径，不能跨版本
- **语言环境** `en_US.UTF-8` 必须匹配
- **Trilium 备份** 需导出 root.zip，不能直接读 DB
- **MySQL 从库与 MinIO 共盘** 会导致复制延迟

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

*最后更新：2026-04-13*
