# KingbaseES V9R2C14 KFS 单向同步部署（初/中/高级）

> 适用版本：KingbaseES V9R2C14
> 参考：https://docs.kingbase.com.cn/cn/KES-V9R2C14/sync/

---

## 一、KFS 概述

KFS（Kingbase FlySync）是金仓提供的数据同步产品，支持：
- **单向同步**：源端到目标端的数据同步
- **双轨同步**：支持双向数据同步
- **多种同步模式**：同步复制、异步复制
- **断点续传**：支持网络中断后的续传

---

## 二、环境规划

| 角色 | 主机名 | IP | 端口 | 说明 |
|------|--------|-----|------|------|
| 源端 | kfs-source | 192.168.1.101 | 54321 | KingbaseES 主库 |
| 目标端 | kfs-target | 192.168.1.102 | 54321 | KingbaseES 备库 |

---

## 三、初级：安装与基础配置

### 3.1 安装 KFS

```bash
# 下载 KFS 安装包（以 kingbase-flysync-V9R2C14 为例）
cd /opt
tar -xzf kingbase-flysync-V9R2C14-linux.tar.gz
mv kingbase-flysync-V9R2C14 kingbase-flysync
cd kingbase-flysync

# 查看目录结构
ls -la
# bin/        KFS 命令
# conf/       配置文件
# lib/        依赖库
# tool/       工具
```

### 3.2 配置环境变量

```bash
# ~/.bash_profile
cat >> ~/.bash_profile << 'EOF'
export KFS_HOME=/opt/kingbase-flysync
export PATH=$KFS_HOME/bin:$PATH
EOF

source ~/.bash_profile
```

### 3.3 创建同步用户（源端）

```sql
-- 在源端数据库创建复制用户
CREATE USER repl_user WITH REPLICATION PASSWORD 'repl_password';
GRANT CONNECT ON DATABASE test TO repl_user;
GRANT USAGE ON SCHEMA public TO repl_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO repl_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO repl_user;
```

### 3.4 修改源端 kingbase.conf

```bash
cat >> /data/kingbase/data/kingbase.conf << 'EOF'

# === KFS 复制参数 ===
wal_level = replica
max_wal_senders = 10
max_replication_slots = 10
wal_keep_size = 2GB
hot_standby = on
archive_mode = on
archive_command = 'test ! -f /data/kingbase/wal/%f && cp %p /data/kingbase/wal/%f'
EOF

# 重载配置
./sys_monitor reload -D /data/kingbase/data
```

### 3.5 配置源端 pg_hba.conf

```bash
cat >> /data/kingbase/data/pg_hba.conf << 'EOF'
# KFS 复制连接
host    replication     repl_user     192.168.1.102/32    scram-sha-256
EOF

# 重载配置
./sys_monitor reload -D /data/kingbase/data
```

---

## 四、中级：配置同步服务

### 4.1 源端配置

```bash
cd /opt/kingbase-flysync
mkdir -p data/source

# 创建源端配置
cat > conf/源端.properties << 'EOF'
# === 源端配置 ===
flysync.source.keystore=/opt/kingbase-flysync/conf/源端.keystore
flysync.source.type=kingbase
flysync.source.host=192.168.1.101
flysync.source.port=54321
flysync.source.database=test
flysync.source.user=system
flysync.source.password=your_password
flysync.source.servicename=source_service

# === 服务名称 ===
service.name=source_service

# === 复制槽（可选）===
replication.slots=true
replication.slot.name=flysync_slot

# === 日志 ===
log.dir=/opt/kingbase-flysync/logs
EOF
```

### 4.2 目标端配置

```bash
cd /opt/kingbase-flysync
mkdir -p data/target

# 创建目标端配置
cat > conf/目标端.properties << 'EOF'
# === 目标端配置 ===
flysync.target.keystore=/opt/kingbase-flysync/conf/目标端.keystore
flysync.target.type=kingbase
flysync.target.host=192.168.1.102
flysync.target.port=54321
flysync.target.database=test
flysync.target.user=system
flysync.target.password=your_password
flysync.target.servicename=target_service

# === 服务名称 ===
service.name=target_service

# === KFS 目标端模式 ===
role=target
masterconnecturi=192.168.1.101:54321

# === 日志 ===
log.dir=/opt/kingbase-flysync/logs
EOF
```

### 4.3 初始化 KFS 服务

```bash
# 源端初始化
cd /opt/kingbase-flysync
bin/flysync init \
  -conf conf/源端.properties \
  -dir data/source

# 目标端初始化
bin/flysync init \
  -conf conf/目标端.properties \
  -dir data/target
```

### 4.4 启动 KFS 服务

```bash
# 源端启动
bin/flysync start \
  -conf conf/源端.properties \
  -dir data/source

# 目标端启动
bin/flysync start \
  -conf conf/目标端.properties \
  -dir data/target

# 查看状态
bin/flysync status -dir data/source
bin/flysync status -dir data/target
```

---

## 五、高级：同步参数调优

### 5.1 同步性能参数

```bash
# 高级配置 - 源端
cat > conf/源端.properties << 'EOF'
service.name=source_service
flysync.source.type=kingbase
flysync.source.host=192.168.1.101
flysync.source.port=54321
flysync.source.database=test
flysync.source.user=system
flysync.source.password=your_password

# === 性能优化 ===
replication.parallelism=4          # 并行复制线程数
replication.batchSize=1000        # 批处理大小
replication.bufferSize=10MB       # 缓冲区大小
replication.compress=true         # 是否压缩传输
replication.compressLevel=6      # 压缩级别

# === 过滤规则 ===
replicate.do.db=test              # 同步的数据库
replicate.ignore.db=postgres,sys_template  # 忽略的数据库

# === 过滤表（可选）===
# replicate.do.table=test.public.*
# replicate.ignore.table=test.public.log_*

# === 复制槽 ===
replication.slots=true
replication.slot.name=flysync_slot
replication.slot.keepalive=true

# === 日志 ===
log.dir=/opt/kingbase-flysync/logs
log.level=INFO
EOF
```

### 5.2 同步策略配置

```bash
# 断点续传配置
# 确保 replication.slots=true 已启用

# 目标端 - 故障切换配置
cat > conf/目标端.properties << 'EOF'
service.name=target_service
flysync.target.type=kingbase
flysync.target.host=192.168.1.102
flysync.target.port=54321
flysync.target.database=test
flysync.target.user=system
flysync.target.password=your_password

# === 角色 ===
role=target
masterconnecturi=192.168.1.101:54321

# === 断点续传 ===
replication.checkpoint.enabled=true
replication.checkpoint.interval=30

# === 自动重连 ===
reconnection.maxRetries=10
reconnection.retryInterval=30

# === 冲突处理 ===
conflict.strategy=source_wins    # 源端优先
# conflict.strategy=target_wins  # 目标端优先
# conflict.strategy=manual      # 手动处理

# === 日志 ===
log.dir=/opt/kingbase-flysync/logs
log.level=INFO
EOF
```

---

## 六、验证同步状态

### 6.1 查看同步状态

```bash
# KFS 服务状态
bin/flysync status -dir data/source
bin/flysync status -dir data/target

# 查看同步延迟
bin/flysync check -dir data/target

# 查看详细状态（JSON格式）
bin/flysync status -dir data/target -format json
```

### 6.2 数据库端验证

```sql
-- 源端：查看复制槽
SELECT slot_name, slot_type, active, restart_lsn
FROM sys_replication_slots
WHERE slot_name LIKE 'flysync%';

-- 源端：查看 wal 发送状态
SELECT pid, application_name, state, sent_lsn, write_lsn
FROM sys_stat_replication;

-- 目标端：查看同步进度
SELECT now(), pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn();
SELECT now(), pg_last_xact_replay_timestamp();
```

### 6.3 测试数据同步

```sql
-- 源端插入测试数据
INSERT INTO test_repl (id, name) VALUES (1, 'sync_test_' || now());

-- 目标端验证
SELECT * FROM test_repl ORDER BY id DESC LIMIT 5;
```

---

## 七、常见问题排查

### 7.1 同步延迟大

```
症状：目标端数据明显落后于源端
原因：网络带宽不足、目标端处理速度慢、并行度不够
```

**排查：**

```bash
# 查看 KFS 日志
tail -100 /opt/kingbase-flysync/logs/flysync-*.log

# 检查网络
iperf3 -c 192.168.1.102

# 检查目标端资源
top -H
iostat -x 1
```

**解决方案：**

```bash
# 1. 增加并行度
sed -i 's/replication.parallelism=.*/replication.parallelism=8/' conf/源端.properties

# 2. 增加批处理大小
sed -i 's/replication.batchSize=.*/replication.batchSize=5000/' conf/源端.properties

# 3. 重启服务
bin/flysync restart -dir data/source
```

### 7.2 复制槽不存在

```
ERROR: replication slot "flysync_slot" does not exist
```

**解决方案：**

```sql
-- 在源端手动创建复制槽
SELECT * FROM sys_create_physical_replication_slot('flysync_slot', true);

-- 或者禁用复制槽（不推荐，数据可能丢失）
-- 修改配置：replication.slots=false
```

### 7.3 同步中断后无法续传

```bash
# 1. 检查 KFS 状态
bin/flysync status -dir data/target

# 2. 查看错误日志
grep -i error /opt/kingbase-flysync/logs/flysync-*.log

# 3. 尝试恢复
bin/flysync recover -dir data/target

# 4. 如果无法恢复，需要重新初始化（会丢失中断期间的数据）
# 4.1 停止服务
bin/flysync stop -dir data/target

# 4.2 清除状态
rm -rf data/target

# 4.3 重新初始化
bin/flysync init -conf conf/目标端.properties -dir data/target
bin/flysync start -conf conf/目标端.properties -dir data/target
```

---

## 八、KFS 命令汇总

```bash
# 初始化
bin/flysync init -conf <配置文件> -dir <数据目录>

# 启动
bin/flysync start -conf <配置文件> -dir <数据目录>

# 停止
bin/flysync stop -dir <数据目录>

# 重启
bin/flysync restart -dir <数据目录>

# 状态查看
bin/flysync status -dir <数据目录>
bin/flysync status -dir <数据目录> -format json

# 健康检查
bin/flysync check -dir <数据目录>

# 恢复
bin/flysync recover -dir <数据目录>

# 同步进度
bin/flysync syncstatus -dir <数据目录>

# 帮助
bin/flysync help
```
