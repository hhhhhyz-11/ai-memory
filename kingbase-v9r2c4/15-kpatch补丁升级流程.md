# KingbaseES kpatch 补丁升级流程（V9R2C13 → PS014）

> 适用版本：V009R002C13（B0005）升级至 V009R002C013PS014  
> 适用环境：单机 / 集群  
> 文档日期：2026-04-10

---

## 一、升级前准备

### 1.1 确认当前版本

```bash
cd /home/kingbase/KESRealPro/V009R002C013/Server/bin
./kingbase -V
./ksql -V
```

**支持的基线版本：**

| 当前版本 | 是否可升级 |
|---------|----------|
| V009R002C013PS007 | ✅ |
| V009R002C013PS009 | ✅ |
| 其他版本 | ❌ 需先升级到 PS007/PS009 |

### 1.2 确认目录结构

```bash
# 单机目录示例（本次环境）
安装目录（Server）：/home/kingbase/KESRealPro/V009R002C013/Server
可执行文件目录：  /home/kingbase/KESRealPro/V009R002C013/Server/bin
数据目录：        /home/kingbase/data
Server 软链接：   /home/kingbase/Server → /home/kingbase/KESRealPro/V009R002C013/Server
```

### 1.3 检查磁盘空间

```bash
df -h
```

确保数据目录所在磁盘有足够空间（建议剩余可用空间 > 数据目录大小的 1.5 倍）。

---

## 二、单机升级（kpatch 原位升级）

### 2.1 备份数据

```bash
mkdir -p /home/kingbase/data_bak
cp -r /home/kingbase/data/ /home/kingbase/data_bak/
```

> ⚠️ **必须执行**，数据损坏时可回退

### 2.2 上传补丁包

上传 `kingbase-server-V009R002C013PS014-linux-x86_64.tar` 到服务器。

### 2.3 解压 kpatch 可执行文件

```bash
mkdir -p /home/kingbase/Kpatch/patch_packages

cd /home/kingbase/Kpatch/patch_packages
tar -zxf kingbase-server-V009R002C013PS014-linux-x86_64.tar \
  --strip-components 2 -C .. ./bin/kpatch
```

**验证解压结果：**

```bash
ls /home/kingbase/Kpatch/kpatch
```

### 2.4 启动数据库

```bash
cd /home/kingbase/KESRealPro/V009R002C013/Server/bin
./sys_ctl -D /home/kingbase/data start

# 验证连接
./ksql -d test -U system -p 54321 -W
```

> ⚠️ **必须先启动**，否则 kpatch 检查会报错 `kingbase not running`

**如果启动报错 PID 文件残留：**

```bash
./sys_ctl -D /home/kingbase/data stop
./sys_ctl -D /home/kingbase/data start
```

### 2.5 执行 kpatch 升级

```bash
cd /home/kingbase/Kpatch

./kpatch \
  -k /home/kingbase/Server \
  -D /home/kingbase/data \
  -t V009R002C013PS014 apply single
```

> ⚠️ **关键**：`-k` 参数必须使用软链接路径（如 `/home/kingbase/Server`），**不能使用包含 `KESRealPro` 的路径**，否则报错：
> `kingbase_path contains:KESRealPro, should not use with:-k *KESRealPro*`

出现提示后输入 `y` 确认：

```
next the database will be stopped. are you ready to upgrade? (y/n): y
```

### 2.6 验证升级结果

```bash
cd /home/kingbase/Server/bin
./kingbase -V
./ksql -V
```

**预期输出：**

```
kingbase (KingbaseES) V009R002C013PS014
ksql (KingbaseES) V009R002C013PS014
```

---

## 三、升级后操作

### 3.1 验证数据库状态

```bash
# 确认服务正常
./ksql -d test -U system -p 54321 -W -c "SELECT build_version;"

# 检查数据完整性
./ksql -d test -U system -p 54321 -W -c "SELECT count(*) FROM <业务表>;"

# 检查扩展状态
./ksql -d <业务库> -U system -p 54321 -W -c "SELECT * FROM sys_extension;"
```

### 3.2 SQL 扩展升级（按需执行）

**PS007 → PS009 升级：**

```sql
-- 兼容 Oracle 函数 wm_concat 返回类型为 clob
ALTER EXTENSION kdb_oracle_datatype update to '1.21';
```

> ⚠️ 如果报错 `cannot drop operator /(xxx,xxx) because others objects depend on it`，需要先备份依赖该操作符的对象，删除后重做升级，再还原。

**PS009 → PS014：** 无额外 SQL 操作

### 3.3 检查日志

```bash
cat /home/kingbase/data/sys_log/*.log | grep -i error | tail -20
```

---

## 四、集群升级

### 4.1 目录结构（集群）

```bash
安装目录：/home/kingbase/cluster/test/kingbase/
数据目录：/home/kingbase/cluster/test/data/
Kpatch目录：/home/kingbase/cluster/test/Kpatch/
```

### 4.2 升级步骤

```bash
# 1. 主备节点分别备份数据
mkdir -p /home/kingbase/data_bak
cp -r /home/kingbase/cluster/test/data/ /home/kingbase/data_bak/

# 2. 主节点上传并解压补丁包（同单机步骤）

# 3. 执行集群升级（二选一）

# 滚动升级（不停止集群服务）
cd /home/kingbase/cluster/test/Kpatch
./kpatch -k /home/kingbase/cluster/test/kingbase/ \
  -D /home/kingbase/cluster/test/data \
  -t V009R002C013PS014 apply cluster_rolling

# 并行升级（需先停止集群）
./kpatch -k /home/kingbase/cluster/test/kingbase/ \
  -D /home/kingbase/cluster/test/data \
  -t V009R002C013PS014 apply cluster_parallel
```

### 4.3 集群验证

```bash
# 查看集群状态
./repmgr cluster show

# 检查流复制
./ksql -h localhost -U system -d test -p 54321 -W -c "SELECT * FROM sys_stat_replication;"

# 检查复制槽
./ksql -h localhost -U system -d test -p 54321 -W -c "SELECT * FROM sys_replication_slots;"
```

---

## 五、版本回退

### 5.1 单机回退

```bash
cd /home/kingbase/Kpatch

./kpatch -k /home/kingbase/Server \
  -D /home/kingbase/data \
  -t V009R002C013 rollback single
```

### 5.2 集群回退

```bash
# 滚动回退
./kpatch -k /home/kingbase/cluster/test/kingbase/ \
  -D /home/kingbase/cluster/test/data \
  -t V009R002C013 rollback cluster_rolling

# 并行回退
./kpatch -k /home/kingbase/cluster/test/kingbase/ \
  -D /home/kingbase/cluster/test/data \
  -t V009R002C013 rollback cluster_parallel
```

### 5.3 数据回退（彻底回退）

```bash
# 停止数据库
./sys_ctl -D /home/kingbase/data stop

# 还原数据目录
rm -fr /home/kingbase/data/
cp -r /home/kingbase/data_bak/data /home/kingbase/

# 启动
./sys_ctl -D /home/kingbase/data start
```

---

## 六、常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| `kingbase not running` | 数据库未启动 | 先 `sys_ctl start` |
| `lock file "kingbase.pid" already exists` | PID 文件残留 | `sys_ctl stop` 后重试 |
| `-k path contains KESRealPro` | 路径包含 KESRealPro | 改用软链接路径如 `/home/kingbase/Server` |
| 扩展升级报错 `cannot drop operator` | 有对象依赖该操作符 | 先备份/删除依赖对象，再升级扩展 |

---

## 七、kpatch 参数说明

| 参数 | 说明 | 示例 |
|------|------|------|
| `-k` | Kingbase 安装路径（软链接） | `/home/kingbase/Server` |
| `-D` | 数据目录路径 | `/home/kingbase/data` |
| `-t` | 目标版本号 | `V009R002C013PS014` |
| `apply` | 执行升级 | `apply single` / `apply cluster_rolling` |
| `rollback` | 执行回退 | `rollback single` |

---

*本文档基于 V009R002C013PS014 补丁包实际操作记录*
