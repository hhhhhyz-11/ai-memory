# KingbaseES V9R2C14 KDTS 全量迁移

> 本文档介绍使用 KDTS（Kingbase Data Transfer Studio）工具进行全量数据迁移的操作流程。

---

## 一、KDTS 概述

### 1.1 KDTS 简介

KDTS（Kingbase Data Transfer Studio）是金仓提供的数据迁移工具，支持：
- 全量数据迁移
- 增量数据迁移（CDC 模式）
- 多种数据库源支持（Oracle、MySQL、PostgreSQL、SQL Server 等）
- 表结构迁移
- 数据迁移校验

### 1.2 KDTS 组件

| 组件 | 说明 |
|------|------|
| KDTS Server | 迁移服务主进程 |
| KDTS Console | 图形化控制台（可选） |
| KDTS CLI | 命令行迁移工具 |
| KDTS Agent | 远程代理（分布式部署） |

---

## 二、环境准备

### 2.1 检查 KDTS 安装

```bash
# 检查 KDTS 是否已安装
ls -la $KINGBASE_HOME/../KDTS/
ls -la $KINGBASE_HOME/../kdts/

# 或者
find /opt -name "*kdts*" -type d 2>/dev/null

# 检查版本
$KINGBASE_HOME/../kdts/bin/kdts --version
```

### 2.2 系统要求

| 项目 | 要求 |
|------|------|
| JDK | JDK 8 或 JDK 11 |
| 内存 | 建议 4GB 以上 |
| 磁盘 | 临时目录需要足够空间 |
| 网络 | 源端和目标端互通 |

### 2.3 创建迁移用户

```sql
-- 在目标库创建迁移专用用户
CREATE USER kdts_user WITH PASSWORD 'KdtsPassword123';
GRANT CONNECT ON DATABASE test TO kdts_user;
GRANT CREATE ON DATABASE test TO kdts_user;
GRANT ALL PRIVILEGES ON SCHEMA public TO kdts_user;

-- 如果迁移特定表空间
GRANT ALL PRIVILEGES ON TABLESPACE your_tablespace TO kdts_user;
```

---

## 三、KDTS 全量迁移步骤

### 3.1 启动 KDTS 服务

```bash
# 进入 KDTS 安装目录
cd $KINGBASE_HOME/../kdts

# 启动 KDTS 服务
bin/kdts-server.sh start

# 查看服务状态
bin/kdts-server.sh status

# 查看日志
tail -f logs/kdts.log
```

### 3.2 KDTS 配置文件

```bash
# 创建迁移配置文件
vim /opt/kdts_jobs/migration_job.json

{
    "job": {
        "name": "oracle_to_kingbase_full",
        "type": "FULL",
        "source": {
            "type": "ORACLE",
            "host": "192.168.1.10",
            "port": 1521,
            "database": "ORCL",
            "schema": "SOURCE_USER",
            "username": "source_user",
            "password": "SourcePassword123",
            "tables": ["*"]
        },
        "target": {
            "type": "KINGBASE",
            "host": "192.168.1.100",
            "port": 54321,
            "database": "test",
            "schema": "public",
            "username": "kdts_user",
            "password": "KdtsPassword123"
        },
        "options": {
            "parallel": 4,
            "batchSize": 10000,
            "commitSize": 50000,
            "skipErrors": true,
            "createTable": true,
            "truncateBeforeInsert": false
        }
    }
}
```

### 3.3 启动 KDTS Console（可选）

```bash
# 如果使用图形化界面
cd $KINGBASE_HOME/../kdts
bin/kdts-console.sh

# 或者
java -jar kdts-console.jar
```

### 3.4 命令行执行迁移

```bash
# 执行迁移任务
cd $KINGBASE_HOME/../kdts
bin/kdts-cli.sh -config /opt/kdts_jobs/migration_job.json

# 或使用简写
bin/kdts -c /opt/kdts_jobs/migration_job.json

# 后台执行
nohup bin/kdts-cli.sh -config /opt/kdts_jobs/migration_job.json > /var/log/kdts_migration.log 2>&1 &

# 查看执行状态
bin/kdts-cli.sh -status

# 查看迁移进度
bin/kdts-cli.sh -progress
```

---

## 四、不同数据源迁移示例

### 4.1 Oracle 迁移到 KingbaseES

```bash
# 创建 Oracle 迁移配置
cat > /opt/kdts_jobs/oracle_to_kingbase.json << 'EOF'
{
    "job": {
        "name": "oracle_to_kingbase",
        "type": "FULL",
        "source": {
            "type": "ORACLE",
            "host": "192.168.1.10",
            "port": 1521,
            "serviceName": "ORCL",
            "username": "SRC_USER",
            "password": "SrcPassword123",
            "tables": ["EMP", "DEPT", "SALGRADE"],
            "excludeTables": ["BIN$*"]
        },
        "target": {
            "type": "KINGBASE",
            "host": "192.168.1.100",
            "port": 54321,
            "database": "test",
            "username": "kdts_user",
            "password": "KdtsPassword123"
        },
        "options": {
            "parallel": 4,
            "batchSize": 5000,
            "createTable": true,
            "dataTypeMapping": {
                "CLOB": "TEXT",
                "BLOB": "BYTEA",
                "DATE": "TIMESTAMP"
            }
        }
    }
}
EOF

# 执行
bin/kdts-cli.sh -config /opt/kdts_jobs/oracle_to_kingbase.json
```

### 4.2 MySQL 迁移到 KingbaseES

```bash
cat > /opt/kdts_jobs/mysql_to_kingbase.json << 'EOF'
{
    "job": {
        "name": "mysql_to_kingbase",
        "type": "FULL",
        "source": {
            "type": "MYSQL",
            "host": "192.168.1.20",
            "port": 3306,
            "database": "source_db",
            "username": "root",
            "password": "MysqlPassword123"
        },
        "target": {
            "type": "KINGBASE",
            "host": "192.168.1.100",
            "port": 54321,
            "database": "test",
            "username": "kdts_user",
            "password": "KdtsPassword123"
        },
        "options": {
            "parallel": 4,
            "batchSize": 10000
        }
    }
}
EOF

bin/kdts-cli.sh -config /opt/kdts_jobs/mysql_to_kingbase.json
```

### 4.3 PostgreSQL 迁移到 KingbaseES

```bash
cat > /opt/kdts_jobs/pg_to_kingbase.json << 'EOF'
{
    "job": {
        "name": "pg_to_kingbase",
        "type": "FULL",
        "source": {
            "type": "POSTGRESQL",
            "host": "192.168.1.30",
            "port": 5432,
            "database": "source_pg",
            "username": "postgres",
            "password": "PgPassword123"
        },
        "target": {
            "type": "KINGBASE",
            "host": "192.168.1.100",
            "port": 54321,
            "database": "test",
            "username": "kdts_user",
            "password": "KdtsPassword123"
        }
    }
}
EOF

bin/kdts-cli.sh -config /opt/kdts_jobs/pg_to_kingbase.json
```

### 4.4 KingbaseES 同版本迁移

```bash
# KingbaseES 到 KingbaseES 迁移
cat > /opt/kdts_jobs/kingbase_to_kingbase.json << 'EOF'
{
    "job": {
        "name": "kingbase_to_kingbase",
        "type": "FULL",
        "source": {
            "type": "KINGBASE",
            "host": "192.168.1.50",
            "port": 54321,
            "database": "old_db",
            "username": "system",
            "password": "OldPassword123"
        },
        "target": {
            "type": "KINGBASE",
            "host": "192.168.1.100",
            "port": 54321,
            "database": "new_db",
            "username": "system",
            "password": "NewPassword123"
        },
        "options": {
            "parallel": 8,
            "batchSize": 20000,
            "createTable": true,
            "copyIndexes": true,
            "copyConstraints": true,
            "copyTriggers": true
        }
    }
}
EOF

bin/kdts-cli.sh -config /opt/kdts_jobs/kingbase_to_kingbase.json
```

---

## 五、迁移监控与日志

### 5.1 查看迁移状态

```bash
# 查看所有迁移任务状态
bin/kdts-cli.sh -list

# 查看特定任务详细状态
bin/kdts-cli.sh -status -job oracle_to_kingbase

# 查看进度
bin/kdts-cli.sh -progress -job oracle_to_kingbase
```

### 5.2 查看迁移日志

```bash
# KDTS 日志目录
ls -la $KINGBASE_HOME/../kdts/logs/

# 实时查看日志
tail -f $KINGBASE_HOME/../kdts/logs/kdts.log

# 查看错误日志
grep -i error $KINGBASE_HOME/../kdts/logs/kdts.log

# 查看特定任务的日志
tail -f $KINGBASE_HOME/../kdts/logs/kdts_job_oracle_to_kingbase.log
```

### 5.3 迁移性能监控 SQL

```sql
-- 监控目标库数据增长
SELECT 
    schemaname,
    relname,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_live_tup,
    n_dead_tup,
    last_vacuum,
    last_autovacuum,
    last_analyze
FROM sys_stat_user_tables
ORDER BY n_tup_ins DESC;

-- 查看迁移表的记录数
SELECT 
    schemaname,
    relname,
    n_live_tup
FROM sys_stat_user_tables
WHERE relname IN ('emp', 'dept', 'salgrade')
ORDER BY relname;
```

---

## 六、数据校验

### 6.1 记录数校验

```bash
# 创建校验脚本
cat > /opt/kdts_jobs/verify_data.sh << 'EOF'
#!/bin/bash

SOURCE_CONN="system/SourcePassword123@192.168.1.10:1521/ORCL"
TARGET_CONN="-U kdts_user -d test -h 192.168.1.100 -p 54321"

TABLES=("EMP" "DEPT" "SALGRADE")

echo "=== 数据校验开始 ==="
echo "时间: $(date)"

for TABLE in "${TABLES[@]}"; do
    # 源端记录数
    SRC_COUNT=$(sqlplus -s $SOURCE_CONN << EOF | grep -v "^$" | tail -1
SET HEADING OFF
SET FEEDBACK OFF
SELECT COUNT(*) FROM ${TABLE};
EOF
)
    
    # 目标端记录数
    TGT_COUNT=$(ksql $TARGET_CONN -t -c "SELECT COUNT(*) FROM ${TABLE};")
    
    echo "表: $TABLE | 源端: $SRC_COUNT | 目标端: $TGT_COUNT"
    
    if [ "$SRC_COUNT" != "$TGT_COUNT" ]; then
        echo "⚠️  记录数不匹配!"
    else
        echo "✓ 记录数匹配"
    fi
done

echo "=== 校验完成 ==="
EOF

chmod +x /opt/kdts_jobs/verify_data.sh
```

### 6.2 KDTS 内置校验

```bash
# 使用 KDTS 校验功能
cat > /opt/kdts_jobs/verify_job.json << 'EOF'
{
    "job": {
        "name": "verify_job",
        "type": "VERIFY",
        "source": {
            "type": "KINGBASE",
            "host": "192.168.1.50",
            "port": 54321,
            "database": "old_db",
            "username": "system",
            "password": "OldPassword123"
        },
        "target": {
            "type": "KINGBASE",
            "host": "192.168.1.100",
            "port": 54321,
            "database": "test",
            "username": "system",
            "password": "NewPassword123"
        },
        "options": {
            "verifyMode": "FULL",
            "tolerance": 0
        }
    }
}
EOF

bin/kdts-cli.sh -config /opt/kdts_jobs/verify_job.json
```

---

## 七、常见问题

### 7.1 连接失败

**错误**：`Connection refused` 或 `Unable to connect`

**解决**：
```bash
# 检查目标数据库是否运行
ps -ef | grep kingbase | grep -v grep

# 检查端口
netstat -tlnp | grep 54321

# 测试连接
ksql -U kdts_user -d test -h 192.168.1.100 -p 54321 -c "SELECT 1;"
```

### 7.2 表不存在

**错误**：`Table not found` 或 `relation does not exist`

**解决**：
1. 检查源端表名大小写
2. 检查 schema 是否正确
3. 确认用户有访问权限

### 7.3 字符集不兼容

**错误**：`character set conversion failed`

**解决**：
```bash
# 在 kingbase.conf 中配置字符集
vim $KINGBASE_DATA/kingbase.conf
# client_encoding = UTF8
# server_encoding = UTF8

# 或在迁移配置中指定字符集映射
"dataTypeMapping": {
    "VARCHAR2": "VARCHAR"
}
```

### 7.4 内存不足

**错误**：`OutOfMemoryError` 或 `cannot allocate memory`

**解决**：
1. 减小 `batchSize` 参数
2. 减小 `parallel` 并行数
3. 增加服务器内存

---
