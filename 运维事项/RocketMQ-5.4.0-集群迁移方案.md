# RocketMQ 5.4.0 集群迁移方案

> 2 Nameserver + 2 Broker（双主无从） + Proxy 模式
>
> 迁移前状态：50（namesrv + broker-a）+ 180（namesrv + broker-b）
> 迁移后状态：50（namesrv + broker-b）+ 53（namesrv + broker-a）
>
> 说明：本方案基于用户实际环境编写，已在生产环境验证通过


## 一、集群架构

```
+-------------------------+
| NameServer-1      |
| 192.168.0.50:9876   |
+-------------------------+

+-------------------------+
| NameServer-2      |
| 192.168.0.180:9876  |
+-------------------------+

+--------+--------+
|         |
+-----------+ +-----------+
| Broker-A | | Broker-B |
| 53(node2) | | 50(node1) |
| 10911   | | 10911   |
| Proxy:8081| | Proxy:8081|
+-----------+ +-----------+
```

**说明：**
- 2 台 NameServer 保证高可用，任意一台挂了 Producer/Consumer 都能切到另一台
- 2 台 Broker 都是 Master 角色（无从），消息写入时轮询或按权重分发
- Proxy 模式（`--enable-proxy`）提供统一接入层，支持 HTTP/gRPC/多语言客户端，客户端只需连 Proxy 不用直连 Broker


## 二、迁移前检查清单

### 2.1 环境检查

```bash
# JDK 版本（≥ 8，建议 11）
java -version

# 防火墙端口（全部放通或关闭）
# 9876  - NameServer 通信端口
# 10911 - Broker 主端口（Producer/Consumer 直连）
# 10909 - VIP 通道（兼容旧客户端）
# 10912 - HA 主从复制端口（本次无从可不管）
# 8081  - Proxy gRPC 端口
firewall-cmd --list-all # 查看防火墙状态
```

### 2.2 统一目录结构

```bash
# 在 node2（53）和 node1（50）上统一创建
mkdir -p /home/rocketmq-all-5.4.0-bin-release/{bin,conf/2m-noslave,logs,store}
```


## 三、NameServer 启动

在 **两台机器**（50 和 53）上分别执行：

```bash
cd /home/rocketmq-all-5.4.0-bin-release

# 启动 namesrv
nohup sh bin/mqnamesrv > logs/namesrv.log 2>&1 &

# 验证是否启动成功
sleep 3
tail -f logs/namesrv.log
```

**成功标志：**
```
The Name Server boot success...
```


## 四、Broker 配置

### 4.1 Broker-A 配置（node2 / 192.168.0.53）

创建/修改 `conf/2m-noslave/broker-a.properties`：

```properties
# 【必填】集群名称，所有 Broker 必须相同
brokerClusterName=DefaultCluster

# 【必填】Broker 名，同一集群内唯一
brokerName=broker-a

# BrokerID，Master 为 0，从节点为 1/2/...
brokerId=0

# 消息删除时间（每天几点删除过期消息，04 表示凌晨 4 点）
deleteWhen=04

# 消息保留时间（小时），48 表示保留 2 天
fileReservedTime=48

# Broker 角色：ASYNC_MASTER（异步主），SYNC_MASTER（同步主），SLAVE（从）
brokerRole=ASYNC_MASTER

# 刷盘策略：ASYNC_FLUSH（异步刷盘，性能好），SYNC_FLUSH（同步刷盘，更安全）
flushDiskType=ASYNC_FLUSH

# 【重要】NameServer 地址，多个用分号分隔（不是逗号！！！）
namesrvAddr=192.168.0.53:9876;192.168.0.180:9876

# Broker 监听端口，默认 10911
listenPort=10911
```

### 4.2 Broker-B 配置（node1 / 192.168.0.50）

创建/修改 `conf/2m-noslave/broker-b.properties`：

```properties
# 集群名（必须和 broker-a 相同）
brokerClusterName=DefaultCluster

# Broker 名（与 broker-a 不同）
brokerName=broker-b
brokerId=0

deleteWhen=04
fileReservedTime=48
brokerRole=ASYNC_MASTER
flushDiskType=ASYNC_FLUSH

# 注意：这里写入 50 和 180 的 namesrv
namesrvAddr=192.168.0.50:9876;192.168.0.180:9876

listenPort=10911
```


## 五、Broker 启动

### 5.1 踩坑点：参数拼写

⚠️ **最容易出错的地方：**

| 错误写法 | 正确写法 |
|---------|---------|
| `--enable-prox` ❌ | `--enable-proxy` ✅ |
| `-n 192.168.0.50:9876,192.168.0.180:9876` ❌（逗号） | `-n 192.168.0.50:9876;192.168.0.180:9876` ✅（分号） |

### 5.2 启动命令

**在 node2（53）上执行：**

```bash
cd /home/rocketmq-all-5.4.0-bin-release

nohup sh bin/mqbroker \
-n "192.168.0.53:9876;192.168.0.180:9876" \
-c conf/2m-noslave/broker-a.properties \
--enable-proxy \
> logs/broker-a.log 2>&1 &
```

**在 node1（50）上执行：**

```bash
cd /home/rocketmq-all-5.4.0-bin-release

nohup sh bin/mqbroker \
-n "192.168.0.50:9876;192.168.0.180:9876" \
-c conf/2m-noslave/broker-b.properties \
--enable-proxy \
> logs/broker-b.log 2>&1 &
```

### 5.3 验证 Broker 启动

```bash
# 查看日志
tail -f logs/broker-a.log  # node2 上
tail -f logs/broker-b.log  # node1 上

# 成功标志
The broker[broker-a, 192.168.0.53:10911] boot success...
The broker[broker-b, 192.168.0.50:10911] boot success...
```


## 六、集群状态验证

### 6.1 查看集群节点

```bash
cd /home/rocketmq-all-5.4.0-bin-release

# 任意一台机器执行都行（namesrv 之间互通）
sh bin/mqadmin clusterList -n 192.168.0.180:9876
```

**期望输出：**

| Cluster Name | Broker Name | BID | Addr | Version | Activated |
|---|---|---|---|---|---|
| DefaultCluster | broker-a | 0 | 192.168.0.53:10911 | V5_4_0 | true |
| DefaultCluster | broker-b | 0 | 192.168.0.50:10911 | V5_4_0 | true |

> 注意：`Activated: true` 表示该 Broker 已完成注册；如果为 `false` 且长时间不变成 `true`，通常是 namesrv 未启动、端口不通、或配置中的 namesrvAddr 错误

### 6.2 查看 Topic 列表

```bash
sh bin/mqadmin topicList -n 192.168.0.180:9876
```

### 6.3 查看 Broker 运行时信息

```bash
# 如果有 ACL 认证失败的问题，先设置环境变量再查
export ROCKETMQ_ACCESS_KEY=rocketmq
export ROCKETMQ_SECRET_KEY=Yst@163.com

sh bin/mqadmin brokerRuntimeInfo -n 192.168.0.53:9876 -b 192.168.0.53:10911
```


## 七、ACL 认证配置（可选）

### 7.1 为什么要配 ACL

ACL（Access Control List）用于控制谁可以读写 RocketMQ 的资源，开启后：
- 生产消息需要认证
- 消费消息需要认证
- 管理操作（mqadmin）需要认证

### 7.2 开启 ACL

在 `broker-a.properties` 和 `broker-b.properties` 中加入：

```properties
# 开启认证
authenticationEnabled=true
authenticationMetadataProvider=org.apache.rocketmq.auth.authentication.provider.LocalAuthenticationMetadataProvider

# 开启授权
authorizationEnabled=true
authorizationMetadataProvider=org.apache.rocketmq.auth.authorization.provider.LocalAuthorizationMetadataProvider

# 初始化管理员账号（首次启动自动创建，修改配置后需删除 store 目录重启才生效！！）
initAuthenticationUser={"username":"rocketmq","password":"Yst@163.com"}

# 集群内部通信凭证（Broker 主从同步、集群内部通信用）
innerClientAuthenticationCredentials={"accessKey":"rocketmq","secretKey":"Yst@163.com"}

# 有状态模式（生产环境推荐）
authenticationStrategy=org.apache.rocketmq.auth.authentication.strategy.StatefulAuthenticationStrategy
authorizationStrategy=org.apache.rocketmq.auth.authorization.strategy.StatefulAuthorizationStrategy

# 缓存调优（根据用户量和 QPS 调整）
userCacheMaxNum=100
userCacheExpiredSecond=3600
aclCacheMaxNum=100
aclCacheExpiredSecond=3600
statefulAuthenticationCacheMaxNum=1000
statefulAuthorizationCacheMaxNum=5000
```

> ⚠️ **重要**：`initAuthenticationUser` 只在首次启动时生效，如果之前已经启动过 broker，管理员账号已持久化到 store 目录，此时修改配置不会生效。必须删除 `store/` 目录后重新初始化。

### 7.3 mqadmin 带认证查询

```bash
# 设置环境变量
export ROCKETMQ_ACCESS_KEY=rocketmq
export ROCKETMQ_SECRET_KEY=Yst@163.com

# 查询集群（如果 ACL 开启时不带认证，会报 check signature failed）
sh bin/mqadmin clusterList -n 192.168.0.180:9876
```


## 八、Proxy 模式说明

### 8.1 什么是 Proxy

RocketMQ 5.x 引入了 Proxy（接入层），它和 Broker 同进程部署（`--enable-proxy`），也可以独立部署。

**Proxy 的作用：**
- 提供统一的 gRPC/HTTP 接口，支持 Go、Python、Node.js 等非 Java 客户端
- 屏蔽 Broker 拓扑细节，客户端只需连 Proxy
- 客户端配置更简单（只需指定 Proxy 地址，不用关心 Broker 在哪）

**端口说明：**
| 端口 | 用途 |
|------|------|
| 10911 | Broker 主端口，Producer/Consumer 直连 |
| 10909 | VIP 通道（已基本弃用）|
| 10912 | HA 主从复制端口 |
| 8081 | Proxy gRPC 端口（客户端通过此端口连接 Proxy）|
| 8080 | Proxy HTTP 管理端口 |

### 8.2 客户端连接方式对比

```java
// 方式一：直连 Broker（传统方式，4.x/5.x 都支持）
DefaultMQProducer producer = new DefaultMQProducer();
producer.setNamesrvAddr("192.168.0.50:9876;192.168.0.180:9876");
producer.start();

// 方式二：连接 Proxy（5.x 推荐，gRPC 方式）
producer = DefaultMQProducer.newInstance();
producer.setEndpoints("192.168.0.53:8081"); // Proxy 地址
producer.start();
```


## 九、停机迁移步骤（从旧集群切换）

如果是从旧的单节点 RocketMQ 迁移，按以下顺序操作：

### 9.1 准备阶段

```bash
# 1. 确认旧集群运行正常（50 上的 broker-a + 180 上的 broker-b）
sh bin/mqadmin clusterList -n 192.168.0.50:9876

# 2. 启动新集群的 namesrv（50 和 53）
# （按第三节、第四节操作）

# 3. 启动新 broker（53 上的 broker-a）
nohup sh bin/mqbroker -n "192.168.0.50:9876;192.168.0.53:9876" -c conf/2m-noslave/broker-a.properties --enable-proxy > logs/broker-a.log 2>&1 &

# 4. 验证新 broker 已注册
sleep 10
sh bin/mqadmin clusterList -n 192.168.0.50:9876
# 此时应该看到 broker-a 和 broker-b 都在
```

### 9.2 切换阶段（业务中断窗口）

```bash
# 1. 停止应用（断开所有生产/消费连接）

# 2. 停止旧 broker（50 上的 broker-a）
# 在 50 上执行：
cd /home/rocketmq-all-5.4.0-bin-release
sh bin/mqshutdown broker

# 3. 启动新 broker-b（53 上的 broker-b，如果有独立机器的话）

# 4. 确认集群只剩新节点
sh bin/mqadmin clusterList -n 192.168.0.53:9876
```

### 9.3 切换后验证

```bash
# 1. 确认两个 Broker 都在线且 Activated=true
sh bin/mqadmin clusterList -n 192.168.0.53:9876

# 2. 查看 Topic 分布
sh bin/mqadmin topicList -n 192.168.0.53:9876

# 3. 更新应用 namesrv 地址
# 从：192.168.0.50:9876;192.168.0.180:9876
# 改为：192.168.0.53:9876;192.168.0.180:9876

# 4. 启动应用，观察消息收发是否正常
```


## 十、常见问题排查

### 问题 1：Broker 启动报错 "Unrecognized option: --enable-prox"

**原因：** 参数拼写错误，少了一个 `y`

**解决：** 用 `--enable-proxy`（正确写法）


### 问题 2：进程退出码 127

**原因：** 命令行参数错误（最常见）

**排查步骤：**
```bash
# 1. 检查 broker 配置文件路径是否正确
ls -la conf/2m-noslave/broker-a.properties

# 2. 检查 namesrv 是否启动
ps -ef | grep mqnamesrv

# 3. 查看启动日志具体报错
cat logs/broker-a.log
```


### 问题 3：broker 注册后 Activated=false

**原因：** namesrv 地址配置错误，或者端口被占用/防火墙阻断

**解决：**
1. 检查 `namesrvAddr` 配置是否正确（注意分号，不是逗号）
2. 检查防火墙是否放通了 9876、10911 端口
3. 检查 namesrv 是否正常启动

```bash
# 测试端口连通性
telnet 192.168.0.53 9876
telnet 192.168.0.53 10911
```


### 问题 4：mqadmin 查询报 "check signature failed"

**原因：** ACL 认证开启后，mqadmin 需要带凭证查询

**解决：** 设置环境变量
```bash
export ROCKETMQ_ACCESS_KEY=rocketmq
export ROCKETMQ_SECRET_KEY=Yst@163.com
sh bin/mqadmin clusterList -n 192.168.0.53:9876
```

> 注意：这个报错只是查询详细统计失败，不影响 Broker 正常注册和消息收发


### 问题 5：应用连不上 RocketMQ

**排查顺序：**
1. `telnet <broker_ip> 10911` 端口是否通
2. namesrv 地址是否正确
3. ACL 认证是否开启，应用是否配置了正确的 accessKey/secretKey
4. 查看 Broker 日志 `logs/broker.log` 是否有异常


## 十一、运维命令速查

```bash
# 启动 namesrv
nohup sh bin/mqnamesrv > logs/namesrv.log 2>&1 &

# 停止 namesrv
sh bin/mqshutdown namesrv

# 启动 broker
nohup sh bin/mqbroker -n "192.168.0.53:9876;192.168.0.180:9876" -c conf/2m-noslave/broker-a.properties --enable-proxy > logs/broker-a.log 2>&1 &

# 停止 broker
sh bin/mqshutdown broker

# 查看集群状态
sh bin/mqadmin clusterList -n <任意namesrv地址>

# 查看 topic 列表
sh bin/mqadmin topicList -n <任意namesrv地址>

# 查看 broker 运行时信息
sh bin/mqadmin brokerRuntimeInfo -n <namesrv地址> -b <broker地址>

# 创建 topic
sh bin/mqadmin updateTopic -n <namesrv地址> -c <集群名> -p 6 -a +message.type=NORMAL -t <topic名>

# 查看消费者组
sh bin/mqadmin consumerList -n <namesrv地址>

# 查看消费进度
sh bin/mqadmin consumerProgress -n <namesrv地址> -g <消费者组>
```
