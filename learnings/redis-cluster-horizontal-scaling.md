# Redis 集群水平扩展实战：添加与删除节点

> 来源：[CSDN - Redis集群添加新节点](https://blog.csdn.net/qq_33417321/article/details/119518848)

Redis 3.0+ 集群提供了比哨兵模式更高的性能与可用性，但水平扩展（添加新节点）需要手动操作。本文详细介绍如何优雅地扩展 Redis 集群。

---

## 一、准备工作

### 1.1 原始集群状态
假设现有三主三从集群，分布在三台机器上：
- 8001/8002/8003 → 主节点
- 8004/8005/8006 → 从节点

启动集群：
```bash
/usr/local/redis-5.0.3/src/redis-server /usr/local/redis-cluster/8001/redis.conf
# ... 启动其他节点

# 连接集群
/usr/local/redis-5.0.3/src/redis-cli -a zhuge -c -h 192.168.0.61 -p 8001

# 查看集群状态
192.168.0.61:8001> cluster nodes
```

每个主节点负责不同的 hash 槽：
- 8001: 0-5460
- 8002: 5461-10922
- 8003: 10923-16383

---

## 二、添加新节点

### 2.1 创建新节点配置

在 `/usr/local/redis-cluster` 下创建 8007 和 8008 文件夹：

```bash
mkdir 8007 8008
cd 8001
cp redis.conf /usr/local/redis-cluster/8007/
cp redis.conf /usr/local/redis-cluster/8008/
```

修改 `8007/redis.conf`：
```bash
port 8007
dir /usr/local/redis-cluster/8007/
cluster-config-file nodes-8007.conf
```

修改 `8008/redis.conf`：
```bash
port 8008
dir /usr/local/redis-cluster/8008/
cluster-config-file nodes-8008.conf
```

### 2.2 启动新节点

```bash
/usr/local/redis-5.0.3/src/redis-server /usr/local/redis-cluster/8007/redis.conf
/usr/local/redis-5.0.3/src/redis-server /usr/local/redis-cluster/8008/redis.conf
ps -ef | grep redis
```

### 2.3 添加主节点到集群

```bash
/usr/local/redis-5.0.3/src/redis-cli -a zhuge --cluster add-node 192.168.0.61:8007 192.168.0.61:8001
```

> ⚠️ 新节点添加后没有分配 hash 槽，还不能写入数据

### 2.4 分配 Hash 槽

```bash
/usr/local/redis-5.0.3/src/redis-cli -a zhuge --cluster reshard 192.168.0.61:8001
```

交互式回答：
```
How many slots do you want to move (from 1 to 16384)? 600

What is the receiving node ID? <8007的节点ID>

Please enter all the source node IDs.
Type 'all' to use all the nodes as source nodes for the hash slots.
Type 'done' once you entered all the source nodes IDs.
Source node 1: all

Do you want to proceed with the proposed reshard plan (yes/no)? yes
```

### 2.5 添加从节点

```bash
# 添加8008到集群
/usr/local/redis-5.0.3/src/redis-cli -a zhuge --cluster add-node 192.168.0.61:8008 192.168.0.61:8001

# 关联到主节点8007
/usr/local/redis-5.0.3/src/redis-cli -a zhuge -c -h 192.168.0.61 -p 8008
192.168.0.61:8008> cluster replicate <8007的节点ID>
```

---

## 三、删除节点

### 3.1 删除从节点

```bash
/usr/local/redis-5.0.3/src/redis-cli -a zhuge --cluster del-node 192.168.0.61:8008 <节点ID>
```

### 3.2 删除主节点

删除主节点前，**必须先将其 hash 槽迁移到其他节点**：

```bash
# 重新分片，将槽迁移走
/usr/local/redis-5.0.3/src/redis-cli -a zhuge --cluster reshard 192.168.0.61:8007

# 槽迁走后，再删除节点
/usr/local/redis-5.0.3/src/redis-cli -a zhuge --cluster del-node 192.168.0.61:8007 <节点ID>
```

---

## 四、常用命令速查

```bash
# 查看集群帮助
redis-cli --cluster help

# 创建集群
redis-cli --cluster create host1:port1 ... hostN:portN

# 检查集群状态
redis-cli --cluster check <任意节点>

# 重新分片
redis-cli --cluster reshard <任意节点>

# 添加节点
redis-cli --cluster add-node <新节点> <已有节点>

# 删除节点
redis-cli --cluster del-node <节点> <节点ID>
```

---

## 五、注意事项

1. **hash 槽迁移会阻塞客户端** - 建议在业务低峰期操作
2. **删除主节点前必须迁移槽** - 否则数据会丢失
3. **从节点会自动复制主节点数据** - 不需要手动同步
4. **生产环境建议使用防火墙** - 限制 Redis 端口访问
