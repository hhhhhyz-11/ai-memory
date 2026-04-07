# KingbaseES V9R2C14 KWR / KBBadger 巡检报告输出

> 适用版本：KingbaseES V9R2C14
> 参考：https://docs.kingbase.com.cn/cn/KES-V9R2C14/perf/db-optimization/性能诊断/性能调优工具/

---

## 一、工具概述

| 工具 | 说明 | 用途 |
|------|------|------|
| **KWR** | KingbaseES Workload Report | 数据库整体性能分析报告 |
| **KBBadger** | 日志分析工具 | 分析慢查询日志，找出性能问题 SQL |

---

## 二、KWR 巡检报告

### 2.1 安装 KWR 扩展

```sql
-- 检查扩展是否已安装
SELECT * FROM sys_available_extensions WHERE name = 'sys_kwr';

-- 安装 KWR 扩展
CREATE EXTENSION IF NOT EXISTS sys_kwr;
```

### 2.2 配置 KWR 参数

```sql
-- kingbase.conf 中配置
-- shared_preload_libraries = 'sys_kwr'

-- KWR 相关参数
-- 可以在会话中设置：
SET sys_kwr.top_n = 20;           -- TOP N SQL 数量
SET sys_kwr.interval = '5 min';   -- 采样间隔
```

### 2.3 生成 KWR 报告

```sql
-- 创建一个 KWR 快照
SELECT sys_kwr_start(
    'snap_20260407_01',        -- 快照名称
    '测试报告',                 -- 描述
    '30 min'                   -- 采样时长
);

-- 查看当前快照
SELECT * FROM sys_kwr_list();

-- 或者手动控制开始和结束
SELECT sys_kwr_begin();
-- ... 运行负载测试 ...
SELECT sys_kwr_end('snap_20260407_02');
```

### 2.4 生成 HTML 报告

```sql
-- 生成文本格式报告
SELECT sys_kwr_report(
    'snap_20260407_01',
    'text'  -- 输出格式：text, html, csv
);

-- 或者使用函数生成报告
SELECT sys_kwr_show(
    'snap_20260407_01',
    'html'  -- 输出 HTML 格式
);
```

### 2.5 常用 KWR SQL 查询

```sql
-- 查看 TOP SQL（按总执行时间）
SELECT
    queryid,
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    rows
FROM sys_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;

-- 查看 TOP SQL（按平均执行时间）
SELECT
    queryid,
    query,
    calls,
    mean_exec_time,
    rows
FROM sys_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 20;

-- 查看执行次数最多的 SQL
SELECT
    queryid,
    query,
    calls,
    total_exec_time
FROM sys_stat_statements
ORDER BY calls DESC
LIMIT 20;
```

### 2.6 KWR 报告解读

```
KWR 报告主要包含以下部分：

1. 概览（Summary）
   - 采样时间段
   - 总查询数
   - 平均响应时间
   - QPS

2. TOP SQL
   - 按 CPU 时间排序
   - 按执行次数排序
   - 按平均响应时间排序

3. 等待事件分析
   - Lock 等待
   - Buffer I/O 等待
   - 网络等待

4. 建议（Recommendations）
   - 索引建议
   - 配置参数建议
   - SQL 优化建议
```

---

## 三、KBBadger 巡检报告

### 3.1 安装 KBBadger

```sql
-- 检查扩展
SELECT * FROM sys_available_extensions WHERE name = 'kbbadger';

-- 安装
CREATE EXTENSION IF NOT EXISTS kbbadger;
```

### 3.2 配置慢查询日志

```sql
-- kingbase.conf 配置
ALTER SYSTEM SET logging_collector = on;
ALTER SYSTEM SET log_directory = 'log';
ALTER SYSTEM SET log_filename = 'kingbase-%Y-%m-%d.log';
ALTER SYSTEM SET log_rotation_age = '1d';
ALTER SYSTEM SET log_rotation_size = '100MB';

-- 慢查询阈值
ALTER SYSTEM SET log_min_duration_statement = '1000';  -- 超过 1 秒记录

-- 其他日志配置
ALTER SYSTEM SET log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h ';
ALTER SYSTEM SET log_statement = 'none';  -- 不记录普通 SQL
ALTER SYSTEM SET log_duration = off;

-- 重载配置
SELECT sys_reload_conf();
```

### 3.3 生成 KBBadger 报告

```bash
# 使用 KBBadger 分析日志
cd /opt/Kingbase/ES/V9R2C14/Server/bin

# 分析单日日志
./kbbadger /data/kingbase/data/log/kingbase-2026-04-07.log -o /tmp/kbbadger_report.html

# 分析多日日志
./kbbadger /data/kingbase/data/log/kingbase-2026-04-*.log -o /tmp/kbbadger_report.html

# 命令行输出
./kbbadger /data/kingbase/data/log/kingbase-2026-04-07.log

# 参数说明：
# -o : 输出文件
# -p : 归类参数（如 --p 'client_addr' 按客户端 IP 归类）
# -b : 最少查询次数
# --skip-text : 跳过 query text（加快分析）
```

### 3.4 KBBadger 报告解读

```
KBBadger 报告主要包含：

1. 概览
   - 分析日志时间段
   - 总查询数
   - 唯一 SQL 数
   - 平均执行时间

2. TOP SQL（慢 SQL 排行）
   - 按总执行时间排序
   - 按平均执行时间排序
   - 按执行次数排序

3. 归类分析
   - 按数据库归类
   - 按用户归类
   - 按客户端 IP 归类

4. SQL 模板统计
   - 去除常数的 SQL 模板
   - 各模板的执行统计
```

---

## 四、定期巡检脚本

### 4.1 自动生成 KWR + KBBadger 报告

```bash
#!/bin/bash
# KingbaseES 巡检报告自动生成脚本

KBS_HOME="/opt/Kingbase/ES/V9R2C14/Server"
DATA_DIR="/data/kingbase/data"
REPORT_DIR="/tmp/kingbase_reports"
DATE=$(date +%Y%m%d)

mkdir -p $REPORT_DIR

echo "=== 生成 KWR 报告 ==="

# 使用 ksql 生成 KWR 相关数据
$KBS_HOME/bin/ksql -U system -d test -p 54321 << 'EOSQL'
-- 创建 KWR 快照
SELECT sys_kwr_begin();

-- 等待一段时间（可以改为后台运行一段时间）
-- SELECT pg_sleep(60);

-- 结束快照
SELECT sys_kwr_end('daily_report_'$DATE);

-- 输出报告
\o $REPORT_DIR/kwr_report_$DATE.txt
SELECT sys_kwr_report('daily_report_$DATE', 'text');
\o
EOSQL

echo "=== 生成 KBBadger 报告 ==="
$KBS_HOME/bin/kbbadger \
    $DATA_DIR/log/kingbase-$(date +%Y-%m-%d).log \
    -o $REPORT_DIR/kbbadger_$DATE.html

echo "=== 报告已生成 ==="
ls -la $REPORT_DIR/
```

### 4.2 Crontab 配置

```bash
# 每天凌晨 2 点生成巡检报告
crontab -e

# 添加：
# 0 2 * * * /opt/scripts/kingbase_inspection.sh >> /var/log/inspection.log 2>&1
```

---

## 五、KWR / KBBadger 命令参考

### 5.1 KWR 相关 SQL

```sql
-- 启动 KWR 采样
SELECT sys_kwr_begin();

-- 结束 KWR 采样并创建快照
SELECT sys_kwr_end('snapshot_name');

-- 列出所有快照
SELECT * FROM sys_kwr_list();

-- 删除快照
SELECT sys_kwr_drop('snapshot_name');

-- 生成报告
SELECT sys_kwr_report('snapshot_name', 'html');

-- 查看报告内容
SELECT sys_kwr_show('snapshot_name', 'text');
```

### 5.2 KBBadger 命令行

```bash
# 基本用法
kbbadger [options] logfile [...]

# 常用选项
# -o FILE       输出文件（默认 stdout）
# -p FORMAT     归类参数（database, username, client_addr 等）
# -b NUM        最少查询次数
# --min-duration NUM  最小执行时间（毫秒）
# --skip-text        跳过 SQL 文本
# -t            只输出 TOP N
# --quiet       静默模式

# 示例
kbbadger --help
kbbadger /data/kingbase/data/log/kingbase-2026-04-07.log
kbbadger -p client_addr -o /tmp/report.html /data/kingbase/data/log/*.log
kbbadger --min-duration 5000 /data/kingbase/data/log/kingbase-*.log
```

---

## 六、巡检报告模板

### 6.1 日/周巡检报告模板

```markdown
# KingbaseES 巡检报告

**报告日期**: 2026-04-07
**数据库版本**: KingbaseES V9R2C14
**巡检类型**: 日巡检

---

## 1. 系统概况

| 项目 | 值 | 状态 |
|------|-----|------|
| 数据库运行时间 | X 天 | ✅ |
| 当前连接数 | XX / 1000 | ✅ |
| 数据库大小 | XX GB | ✅ |
| 慢查询数量 | XX | ✅ |

## 2. TOP 10 慢 SQL

| 排名 | 执行次数 | 平均耗时 | 总耗时 | SQL 摘要 |
|------|---------|---------|--------|---------|
| 1 | 100 | 5000ms | 500s | SELECT * FROM orders... |
| ... | ... | ... | ... | ... |

## 3. 等待事件

| 等待类型 | 次数 | 平均等待时间 |
|---------|------|------------|
| Lock | XX | XX ms |
| BufferIO | XX | XX ms |

## 4. 巡检结论

✅ 整体运行正常
⚠️ 存在以下问题需要关注：
- 问题 1
- 问题 2

---

**报告生成时间**: 2026-04-07 10:00:00
```
```

---

## 七、常见问题

### 7.1 KWR 扩展无法安装

```sql
-- 检查 shared_preload_libraries
SHOW shared_preload_libraries;

-- 如果不包含 sys_kwr，需要重启数据库
ALTER SYSTEM SET shared_preload_libraries = 'sys_kwr';
-- 重启数据库
./sys_monitor restart -D /data/kingbase/data
```

### 7.2 KBBadger 报告为空

```bash
# 检查日志文件是否存在
ls -la /data/kingbase/data/log/kingbase-$(date +%Y-%m-%d).log

# 检查慢查询是否被记录
grep -c "duration:" /data/kingbase/data/log/kingbase-$(date +%Y-%m-%d).log

# 检查日志格式
grep "duration:" /data/kingbase/data/log/kingbase-$(date +%Y-%m-%d).log | head -5
```

### 7.3 慢查询日志格式不正确

```bash
# 确保 log_line_prefix 包含时间戳
ALTER SYSTEM SET log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d ';

# 确保 log_min_duration_statement 设置正确
ALTER SYSTEM SET log_min_duration_statement = '1000';

# 重载配置
SELECT sys_reload_conf();
```
