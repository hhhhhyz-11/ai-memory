# 历史记录归档（MEMORY.md 精简前的内容）

> 此文件记录 MEMORY.md 精简前的历史每日记录摘要
> 详细日志见 `daily-log/` 和 `learnings/` 目录

## 2026-03 重要事件摘要

- **03-11**: 定时任务修复（payload日期写死）、每日日志习惯建立、SonarQube流水线调试
- **03-12**: OpenClaw Node掉线排查（J 节点 TOKEN 未设置）、SonarQube增量扫描配置
- **03-13**: SonarQube增量参数、`-Dsonar.newCode.referenceBranch=uat`、GitLab CI门禁配置
- **03-17**: GitLab 11.1.4→16.1.8 升级 Phase1 完成、备份恢复流程
- **03-18**: 每日学习总结 cron 执行、Nginx proxy_pass 斜杠问题、GitLab CI自动合并MR
- **03-25**: Redis 集群水平扩容（添加/下线节点）、NFS umount -l
- **03-26**: Redis 节点下线验证（192.168.0.50）、RabbitMQ Docker 迁移
- **03-27**: MySQL 8.0 Systemd→Docker 迁移、OpenClaw 模型切换 M2.5→M2.7
- **03-28**: K8s 证书更新不需重启 Docker、Nacos raft 目录需清空、Trilium WAL 备份
- **03-30**: GitLab 升级验证、MySQL 从库多线程复制、GitHub 仓库整理
- **03-31**: GitLab+SonarQube 重新部署、RocketMQ 迁移 50→53、飞书渠道接入、PG Docker 迁移

## 踩坑完整记录

1. gateway bind 模式 → `custom` + `customBindHost`
2. 节点配对命令 → `devices approve`
3. GitLab gitlab-secrets.json → CI/CD 500 → 清空 ci_variables
4. GitLab 克隆地址变容器ID → 修改 external_url
5. Nginx proxy_pass 尾部斜杠 → 去掉
6. GitLab 合并 405 → 加 `"squash": false`
7. GitLab interruptible → 移除参数（11.x不支持）
8. GitLab 重复流水线 → API 取消旧 pipeline
9. Redis 连接 I/O error → 端口/防火墙/进程排查
10. MySQL 8 密码重置 → `ALTER USER` 而非 `SET PASSWORD`
11. Jenkins DingTalk text 类型 → `List<String>`
12. Trilium 数据库 → WAL 模式，需 root.zip 导出
13. SonarQube 覆盖率=0 → JaCoCo 参数 + 不用 `-Dmaven.test.skip=true`
14. kpatch 路径含 KESRealPro → 用软链接路径
15. kpatch kingbase not running → 先启动数据库

## 技术知识

- SonarQube: `-Dsonar.newCode.referenceBranch=uat` / JaCoCo 覆盖率
- GitLab 升级: 官方路径，不能跨版本，语言环境 en_US.UTF-8
- MySQL 从库: `slave_parallel_workers=4`，与 MinIO 分离磁盘
- Redis: `reshard` 迁槽，`del-node` 删除节点
- AI 短剧: Leonardo.ai + 快手可灵 + Azure TTS + CapCut
- OpenClaw: WSL token 持久化 `/etc/environment`，`ask:"off"` 在 agents.main 层

---

*归档时间：2026-04-13*
