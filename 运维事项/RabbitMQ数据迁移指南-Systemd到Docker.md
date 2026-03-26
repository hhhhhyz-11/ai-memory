# RabbitMQ 数据迁移指南（Systemd → Docker）

> 将旧服务器（Systemd 管理）的 RabbitMQ 迁移到新服务器的 Docker 容器中

## 迁移概述

| 项目 | 说明 |
|------|------|
| 迁移方向 | Systemd 管理 → Docker 容器 |
| 关键要点 | 数据目录挂载、权限对齐、节点名称一致性 |
| 数据完整性 | 迁移前必须停止旧服务 |

---

## 第一步：旧服务器停机与数据打包

### 1.1 停止 RabbitMQ 服务

```bash
systemctl stop rabbitmq-server
```

### 1.2 查看节点名（Node Name）

RabbitMQ 的数据存储在以节点名命名的子目录中。

```bash
# 默认通常是 rabbit@node1（取决于你的 hostname）
ls /var/lib/rabbitmq/mnesia/
```

**记录下这个文件夹的名字**（例如 `rabbit@node1`），后续在 Docker 中需要保持一致。

### 1.3 获取 Erlang Cookie

Erlang Cookie 是节点认证的关键。

```bash
cat /var/lib/rabbitmq/.erlang.cookie
# 复制这串字符串，例如：XYZABC...
```

### 1.4 打包数据

```bash
cd /var/lib/rabbitmq
tar -zcvf mq_data.tar.gz mnesia
```

---

## 第二步：新服务器环境准备

### 2.1 创建目标目录

```bash
mkdir -p /home/rabbitmq/data
```

### 2.2 上传并解压数据

将 `mq_data.tar.gz` 上传到新服务器的 `/home/rabbitmq/data` 并解压。

```bash
cd /home/rabbitmq/data
tar -zxvf mq_data.tar.gz
# 解压后目录结构应为 /home/rabbitmq/data/mnesia/rabbit@node1...
```

### 2.3 修改目录权限（关键）

Docker 官方 RabbitMQ 镜像内部运行的用户 **UID 是 999，GID 也是 999**。如果宿主机权限不对，容器将无法启动。

```bash
chown -R 999:999 /home/rabbitmq/data
```

---

## 第三步：启动 Docker 容器

### 3.1 核心参数说明

| 参数 | 说明 |
|------|------|
| `--hostname` | 必须与旧服务器一致（确保能找到数据目录） |
| `RABBITMQ_ERLANG_COOKIE` | 必须与旧服务器一致，否则节点认证失败 |
| `-v` | 挂载数据目录 |

### 3.2 启动命令

假设旧节点名是 `rabbit@node1`，则新容器 hostname 设为 `node1`：

```bash
docker run -d \
 --name rabbitmq \
 --hostname node1 \
 -p 5672:5672 \
 -p 15672:15672 \
 -v /home/rabbitmq/data:/var/lib/rabbitmq \
 -e RABBITMQ_ERLANG_COOKIE='你复制的Cookie字符串' \
 -e RABBITMQ_DEFAULT_USER=admin \
 -e RABBITMQ_DEFAULT_PASS=admin_password \
 rabbitmq:3.8.8-management
```

### 3.3 参数说明

- `-v /home/rabbitmq/data:/var/lib/rabbitmq`：将宿主机准备好的数据目录映射到容器
- `--hostname node1`：必须和旧服务器的 hostname 保持一致，这样 RabbitMQ 才能找到 `/var/lib/rabbitmq/mnesia/rabbit@node1` 下的数据
- `RABBITMQ_ERLANG_COOKIE`：确保与旧环境一致，否则权限或集群功能会失效

---

## 第四步：验证与后续处理

### 4.1 检查日志

```bash
docker logs -f rabbitmq
```

观察是否有：
- ❌ 权限错误
- ❌ 数据库损坏错误
- ✅ 启动成功

### 4.2 进入管理界面

访问 **http://新服务器IP:15672**，检查：

- [ ] Queues（队列）是否恢复
- [ ] Exchanges（交换机）是否恢复
- [ ] Users（用户）是否恢复

### 4.3 验证消息是否可正常消费

建议在测试环境先验证队列消息可正常收发，确认数据完整后再切换生产流量。

---

## 常见问题

### Q1：容器启动失败，提示权限拒绝

**原因**：宿主机目录权限未对齐（UID 999）

**解决**：
```bash
chown -R 999:999 /home/rabbitmq/data
```

### Q2：节点名不一致导致数据无法读取

**原因**：Docker hostname 与旧服务器不一致

**解决**：确保 `--hostname` 参数与旧服务器的 hostname 完全一致

### Q3：Erlang Cookie 不匹配

**原因**：多节点集群或节点间通信需要相同的 Cookie

**解决**：通过 `-e RABBITMQ_ERLANG_COOKIE` 参数指定与旧服务器相同的 Cookie

---

## 回滚方案

如迁移失败需要回滚：

1. 停止 Docker 容器：`docker stop rabbitmq`
2. 在旧服务器重新启动 RabbitMQ：`systemctl start rabbitmq-server`
3. 检查旧服务器数据完整性后恢复服务

---

*文档创建时间：2026-03-26*
