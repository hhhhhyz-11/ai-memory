# KingbaseES V9R2C14 KWR 巡检报告

> 本文档介绍 KWR（Kingbase Workload Repository）巡检报告的生成、配置和分析方法。

---

## 一、KWR 概述

### 1.1 KWR 简介

KWR 是 KingbaseES 的工作负载信息仓库，用于收集、存储和分析数据库性能统计数据，生成巡检报告。

### 1.2 KWR 功能

- 自动收集性能统计数据
- 生成数据库健康巡检报告
- 分析 SQL 性能趋势
- 检测数据库异常
- 提供优化建议

---

## 二、KWR 安装与配置

### 2.1 检查 KWR 安装

```bash
# 检查 KWR 是否已安装
ls -la $KINGBASE_HOME/../kwr/
ls -la /opt/KingbaseES/KWR/

# 或通过 SQL 检查
ksql -U system -d test -c "SELECT * FROM sys_available_extensions WHERE name LIKE '%wr%';"
```

### 2.2 创建 KWR 用户和扩展

```sql
-- 创建 KWR 管理用户
CREATE USER kwr_admin WITH PASSWORD 'KwrAdmin123';
GRANT CONNECT ON DATABASE test TO kwr_admin;
GRANT ALL PRIVILEGES ON SCHEMA sys_wrr TO kwr_admin;

-- 创建 KWR 扩展
CREATE EXTENSION IF NOT EXISTS sys_workload_repository;

-- 验证扩展创建
SELECT extname, extversion FROM sys_extension WHERE extname = 'sys_workload_repository';
```

### 2.3 初始化 KWR

```bash
# 创建 KWR 表空间（可选）
CREATE TABLESPACE kwr_tablespace LOCATION '/data/kingbase/kwr';

# 初始化 KWR
$KINGBASE_HOME/bin/sys_wrr_control.sh init

# 或通过 SQL
ksql -U system -d test -c "SELECT sys_wrr_init();"
```

---

## 三、KWR 配置

### 3.1 配置参数

```bash
vim $KINGBASE_DATA/kingbase.conf

# ================== KWR 相关配置 ==================

# KWR 快照收集间隔（分钟）
sys_wrr.snapshot_interval = 60

# KWR 数据保留天数
sys_wrr.retention_days = 30

# KWR 自动分析
sys_wrr.auto_analysis = on

# KWR 统计收集级别
# 0 - minimal, 1 - basic, 2 - more, 3 - all
sys_wrr.stats_level = 1
```

### 3.2 重启生效

```bash
# 重启数据库使配置生效
sys_ctl -D $KINGBASE_DATA restart
```

---

## 四、KWR 快照管理

### 4.1 手动创建快照

```sql
-- 连接数据库
ksql -U system -d test

-- 手动创建快照
SELECT sys_wrr_snapshot();

-- 查看快照列表
SELECT 
    snapshot_id,
    snap_time,
    elapsed_time,
    db_stats
FROM sys_wrrsnapshots
ORDER BY snap_time DESC;
```

### 4.2 查看快照状态

```sql
-- 查看快照详情
SELECT * FROM sys_wrr_snapshots WHERE snapshot_id = 1;

-- 查看快照统计
SELECT 
    s.snapshot_id,
    s.snap_time,
    s.elapsed_time,
    d.database_name,
    d.num_connections
FROM sys_wrr_snapshots s
JOIN sys_wrr_database_stats d ON s.snapshot_id = d.snapshot_id
ORDER BY s.snap_time DESC;
```

### 4.3 自动快照任务

```bash
# 添加 crontab 定时任务
crontab -e

# 每小时创建一次快照
0 * * * * ksql -U system -d test -c "SELECT sys_wrr_snapshot();"

# 每天凌晨 2 点创建快照并生成报告
0 2 * * * /opt/scripts/kwr_daily_report.sh
```

---

## 五、生成巡检报告

### 5.1 命令行生成报告

```bash
# 生成文本格式报告
$KINGBASE_HOME/bin/sys_wrr_report.sh \
    --start-snapshot 1 \
    --end-snapshot 10 \
    --output /tmp/kwr_report.txt

# 生成 HTML 报告
$KINGBASE_HOME/bin/sys_wrr_report.sh \
    --start-snapshot 1 \
    --end-snapshot 10 \
    --format html \
    --output /tmp/kwr_report.html

# 生成指定时间范围的报告
$KINGBASE_HOME/bin/sys_wrr_report.sh \
    --start-time "2024-01-01 00:00:00" \
    --end-time "2024-01-07 23:59:59" \
    --output /tmp/kwr_report.html
```

### 5.2 SQL 生成报告

```sql
-- 生成简单报告
SELECT sys_wrr_report(
    start_snap_id => 1,
    end_snap_id => 10
);

-- 获取报告内容
SELECT sys_wrr_get_report(
    p_start_time => '2024-01-01 00:00:00'::timestamp,
    p_end_time => '2024-01-07 23:59:59'::timestamp
);
```

---

## 六、巡检报告内容解读

### 6.1 报告结构

```
KWR 巡检报告
├── 数据库概览
│   ├── 数据库版本
│   ├── 运行时间
│   ├── 连接数统计
│   └── 事务统计
├── 性能指标
│   ├── QPS/TPS
│   ├── 响应时间
│   ├── 并发数
│   └── 缓存命中率
├── SQL 分析
│   ├── Top SQL（按执行时间）
│   ├── Top SQL（按调用次数）
│   ├── 慢查询统计
│   └── 等待事件
├── 资源使用
│   ├── CPU 使用
│   ├── 内存使用
│   ├── 磁盘 I/O
│   └── 网络
├── 存储分析
│   ├── 表空间使用
│   ├── 表膨胀分析
│   └── 索引使用
└── 建议与优化
    ├── 性能建议
    ├── 配置建议
    └── SQL 优化建议
```

### 6.2 关键指标解读

| 指标 | 健康范围 | 说明 |
|------|---------|------|
| 缓存命中率 | > 90% | 低于此值可能需要调优 |
| 平均响应时间 | < 100ms | 取决于业务类型 |
| QPS | 根据业务量 | 持续下降需要关注 |
| 连接数使用率 | < 70% | 接近 max_connections 时需扩容 |
| 慢查询数量 | < 5% | 占比过高需优化 |
| 复制延迟 | < 1MB | 主备延迟过大会影响可用性 |

### 6.3 SQL 分析

```sql
-- 查看 Top SQL（按总执行时间）
SELECT 
    queryid,
    calls,
    total_exec_time,
    mean_exec_time,
    rows,
    SUBSTRING(query, 1, 100) AS query_preview
FROM sys_wrr_sql_stats
WHERE snapshot_id BETWEEN 1 AND 10
ORDER BY total_exec_time DESC
LIMIT 10;

-- 查看 Top SQL（按调用次数）
SELECT 
    queryid,
    calls,
    total_exec_time,
    mean_exec_time,
    rows
FROM sys_wrr_sql_stats
WHERE snapshot_id BETWEEN 1 AND 10
ORDER BY calls DESC
LIMIT 10;

-- 查看慢查询统计
SELECT 
    queryid,
    min_exec_time,
    max_exec_time,
    mean_exec_time,
    stddev_exec_time,
    calls
FROM sys_wrr_sql_stats
WHERE snapshot_id BETWEEN 1 AND 10
AND mean_exec_time > 1000
ORDER BY mean_exec_time DESC;
```

---

## 七、巡检报告自动化

### 7.1 定时生成脚本

```bash
#!/bin/bash
# kwr_daily_report.sh - 每日巡检报告生成脚本

DATE=$(date +%Y%m%d)
REPORT_DIR="/var/reports/kwr"
LOG_FILE="/var/log/kwr_report.log"

mkdir -p $REPORT_DIR

echo "[$(date)] 开始生成巡检报告" >> $LOG_FILE

# 获取最近一天的快照 ID 范围
END_SNAP=$(ksql -U system -d test -t -c "SELECT MAX(snapshot_id) FROM sys_wrr_snapshots;")
START_SNAP=$(ksql -U system -d test -t -c "SELECT MIN(snapshot_id) FROM sys_wrr_snapshots WHERE snap_time > NOW() - INTERVAL '1 day';")

if [ -z "$START_SNAP" ] || [ -z "$END_SNAP" ]; then
    echo "[$(date)] 无可用快照" >> $LOG_FILE
    exit 1
fi

echo "[$(date)] 快照范围: $START_SNAP - $END_SNAP" >> $LOG_FILE

# 生成 HTML 报告
$KINGBASE_HOME/bin/sys_wrr_report.sh \
    --start-snapshot $START_SNAP \
    --end-snapshot $END_SNAP \
    --format html \
    --output $REPORT_DIR/kwr_report_$DATE.html

# 生成摘要邮件
SUBJECT="[KEMCC] KingbaseES 巡检报告 - $DATE"
EMAIL_BODY=$(cat << EOF
数据库巡检报告已生成。

报告时间范围: $START_SNAP - $END_SNAP
报告文件: $REPORT_DIR/kwr_report_$DATE.html

请登录 KEMCC 控制台查看详细报告。
EOF
)

# 发送邮件（如果有邮件配置）
# echo "$EMAIL_BODY" | mail -s "$SUBJECT" dba@company.com

echo "[$(date)] 巡检报告生成完成" >> $LOG_FILE
```

### 7.2 Crontab 配置

```bash
# 添加定时任务
crontab -e

# 每天早上 8 点生成前一天的巡检报告
0 8 * * * /opt/scripts/kwr_daily_report.sh >> /var/log/kwr_report.log 2>&1

# 每周一早上 9 点生成周报
0 9 * * 1 /opt/scripts/kwr_weekly_report.sh >> /var/log/kwr_weekly.log 2>&1
```

---

## 八、常见问题

### 8.1 快照创建失败

**错误**：`ERROR: could not create snapshot`

**排查**：
```sql
-- 检查 KWR 扩展状态
SELECT * FROM sys_extension WHERE extname = 'sys_workload_repository';

-- 检查快照表空间
SELECT spcname FROM pg_tablespace WHERE spcname = 'kwr_tablespace';

-- 查看错误日志
SELECT * FROM sys_log WHERE message LIKE '%wrr%' ORDER BY log_time DESC;
```

### 8.2 报告生成慢

**原因**：快照数据量过大

**解决**：
1. 减少快照保留天数
2. 减小快照采集间隔
3. 只生成关键时间段的报告

### 8.3 报告数据为空

**排查**：
```sql
-- 检查是否有快照
SELECT COUNT(*) FROM sys_wrr_snapshots;

-- 检查快照数据
SELECT * FROM sys_wrr_snapshots LIMIT 1;

-- 检查统计收集是否开启
SHOW sys_wrr.stats_level;
```

---
