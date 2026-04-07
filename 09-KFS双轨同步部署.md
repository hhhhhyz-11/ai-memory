# KingbaseES V9R2C14 KFS 双轨同步部署（中/高级）

> 适用版本：KingbaseES V9R2C14
> 参考：https://docs.kingbase.com.cn/cn/KES-V9R2C14/sync/

---

## 一、双轨同步概述

双轨同步（Dual Rail Sync）是 KFS 的高级特性，支持两个 KingbaseES 数据库之间的**双向实时同步**。适用于：
- **双活场景**：两个节点同时提供读写服务
- **数据灾备**：双向同步确保数据不丢失
- **应用级切换**：故障时可快速切换到备用节点

### 1.1 双轨同步架构

```
┌─────────────────┐         双向同步          ┌─────────────────┐
│   Node A        │◄──────────────────────►│   Node B        │
│  192.168.1.101  │                          │  192.168.1.102  │
│  KingbaseES A   │                          │  KingbaseES B   │
│  KFS Service A  │                          │  KFS Service B  │
└─────────────────┘                          └─────────────────┘
```

---

## 二、环境规划

| 节点 | 主机名 | IP | 端口 | 角色 |
|------|--------|-----|------|------|
| 节点 A | kfs-node-a | 192.168.1.101 | 54321 | 双向同步节点 |
| 节点 B | kfs-node-b | 192.168.1.102 | 54321 | 双向同步节点 |

---

## 三、数据库配置（双向）

### 3.1 两个节点都需要配置

```sql
-- 在两个节点都执行：
-- 1. 创建复制用户
CREATE USER repl_user WITH REPLICATION PASSWORD 'repl_password';
GRANT CONNECT ON DATABASE test TO repl_user;

-- 2. 授予必要权限
GRANT USAGE ON SCHEMA public TO repl_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO repl_user;
GRANT TRUNCATE, REFERENCES ON ALL TABLES IN SCHEMA public TO repl_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO repl_user;
```

### 3.2 kingbase.conf 配置（两个节点）

```bash
# 两个节点都需要配置
cat >> /data/kingbase/data/kingbase.conf << 'EOF'

# === 双轨同步参数 ===
wal_level = replica
max_wal_senders = 10
max_replication_slots = 10
wal_keep_size = 2GB
hot_standby = on
max_slot_wal_keep_size = 2GB
archive_mode = on
archive_command = 'test ! -f /data/kingbase/wal/%f && cp %p /data/kingbase/wal/%f'

# === 同步相关 ===
synchronous_commit = on_read_applies  # 异步提交可提高性能
EOF

./sys_monitor reload -D /data/kingbase/data
```

### 3.3 pg_hba.conf 配置（两个节点）

```bash
# 节点 A
cat >> /data/kingbase/data/pg_hba.conf << 'EOF'
# 双轨同步 - 来自节点 B 的连接
host    replication     repl_user     192.168.1.102/32    scram-sha-256
host    test           repl_user     192.168.1.102/32    scram-sha-256
EOF

# 节点 B
cat >> /data/kingbase/data/pg_hba.conf << 'EOF'
# 双轨同步 - 来自节点 A 的连接
host    replication     repl_user     192.168.1.101/32    scram-sha-256
host    test           repl_user     192.168.1.101/32    scram-sha-256
EOF

# 两个节点都重载
./sys_monitor reload -D /data/kingbase/data
```

---

## 四、KFS 双轨配置

### 4.1 节点 A 配置

```bash
mkdir -p /opt/kingbase-flysync/data/node_a
mkdir -p /opt/kingbase-flysync/conf

cat > /opt/kingbase-flysync/conf/node_a.properties << 'EOF'
# === 基本配置 ===
service.name=node_a_service
role=master

# === 源端配置（到 Node B） ===
flysync.source.type=kingbase
flysync.source.host=192.168.1.101
flysync.source.port=54321
flysync.source.database=test
flysync.source.user=system
flysync.source.password=your_password_a

# === 目标端配置（来自 Node B 的数据） ===
flysync.target.type=kingbase
flysync.target.host=192.168.1.101
flysync.target.port=54321
flysync.target.database=test
flysync.target.user=system
flysync.target.password=your_password_a

# === 双轨模式 ===
sync.mode=dual_rail
sync.peer=node_b_service
sync.peer.uri=192.168.1.102:54321

# === 复制槽 ===
replication.slots=true
replication.slot.name=flysync_node_a_slot
replication.peer.slot.name=flysync_node_b_slot

# === 过滤规则 ===
replicate.do.db=test
sync.tables=test.public.*

# === 冲突处理 ===
conflict.strategy=last_update_wins
conflict.handling=continue

# === 性能优化 ===
replication.parallelism=4
replication.batchSize=1000

# === 日志 ===
log.dir=/opt/kingbase-flysync/logs
log.level=INFO
EOF
```

### 4.2 节点 B 配置

```bash
mkdir -p /opt/kingbase-flysync/data/node_b

cat > /opt/kingbase-flysync/conf/node_b.properties << 'EOF'
# === 基本配置 ===
service.name=node_b_service
role=master

# === 源端配置（到 Node A） ===
flysync.source.type=kingbase
flysync.source.host=192.168.1.102
flysync.source.port=54321
flysync.source.database=test
flysync.source.user=system
flysync.source.password=your_password_b

# === 目标端配置（来自 Node A 的数据） ===
flysync.target.type=kingbase
flysync.target.host=192.168.1.102
flysync.target.port=54321
flysync.target.database=test
flysync.target.user=system
flysync.target.password=your_password_b

# === 双轨模式 ===
sync.mode=dual_rail
sync.peer=node_a_service
sync.peer.uri=192.168.1.101:54321

# === 复制槽 ===
replication.slots=true
replication.slot.name=flysync_node_b_slot
replication.peer.slot.name=flysync_node_a_slot

# === 过滤规则 ===
replicate.do.db=test
sync.tables=test.public.*

# === 冲突处理 ===
conflict.strategy=last_update_wins
conflict.handling=continue

# === 性能优化 ===
replication.parallelism=4
replication.batchSize=1000

# === 日志 ===
log.dir=/opt/kingbase-flysync/logs
log.level=INFO
EOF
```

### 4.3 创建复制槽（两个节点都执行）

```sql
-- 节点 A
SELECT * FROM sys_create_physical_replication_slot('flysync_node_a_slot', true);
SELECT * FROM sys_create_physical_replication_slot('flysync_node_b_slot', true);

-- 节点 B
SELECT * FROM sys_create_physical_replication_slot('flysync_node_a_slot', true);
SELECT * FROM sys_create_physical_replication_slot('flysync_node_b_slot', true);
```

---

## 五、启动双轨同步

### 5.1 初始化服务

```bash
# 节点 A 初始化
/opt/kingbase-flysync/bin/flysync init \
  -conf /opt/kingbase-flysync/conf/node_a.properties \
  -dir /opt/kingbase-flysync/data/node_a

# 节点 B 初始化
/opt/kingbase-flysync/bin/flysync init \
  -conf /opt/kingbase-flysync/conf/node_b.properties \
  -dir /opt/kingbase-flysync/data/node_b
```

### 5.2 启动服务

```bash
# 节点 A 启动
/opt/kingbase-flysync/bin/flysync start \
  -conf /opt/kingbase-flysync/conf/node_a.properties \
  -dir /opt/kingbase-flysync/data/node_a

# 节点 B 启动
/opt/kingbase-flysync/bin/flysync start \
  -conf /opt/kingbase-flysync/conf/node_b.properties \
  -dir /opt/kingbase-flysync/data/node_b

# 等待服务启动（通常需要 10-30 秒）
sleep 30
```

---

## 六、验证双轨同步

### 6.1 查看同步状态

```bash
# 节点 A 状态
/opt/kingbase-flysync/bin/flysync status -dir /opt/kingbase-flysync/data/node_a

# 节点 B 状态
/opt/kingbase-flysync/bin/flysync status -dir /opt/kingbase-flysync/data/node_b

# 查看详细状态
/opt/kingbase-flysync/bin/flysync status -dir /opt/kingbase-flysync/data/node_a -format json
```

### 6.2 双向数据测试

```sql
-- 节点 A 插入测试数据
\c test
INSERT INTO dual_test (id, name, node_flag) VALUES (1, 'from_node_a', 'A');

-- 节点 B 插入测试数据
\c test
INSERT INTO dual_test (id, name, node_flag) VALUES (2, 'from_node_b', 'B');

-- 等待几秒后，在两个节点都查询
SELECT * FROM dual_test ORDER BY id;
-- 两个节点都应该看到两条记录
```

### 6.3 查看同步延迟

```bash
# 查看两个方向的同步延迟
/opt/kingbase-flysync/bin/flysync check -dir /opt/kingbase-flysync/data/node_a
/opt/kingbase-flysync/bin/flysync check -dir /opt/kingbase-flysync/data/node_b
```

---

## 七、冲突处理策略

### 7.1 冲突类型

| 冲突类型 | 说明 | 默认策略 |
|---------|------|---------|
| UPDATE-UPDATE | 两边同时更新同一行 | last_update_wins |
| INSERT-INSERT | 两边插入主键相同的记录 | source_wins |
| DELETE-UPDATE | 一边删除一边更新 | source_wins |

### 7.2 配置冲突处理

```bash
# 推荐配置 - 以时间戳为准
cat >> /opt/kingbase-flysync/conf/node_a.properties << 'EOF'

# === 冲突处理（高级）===
conflict.strategy=last_update_wins
conflict.column=last_update_time
conflict.ignore.columns=created_by,created_time
conflict.logging=true
conflict.log.dir=/opt/kingbase-flysync/logs/conflicts
EOF
```

### 7.3 查看冲突日志

```bash
# 查看冲突记录
cat /opt/kingbase-flysync/logs/conflicts/*.csv

# 分析冲突
# 冲突日志格式：
# timestamp,table,conflict_type,key,node_a_value,node_b_value,winner
```

---

## 八、故障切换

### 8.1 节点 A 故障，切换到节点 B

```bash
# 1. 停止节点 A 的 KFS（如果还能访问）
/opt/kingbase-flysync/bin/flysync stop -dir /opt/kingbase-flysync/data/node_a

# 2. 在节点 B 提升为主（如果需要）
# KingbaseES 端需要切换角色

# 3. 更新节点 B 配置为单向同步（临时）
cat > /opt/kingbase-flysync/conf/node_b_single.properties << 'EOF'
service.name=node_b_service
role=master
flysync.source.type=kingbase
flysync.source.host=192.168.1.102
flysync.source.port=54321
flysync.source.database=test
flysync.source.user=system
flysync.source.password=your_password_b

# 暂时禁用来自 A 的同步
sync.mode=none
EOF

# 4. 重启节点 B
/opt/kingbase-flysync/bin/flysync restart -conf /opt/kingbase-flysync/conf/node_b_single.properties -dir /opt/kingbase-flysync/data/node_b
```

### 8.2 节点恢复后重新同步

```bash
# 1. 节点 A 恢复后，以节点 A 为源端重新初始化
/opt/kingbase-flysync/bin/flysync init \
  -conf /opt/kingbase-flysync/conf/node_a.properties \
  -dir /opt/kingbase-flysync/data/node_a

# 2. 恢复双轨模式
/opt/kingbase-flysync/bin/flysync restart \
  -conf /opt/kingbase-flysync/conf/node_a.properties \
  -dir /opt/kingbase-flysync/data/node_a

# 3. 验证数据一致性
```

---

## 九、高级配置

### 9.1 性能调优

```bash
# 高性能配置
cat > /opt/kingbase-flysync/conf/node_a.properties << 'EOF'
# === 性能优化 ===
replication.parallelism=8
replication.batchSize=5000
replication.bufferSize=64MB
replication.compress=true
replication.compressLevel=3

# 网络优化
sync.network.maxRate=100MB

# 内存优化
sync.memory.maxSize=2GB
EOF
```

### 9.2 过滤规则

```bash
# 只同步特定表
cat >> /opt/kingbase-flysync/conf/node_a.properties << 'EOF'

# === 表过滤 ===
sync.tables=test.public.orders
sync.tables=test.public.customers
sync.tables=test.public.products

# 排除特定表
sync.ignore.tables=test.public.tmp_*
sync.ignore.tables=test.public.log_*
EOF
```

---

## 十、常见问题

### 10.1 循环同步导致数据翻倍

```
症状：数据在两个节点之间不断复制，数量翻倍
原因：缺少过滤规则或同步配置错误
解决：
  1. 检查 sync.tables 配置
  2. 确保排除临时表和日志表
  3. 确认 replication.slots 正常工作
```

### 10.2 冲突过多

```
症状：冲突日志快速增长
原因：两个节点同时修改同一批数据
解决：
  1. 应用层做拆分：不同节点处理不同表
  2. 使用序列或唯一ID生成器避免主键冲突
  3. 配置合理的冲突处理策略
```

### 10.3 网络中断后无法恢复

```bash
# 检查复制槽状态
# 节点 A：
SELECT slot_name, active, restart_lsn FROM sys_replication_slots;

# 节点 B：
SELECT slot_name, active, restart_lsn FROM sys_replication_slots;

# 如果 slot inactive，需要重新创建并同步
```
