# KingbaseES V9R2C14 KDTS 全量迁移操作流程

> 适用版本：KingbaseES V9R2C14
> 参考：https://docs.kingbase.com.cn/cn/KES-V9R2C14/migration/

---

## 一、KDTS 概述

KDTS（Kingbase Data Transfer Studio）是金仓提供的数据迁移工具，支持从多种数据库（如 Oracle、MySQL、PostgreSQL、SQL Server 等）迁移到 KingbaseES。

### 1.1 KDTS 迁移模式

| 模式 | 说明 | 数据量 |
|------|------|--------|
| **全量迁移** | 一次性迁移所有数据 | 适合数据量较小场景 |
| **增量迁移** | 支持增量数据同步 | 适合数据量大、需持续同步场景 |
| **双向同步** | 支持双向数据同步 | 适合双写场景 |

### 1.2 支持的源数据库

- Oracle
- MySQL / MariaDB
- PostgreSQL
- SQL Server
- DM（达梦）
- KingbaseES（异机迁移/版本升级）

---

## 二、环境准备

### 2.1 KDTS 安装

```bash
# KDTS 通常独立安装，解压到指定目录
cd /opt
tar -xzf KDTS_V9R2C14_Linux.tar.gz
cd KDTS

# 查看目录结构
ls -la
# bin/       包含启动脚本
# lib/       依赖库
# jdbc/      各数据库 JDBC 驱动
# plugins/   插件
# doc/       文档
```

### 2.2 配置环境变量

```bash
# ~/.bash_profile
cat >> ~/.bash_profile << 'EOF'
export KDTS_HOME=/opt/KDTS
export PATH=$KDTS_HOME/bin:$PATH
EOF

source ~/.bash_profile
```

### 2.3 检查 JDK

```bash
# KDTS 需要 JDK 1.8+
java -version

# 如果没有，安装 JDK
# yum install -y java-1.8.0-openjdk java-1.8.0-openjdk-devel
```

---

## 三、KDTS Web 界面迁移（全量迁移）

### 3.1 启动 KDTS 服务

```bash
cd /opt/KDTS/bin

# 启动 KDTS（默认端口 8080）
./kdts_server.sh start

# 或者指定端口
./kdts_server.sh start -port 8888

# 检查启动状态
./kdts_server.sh status

# 查看日志
tail -f /opt/KDTS/logs/kdts.log
```

### 3.2 访问 KDTS Web 界面

```
浏览器访问：http://<服务器IP>:8080/kdts
默认用户名：admin
默认密码：admin
```

### 3.3 创建迁移项目

#### 步骤 1：新建项目

1. 登录 KDTS Web 界面
2. 点击「新建项目」
3. 输入项目名称（如 `oracle_to_kingbase`）
4. 选择迁移类型：`全量迁移`

#### 步骤 2：配置源端（Oracle）

```
源端类型：Oracle
连接信息：
  - 主机：oracle-server
  - 端口：1521
  - 数据库/SID：ORCL
  - 用户名：source_user
  - 密码：source_password
```

#### 步骤 3：配置目标端（KingbaseES）

```
目标端类型：KingbaseES
连接信息：
  - 主机：kes-server
  - 端口：54321
  - 数据库：target_db
  - 用户名：system
  - 密码：******
```

#### 步骤 4：选择迁移对象

1. 点击「选择对象」
2. 选择需要迁移的 Schema（用户）
3. 选择需要迁移的表
4. 检查字段映射

#### 步骤 5：配置迁移规则

| 配置项 | 建议值 |
|-------|-------|
| 批量大小 | 1000-5000 |
| 并行度 | 4-8 |
| 空值处理 | 保持原值 |
| 字符集转换 | 根据实际配置 |
| 表空间映射 | 提前创建目标表空间 |

#### 步骤 6：执行迁移

1. 点击「开始迁移」
2. 监控迁移进度
3. 查看迁移日志
4. 验证迁移结果

---

## 四、KDTS 命令行迁移

### 4.1 准备迁移配置文件

```bash
cat > /opt/KDTS/conf/migration_oracle_to_kes.json << 'EOF'
{
    "name": "oracle_to_kingbase",
    "type": "FULL",
    "source": {
        "dbType": "ORACLE",
        "host": "oracle-server",
        "port": 1521,
        "database": "ORCL",
        "username": "source_user",
        "password": "source_password",
        "schema": "SOURCE_SCHEMA"
    },
    "target": {
        "dbType": "KINGBASE",
        "host": "kes-server",
        "port": 54321,
        "database": "target_db",
        "username": "system",
        "password": "target_password",
        "schema": "public"
    },
    "options": {
        "batchSize": 2000,
        "parallel": 4,
        "skipLob": false,
        "skipIndex": false,
        "tableSpaceMap": {}
    },
    "objects": [
        {
            "type": "TABLE",
            "name": ".*",
            "action": "MIGRATE"
        }
    ]
}
EOF
```

### 4.2 执行迁移

```bash
cd /opt/KDTS/bin

# 执行迁移
./kdts_cli.sh -c /opt/KDTS/conf/migration_oracle_to_kes.json

# 查看帮助
./kdts_cli.sh -h
```

---

## 五、迁移后数据校验

### 5.1 记录数校验

```sql
-- 源端（Oracle）
SELECT table_name, num_rows FROM user_tables ORDER BY table_name;

-- 目标端（KingbaseES）
SELECT schemaname, tablename, n_live_tup
FROM sys_stat_user_tables
ORDER BY tablename;

-- 对比
-- 确保所有表记录数一致
```

### 5.2 数据内容校验

```sql
-- 抽样校验：对比关键表的 sum、count
-- Oracle 端：
SELECT COUNT(*) FROM source_table WHERE some_condition;
SELECT SUM(amount) FROM source_table;

-- KingbaseES 端：
SELECT COUNT(*) FROM target_table WHERE some_condition;
SELECT SUM(amount) FROM target_table;
```

### 5.3 生成校验报告

```bash
# KDTS 通常提供数据校验功能
# 在 Web 界面选择「数据校验」功能
# 或使用命令行

cd /opt/KDTS/bin
./kdts_cli.sh -c /opt/KDTS/conf/migration_oracle_to_kes.json -v
```

---

## 六、常见问题

### 6.1 连接失败

```bash
# 1. 检查网络连通性
ping oracle-server
ping kes-server

# 2. 检查端口
nc -zv oracle-server 1521
nc -zv kes-server 54321

# 3. 检查用户名密码
# 4. 检查防火墙
```

### 6.2 字符集问题

```bash
# 源端和目标端字符集不一致可能导致乱码
# 检查源端字符集
# Oracle: SELECT * FROM NLS_DATABASE_PARAMETERS WHERE PARAMETER='NLS_CHARACTERSET';
# MySQL: show variables like 'character%';

# 配置 KDTS 字符集转换规则
# 通常选择：源端字符集 -> UTF8 -> KingbaseES
```

### 6.3 大字段迁移

```sql
-- 如果表包含 BLOB/CLOB 等大字段，可能需要单独处理
-- 在迁移配置中设置：
# "skipLob": false    # 包含 LOB 类型
# "lobBatchSize": 100  # LOB 批次大小
```

### 6.4 迁移性能优化

| 参数 | 说明 | 建议 |
|------|------|------|
| `batchSize` | 每批次提交记录数 | 1000-5000 |
| `parallel` | 并行迁移任务数 | 4-8（根据 CPU 核心数） |
| `fetchSize` | 每次从源库读取记录数 | 1000-5000 |

---

## 七、迁移后操作

### 7.1 重建索引

```sql
-- 迁移可能跳过了索引，需要手动重建
-- 检查缺失索引
-- 对比源端和目标端的索引定义

-- 重建所有索引
REINDEX DATABASE target_db;

-- 或重建特定表索引
REINDEX TABLE my_table;
```

### 7.2 收集统计信息

```sql
-- 迁移后需要重新 ANALYZE 表
ANALYZE VERBOSE;

-- 对所有表执行 ANALYZE
-- 可以使用 psql 的 analyzedb 脚本或手动执行
```

### 7.3 验证约束

```sql
-- 检查外键约束
SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY';
```

---

## 八、KDTS 参数说明

```json
{
    "name": "项目名称",
    "type": "FULL | INCREMENT | SYNC",
    "source": {
        "dbType": "ORACLE | MYSQL | PG | SQLSERVER | DM | KINGBASE",
        "host": "主机地址",
        "port": 端口,
        "database": "数据库名",
        "username": "用户名",
        "password": "密码",
        "schema": "Schema名"
    },
    "target": {
        "dbType": "目标数据库类型",
        "host": "目标主机",
        "port": 目标端口,
        "database": "目标数据库",
        "username": "目标用户",
        "password": "目标密码",
        "schema": "目标Schema"
    },
    "options": {
        "batchSize": 2000,         // 每批次记录数
        "parallel": 4,             // 并行度
        "skipLob": false,          // 是否跳过LOB字段
        "skipIndex": false,        // 是否跳过索引
        "skipTrigger": false,      // 是否跳过触发器
        "characterSet": "UTF8",    // 字符集转换
        "dateFormat": "",          // 日期格式转换
        "tableSpaceMap": {}        // 表空间映射
    },
    "objects": [
        {
            "type": "TABLE | VIEW | SEQUENCE | PROCEDURE | FUNCTION | TRIGGER",
            "name": "对象名(支持正则)",
            "action": "MIGRATE | SKIP"
        }
    ]
}
```
