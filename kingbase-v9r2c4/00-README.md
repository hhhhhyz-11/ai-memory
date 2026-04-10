# KingbaseES V9R2C14 部署与运维指南

> 📌 本文档档基于 KingbaseES V9R2C14 版本编写，涵盖单机部署、主备集群、数据迁移、同步复制、监控运维等全流程操作指南。

---

## 📋 文档索引

| 编号 | 文档名称 | 说明 |
|------|---------|------|
| 01 | [单机部署全流程](./01-单机部署全流程.md) | 从系统准备到数据库启用的完整步骤 |
| 02 | [主备集群部署](./02-主备集群部署.md) | KingbaseES RAC/RAC Proxy 主备集群配置 |
| 03 | [系统及数据库内存优化](./03-系统及数据库内存优化.md) | OS 和数据库层内存参数调优 |
| 04 | [授权更换操作](./04-授权更换操作.md) | license 文件更新、查看与更换流程 |
| 05 | [KDTS全量迁移](./05-KDTS全量迁移.md) | 使用 KDTS 工具进行全量数据迁移 |
| 06 | [常见报错分类汇总](./06-常见报错分类汇总.md) | 各类常见错误及解决方案 |
| 07 | [PLSQL报错处理](./07-PLSQL报错处理.md) | 存储过程/函数报错处理 |
| 08 | [KFS单向同步部署](./08-KFS单向同步部署.md) | KFS 单向同步配置与部署 |
| 09 | [KFS双轨同步部署](./09-KFS双轨同步部署.md) | KFS 双轨同步配置与部署 |
| 10 | [断点续传配置](./10-断点续传配置.md) | 迁移/同步断点续传配置 |
| 11 | [KEMCC部署全流程](./11-KEMCC部署全流程.md) | KEMCC 控制中心部署 |
| 12 | [告警规则配置](./12-告警规则配置.md) | KEMCC 告警规则配置 |
| 13 | [KWR巡检报告](./13-KWR巡检报告.md) | KWR 巡检报告生成与分析 |
| 14 | [基础运维工具](./14-基础运维工具.md) | sys_monitor、sys_stat 等常用工具 |
| 15 | [kpatch 补丁升级流程](./15-kpatch补丁升级流程.md) | V9R2C13 单机/集群升级至 PS014，含回退操作 |

---

## 🏷️ 版本信息

- **数据库版本**：KingbaseES V9R2C14
- **操作系统**：CentOS 7 / Red Hat 7 及以上 / 麒麟 V10 / 统信UOS
- **文档编写**：小小黄 🐱

---

## ⚠️ 重要提示

1. **操作前备份**：对数据库进行任何重要操作前，请务必备份 `kingbase.conf`、`sys_hba.conf` 等关键配置文件
2. **权限要求**：安装和配置操作建议使用 `kingbase` 系统用户，避免 root 直接操作数据库文件
3. **版本一致性**：主备集群所有节点建议使用相同版本、相同补丁的 KingbaseES
4. **生产环境**：生产环境部署请参考《KingbaseES V9R2C14 管理员指南》

---

## 🔧 快速命令速查

```bash
# 启动数据库
sys_ctl -D $KINGBASE_HOME/data start

# 停止数据库
sys_ctl -D $KINGBASE_HOME/data stop -m fast

# 连接数据库
ksql -U system -d test kingbase

# 查看数据库版本
ksql -U system -d test -c "SELECT version();"

# 查看 license 信息
ksql -U system -d test -c "SELECT * FROM sys_license_info();"
```

---
