# KingbaseES V9R2C14 KFS 双轨同步部署

> 本文档介绍 KFS（Kingbase File Sync）双轨同步的部署与配置，实现双向实时数据同步。

---

## 一、双轨同步概述

### 1.1 什么是双轨同步

双轨同步（Dual-Track Sync）是 KFS 的一种工作模式，支持两个 KingbaseES 实例之间的双向实时同步：
- **轨道 A**：节点 A → 节点 B
- **轨道 B**：节点 B → 节点 A

两个方向同时工作，互为源端和目标端。

### 1.2 架构图

```
┌─────────────┐                        ┌─────────────┐
│   节点 A     │  ════════════════════  │   节点 B     │
│             │  ← KFS 轨道 B (B→A)    │             │
│  Primary    │  ────────────────────→  │  Primary    │
│             │  ─ KFS 轨道 A (A→B)    │             │
└─────────────┘                        └─────────────┘

说明：
- 每个节点同时运行 KFS Sender 和 KFS Receiver
- 轨道 A：节点 A 发送 → 节点 B 接收
- 轨道 B：节点 B 发送 → 节点 A 接收
```

---

## 二、环境规划

### 2.1 服务器规划

| 项目 | 节点 A | 节点 B |
|------|--------|--------|
| 主机名 | kfs-node-a | kfs-node-b |
| IP 地址 | 192.168.1.101 | 192.168.1.102 |
| KFS 端口 | 8891 | 8891 |
| 数据目录 | /data/kingbase/data | /data/kingbase/data |
| KFS 工作目录 | /data/kfs | /data/kfs |

### 2.2 前提条件

- 两台服务器已完成单向 KFS 同步配置（参考 [08-KFS单向同步部署](./08-KFS单向同步部署.md)）
- 已配置 SSH 互信
- KingbaseES 已安装并正常运行

---

## 三、节点 A 配置

### 3.1 目录准备

```bash
su - kingbase
mkdir -p $KINGBASE_HOME/kfs/config
mkdir -p $KINGBASE_HOME/kfs/log
mkdir -p /data/kingbase/data/kfs_replica_a
chown -R kingbase:kingbase /data/kingbase/data/kfs_replica_a
```

### 3.2 配置 KFS 双轨模式

```bash
vim $KINGBASE_HOME/kfs/config/kfs_dual.conf

# ================== KFS 双轨同步配置 (节点 A) ==================

# 集群标识
cluster.name = kfs_dual_cluster
cluster.mode = dual_track

# 本节点标识
node.a.id = node_a_01
node.a.role = dual
node.a.host = 192.168.1.101
node.a.port = 8891

# 对方节点配置
node.b.id = node_b_01
node.b.role = dual
node.b.host = 192.168.1.102
node.b.port = 8891

# KingbaseES 连接配置
kingbase.host = localhost
kingbase.port = 54321
kingbase.database = test
kingbase.user = system
kingbase.password = YourPassword123

# 轨道 A: 本节点 → 对方节点
track.a.enable = on
track.a.source.path = /data/kingbase/data
track.a.target.path = /data/kingbase/data/kfs_replica_b

# 轨道 B: 对方节点 → 本节点
track.b.enable = on
track.b.source.path = /data/kingbase/data/kfs_replica_a
track.b.target.path = /data/kingbase/data

# 同步配置
sync.mode = file
sync.interval = 1000
sync.compression = on
sync.conflict.resolution = timestamp  # 时间戳冲突解决

# 冲突检测
conflict.detection = on
conflict.log = /data/kingbase/kfs/log/conflict.log

# 日志
log.level = INFO
log.path = /data/kingbase/kfs/log
```

---

## 四、节点 B 配置

### 4.1 目录准备

```bash
su - kingbase
mkdir -p $KINGBASE_HOME/kfs/config
mkdir -p $KINGBASE_HOME/kfs/log
mkdir -p /data/kingbase/data/kfs_replica_b
chown -R kingbase:kingbase /data/kingbase/data/kfs_replica_b
```

### 4.2 配置 KFS 双轨模式

```bash
vim $KINGBASE_HOME/kfs/config/kfs_dual.conf

# ================== KFS 双轨同步配置 (节点 B) ==================

# 集群标识
cluster.name = kfs_dual_cluster
cluster.mode = dual_track

# 本节点标识
node.a.id = node_b_01
node.a.role = dual
node.a.host = 192.168.1.102
node.a.port = 8891

# 对方节点配置
node.b.id = node_a_01
node.b.role = dual
node.b.host = 192.168.1.101
node.b.port = 8891

# KingbaseES 连接配置
kingbase.host = localhost
kingbase.port = 54321
kingbase.database = test
kingbase.user = system
kingbase.password = YourPassword123

# 轨道 A: 本节点 → 对方节点
track.a.enable = on
track.a.source.path = /data/kingbase/data
track.a.target.path = /data/kingbase/data/kfs_replica_a

# 轨道 B: 对方节点 → 本节点
track.b.enable = on
track.b.source.path = /data/kingbase/data/kfs_replica_b
track.b.target.path = /data/kingbase/data

# 同步配置
sync.mode = file
sync.interval = 1000
sync.compression = on
sync.conflict.resolution = timestamp

# 冲突检测
conflict.detection = on
conflict.log = /data/kingbase/kfs/log/conflict.log

# 日志
log.level = INFO
log.path = /data/kingbase/kfs/log
```

---

## 五、启动 KFS 服务

### 5.1 节点 A 启动

```bash
# 停止之前的单向同步（如果存在）
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh stop 2>/dev/null

# 启动双轨同步
nohup $KINGBASE_HOME/../kfs/bin/kfs_server \
    --config $KINGBASE_HOME/kfs/config/kfs_dual.conf \
    --role dual \
    > /data/kingbase/kfs/log/kfs_dual_node_a.log 2>&1 &

# 检查进程
ps -ef | grep kfs_server | grep -v grep

# 检查端口
netstat -tlnp | grep 8891
```

### 5.2 节点 B 启动

```bash
# 停止之前的单向同步（如果存在）
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh stop 2>/dev/null

# 启动双轨同步
nohup $KINGBASE_HOME/../kfs/bin/kfs_server \
    --config $KINGBASE_HOME/kfs/config/kfs_dual.conf \
    --role dual \
    > /data/kingbase/kfs/log/kfs_dual_node_b.log 2>&1 &

# 检查进程
ps -ef | grep kfs_server | grep -v grep
```

---

## 六、验证双轨同步

### 6.1 查看双轨状态

```bash
# 查看同步状态
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh status --role dual

# 查看轨道状态
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh track-status

# 查看集群状态
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh cluster-status
```

### 6.2 测试双向同步

```bash
# === 节点 A 端测试 ===
su - kingbase

# 在节点 A 创建测试文件
echo "From Node A - $(date)" > /data/kingbase/data/test_a.txt

# 触发同步
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh sync-now

# 等待几秒后，在节点 B 检查
ssh kingbase@kfs-node-b "cat /data/kingbase/data/kfs_replica_a/test_a.txt"

# === 节点 B 端测试 ===
# 在节点 B 创建测试文件
ssh kingbase@kfs-node-b "echo 'From Node B - \$(date)' > /data/kingbase/data/test_b.txt"
ssh kingbase@kfs-node-b "$KINGBASE_HOME/../kfs/bin/kfs_admin.sh sync-now"

# 等待几秒后，在节点 A 检查
cat /data/kingbase/data/kfs_replica_b/test_b.txt
```

---

## 七、冲突处理

### 7.1 冲突检测配置

```bash
vim $KINGBASE_HOME/kfs/config/kfs_dual.conf

# 冲突解决策略
sync.conflict.resolution = timestamp
# 可选值：
# - timestamp: 以时间戳为准，较新的数据优先
# - source: 以源端数据为准
# - target: 以目标端数据为准
# - manual: 手动解决

# 冲突日志
conflict.log = /data/kingbase/kfs/log/conflict.log
conflict.log.level = DEBUG
```

### 7.2 查看冲突日志

```bash
# 查看冲突记录
cat /data/kingbase/kfs/log/conflict.log

# 搜索冲突
grep -i conflict /data/kingbase/kfs/log/kfs_dual_*.log
```

### 7.3 手动解决冲突

```sql
-- 查询冲突数据（根据实际情况编写）
SELECT * FROM conflict_table WHERE update_time > last_sync_time;

-- 手动决定保留哪一方数据
-- 例如：保留节点 A 的数据
UPDATE conflict_table SET col = 'value_from_a' WHERE id = 1;
```

---

## 八、切换与故障处理

### 8.1 手动切换主节点

当需要将主节点从 A 切换到 B：

```bash
# 1. 在节点 B 停止接收轨道 B
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh stop-track --track=b

# 2. 确保节点 A 停止所有写入
# （应用层面停止写入）

# 3. 在节点 B 提升为主节点
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh promote

# 4. 节点 B 开始接收来自 A 的数据
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh start-track --track=b
```

### 8.2 单节点故障恢复

当节点 A 故障，节点 B 需要独立运行：

```bash
# 在节点 B 端执行
# 1. 停止双轨模式
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh stop

# 2. 以单机模式启动（只保留轨道 B，即 B→A 方向）
vim $KINGBASE_HOME/kfs/config/kfs_standalone.conf
# cluster.mode = standalone
# track.b.enable = off  # 关闭 B→A 方向

# 3. 以 standalone 模式启动
$KINGBASE_HOME/../kfs/bin/kfs_server \
    --config $KINGBASE_HOME/kfs/config/kfs_standalone.conf \
    --role standalone
```

### 8.3 故障恢复后重建同步

节点 A 修复后，重新加入双轨集群：

```bash
# 1. 在节点 B 确认数据一致性
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh verify-data

# 2. 在节点 A 从备份恢复
rm -rf /data/kingbase/data/*
pg_basebackup -h kfs-node-b -p 54321 -U system -D /data/kingbase/data -R -Xs -P -v

# 3. 重新启动节点 A 的双轨模式
$KINGBASE_HOME/../kfs/bin/kfs_server \
    --config $KINGBASE_HOME/kfs/config/kfs_dual.conf \
    --role dual

# 4. 确认双轨状态
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh cluster-status
```

---

## 九、运维命令

### 9.1 常用管理命令

```bash
# 启动双轨同步
$KINGBASE_HOME/../kfs/bin/kfs_server --config <config> --role dual

# 停止
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh stop

# 查看状态
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh status

# 查看所有轨道状态
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh track-status

# 查看集群成员
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh cluster-members

# 强制同步
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh sync-now

# 查看同步延迟
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh sync-delay
```

### 9.2 监控脚本

```bash
#!/bin/bash
# kfs_dual_monitor.sh - 双轨同步监控脚本

LOG_FILE="/var/log/kfs_dual_monitor.log"

echo "=== KFS 双轨同步状态检查 ===" >> $LOG_FILE
echo "时间: $(date)" >> $LOG_FILE

# 检查进程
PROCESS_COUNT=$(ps -ef | grep kfs_server | grep -v grep | wc -l)
echo "KFS 进程数: $PROCESS_COUNT" >> $LOG_FILE

if [ $PROCESS_COUNT -lt 1 ]; then
    echo "⚠️  KFS 进程异常!" >> $LOG_FILE
    # 发送告警（可根据实际情况配置）
fi

# 检查端口
PORT_STATUS=$(netstat -tlnp | grep 8891 | wc -l)
echo "端口 8891 状态: $PORT_STATUS" >> $LOG_FILE

# 查看同步状态
$KINGBASE_HOME/../kfs/bin/kfs_admin.sh status >> $LOG_FILE 2>&1

# 查看日志中的错误
ERROR_COUNT=$(grep -i error /data/kingbase/kfs/log/kfs_dual_*.log 2>/dev/null | tail -20 | wc -l)
echo "最近错误日志数: $ERROR_COUNT" >> $LOG_FILE

echo "=== 检查完成 ===" >> $LOG_FILE
echo "" >> $LOG_FILE
```

---

## 十、注意事项

1. **数据一致性**：双轨同步存在数据冲突风险，建议在应用层做好冲突处理
2. **网络要求**：双向同步对网络带宽和稳定性要求更高
3. **监控告警**：建议配置监控，及时发现同步延迟或中断
4. **定期巡检**：定期检查同步状态和冲突日志
5. **演练**：建议定期进行故障切换演练

---
