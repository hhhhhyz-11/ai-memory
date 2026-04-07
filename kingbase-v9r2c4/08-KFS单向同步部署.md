# KingbaseES V9R2C14 KFS 单向同步部署

> 本文档介绍 KFS（Kingbase File Sync）单向同步的部署与配置，实现源端到目标端的文件级数据同步。

---

## 一、KFS 概述

### 1.1 KFS 简介

KFS（Kingbase File Sync）是金仓提供的文件级同步复制组件，支持：
- 单向同步（源 → 目标）
- 双向同步（源 ↔ 目标）
- 断点续传
- 文件级增量同步
- 异地容灾

### 1.2 架构说明

```
┌─────────────┐         KFS          ┌─────────────┐
│   源端      │  ──────────────────→  │   目标端    │
│ (Primary)   │     文件同步通道      │ (Standby)   │
│             │     实时同步         │             │
└─────────────┘                       └─────────────┘
```

---

## 二、环境规划

### 2.1 服务器规划

| 项目 | 源端 (Primary) | 目标端 (Standby) |
|------|----------------|------------------|
| 主机名 | kfs-primary | kfs-standby |
| IP | 192.168.1.101 | 192.168.1.102 |
| KingbaseES 数据目录 | /data/kingbase/data | /data/kingbase/data |
| KFS 工作目录 | /data/kfs | /data/kfs |
| 同步端口 | 8891 | 8891 |
| 复制模式 | 发送端 | 接收端 |

### 2.2 资源要求

| 组件 | CPU | 内存 | 磁盘 |
|------|-----|------|------|
| KFS 发送端 | 2 核 | 2 GB | 取决于同步数据量 |
| KFS 接收端 | 2 核 | 2 GB | 取决于同步数据量 |

---

## 三、KFS 安装

### 3.1 检查 KFS 安装

```bash
# 检查 KFS 是否已随 KingbaseES 安装
ls -la $KINGBASE_HOME/../kfs/
ls -la /opt/KingbaseES/KFS/

# 检查版本
$KINGBASE_HOME/../kfs/bin/kfs_server --version
```

### 3.2 创建 KFS 用户

```bash
# 在两台服务器上都需要执行
useradd -m -s /bin/bash kfs
echo "kfs:kfspass123" | chpasswd

# 授权目录
mkdir -p /data/kfs
chown -R kfs:kfs /data/kfs
```

### 3.3 SSH 互信配置

```bash
# 在源端执行
su - kfs
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
ssh-copy-id kfs@kfs-standby

# 测试连接
ssh kfs@kfs-standby "hostname"
```

---

## 四、源端配置

### 4.1 创建 KFS 配置目录

```bash
# 切换到 kingbase 用户配置（KFS 通常由 kingbase 管理）
su - kingbase
mkdir -p $KINGBASE_HOME/kfs/config
mkdir -p $KINGBASE_HOME/kfs/log
```

### 4.2 配置 KFS 发送端

```bash
vim $KINGBASE_HOME/kfs/config/kfs_sender.conf

# ================== KFS 发送端配置 ==================

# 标识
cluster.name = kfs_cluster_1
node.id = primary_01
node.role = sender

# 网络配置
node.host = 192.168.1.101
node.port = 8891

# 目标端配置
target.1.host = 192.168.1.102
target.1.port = 8891
target.1.node.id = standby_01

# KingbaseES 连接配置
kingbase.host = localhost
kingbase.port = 54321
kingbase.database = test
kingbase.user = system
kingbase.password = YourPassword123

# 同步配置
sync.mode = file
sync.interval = 1000  # 毫秒
sync.compression = on

# 日志级别
log.level = INFO
log.path = /data/kingbase/kfs/log
```

### 4.3 启动 KFS 发送端服务

```bash
# 启动 KFS 发送端
nohup $KINGBASE_HOME/../kfs/bin/kfs_server \
    --config $KINGBASE_HOME/kfs/config/kfs_sender.conf \
    --role sender \
    > /data/kingbase/kfs/log/kfs_sender.log 2>&1 &

# 检查进程
ps -ef | grep kfs_server | grep -v grep

# 检查端口
netstat -tlnp | grep 8891
```

---

## 五、目标端配置

### 5.1 创建 KFS 配置目录

```bash
su - kingbase
mkdir -p $KINGBASE_HOME/kfs/config
mkdir -p $KINGBASE_HOME/kfs/log
mkdir -p /data/kingbase/data/kfs_replica  # 接收数据存放位置
chown -R kingbase:kingbase /data/kingbase/data/kfs_replica
```

### 5.2 配置 KFS 接收端

```bash
vim $KINGBASE_HOME/kfs/config/kfs_receiver.conf

# ================== KFS 接收端配置 ==================

# 标识
cluster.name = kfs_cluster_1
node.id = standby_01
node.role = receiver

# 网络配置
node.host = 192.168.1.102
node.port = 8891

# 源端配置
sender.1.host = 192.168.1.101
sender.1.port = 8891
sender.1.node.id = primary_01

# 数据同步目录
sync.data.path = /data/kingbase/data/kfs_replica
sync.wal.path = /data/kingbase/data/pg_wal

# 同步模式
sync.mode = file
sync.interval = 1000

# 日志
log.level = INFO
log.path = /data/kingbase/kfs/log
```

### 5.3 启动 KFS 接收端服务

```bash
# 启动 KFS 接收端
nohup $KINGBASE_HOME/../kfs/bin/kfs_server \
    --config $KINGBASE_HOME/kfs/config/kfs_receiver.conf \
    --role receiver \
    > /data/kingbase/kfs/log/kfs_receiver.log 2>&1 &

# 检查进程
ps -ef | grep kfs_server | grep -v grep

# 检查端口
netstat -tlnp | grep 8891
```

---

## 六、验证同步状态

### 6.1 查看 KFS 状态

```bash
# 源端查看发送状态
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh status --role sender

# 目标端查看接收状态
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh status --role receiver

# 或者
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh list-nodes
```

### 6.2 测试同步

```bash
# 在源端创建测试文件
su - kingbase
echo "test data $(date)" > /data/kingbase/data/test_sync.txt

# 触发同步
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh sync-now

# 在目标端检查
su - kingbase
ls -la /data/kingbase/data/kfs_replica/
cat /data/kingbase/data/kfs_replica/test_sync.txt
```

### 6.3 查看同步日志

```bash
# 源端日志
tail -f /data/kingbase/kfs/log/kfs_sender.log

# 目标端日志
tail -f /data/kingbase/kfs/log/kfs_receiver.log

# 搜索错误
grep -i error /data/kingbase/kfs/log/kfs_sender.log
grep -i error /data/kingbase/kfs/log/kfs_receiver.log
```

---

## 七、与 KingbaseES 集成

### 7.1 配置 KingbaseES 触发 KFS 同步

```sql
-- 创建 KFS 同步触发函数
CREATE OR REPLACE FUNCTION kfs_sync_trigger()
RETURNS TRIGGER AS $$
BEGIN
    -- 通知 KFS 同步特定文件/目录
    PERFORM sys_kingbase_notify('kfs_sync', row_to_json(NEW));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 应用到表（示例）
-- CREATE TRIGGER trg_sync AFTER INSERT OR UPDATE ON my_table
-- FOR EACH ROW EXECUTE FUNCTION kfs_sync_trigger();
```

### 7.2 配置 KingbaseES WAL 日志同步

```bash
vim $KINGBASE_HOME/kfs/config/kfs_sender.conf

# 添加 WAL 同步配置
sync.wal.enable = on
sync.wal.path = /data/kingbase/data/pg_wal
sync.wal.retention = 7d
```

---

## 八、常见问题

### 8.1 连接失败

**错误**：`connection refused` 或 `connection timeout`

**排查**：
```bash
# 检查网络连通性
ping kfs-standby

# 检查端口
telnet 192.168.1.102 8891

# 检查防火墙
firewall-cmd --list-all
```

**解决**：
```bash
# 开放端口
firewall-cmd --permanent --add-port=8891/tcp
firewall-cmd --reload
```

### 8.2 同步延迟大

**排查**：
```bash
# 查看同步队列
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh queue-status

# 查看网络带宽
iftop -i eth0
```

**优化**：
```bash
# 调整同步间隔
vim $KINGBASE_HOME/kfs/config/kfs_sender.conf
sync.interval = 500  # 减小间隔

# 启用压缩
sync.compression = on
```

### 8.3 同步中断

**原因**：网络不稳定或目标端故障

**解决**：
```bash
# 重启同步
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh restart

# 查看断点信息
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh checkpoint-status
```

---

## 九、运维命令

### 9.1 常用管理命令

```bash
# 启动服务
$KINGBASE_HOME/../kfs/bin/kfs_server --config <config_file> --role <role> -d

# 停止服务
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh stop

# 重启服务
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh restart

# 查看状态
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh status

# 强制同步
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh sync-now

# 查看配置
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh show-config
```

### 9.2 性能调优参数

```bash
vim $KINGBASE_HOME/kfs/config/kfs_sender.conf

# 性能调优
sync.parallel = 4
sync.buffer.size = 64MB
sync.batch.size = 1000
network.buffer.size = 16MB
```

---
