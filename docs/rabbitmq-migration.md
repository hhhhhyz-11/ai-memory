# RabbitMQ 数据迁移指南

> 从物理机迁移到 Docker 环境

## 概述

本文档记录 RabbitMQ 从旧服务器迁移到新服务器（Docker 运行）的完整步骤。

**关键点**：
- 节点名（Node Name）必须保持一致
- Erlang Cookie 必须一致
- 数据目录权限需要修改为 UID 999:GID 999

---

## 第一步：旧服务器停机与数据打包

### 1.1 停止 RabbitMQ 服务

```bash
systemctl stop rabbitmq-server
```

### 1.2 查看节点名

```bash
ls /var/lib/rabbitmq/mnesia/
```

> 默认通常是 `rabbit@node1`（取决于 hostname），记下这个文件夹名字。

### 1.3 获取 Erlang Cookie

```bash
cat /var/lib/rabbitmq/.erlang.cookie
```

> 复制这串字符串，后续会用到

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

将 `mq_data.tar.gz` 上传到新服务器，解压：

```bash
cd /home/rabbitmq/data
tar -zxvf mq_data.tar.gz
```

> 解压后目录结构：`/home/rabbitmq/data/mnesia/rabbit@node1...`

### 2.3 修改目录权限（关键）

Docker 官方 RabbitMQ 镜像内部运行用户是 **UID 999, GID 999**。

```bash
chown -R 999:999 /home/rabbitmq/data
```

> 权限不对会导致容器无法启动

---

## 第三步：启动 Docker 容器

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

### 参数说明

| 参数 | 说明 |
|------|------|
| `--hostname node1` | 必须与旧服务器 hostname 一致，这样 RabbitMQ 才能找到数据目录 |
| `-v /home/rabbitmq/data:/var/lib/rabbitmq` | 将宿主机数据目录映射到容器 |
| `RABBITMQ_ERLANG_COOKIE` | 必须与旧环境一致，否则节点间通信失败 |

---

## 第四步：验证与后续处理

### 4.1 检查日志

```bash
docker logs -f rabbitmq
```

观察是否有权限错误或数据库损坏错误。

### 4.2 访问管理界面

访问 `http://新服务器IP:15672`，验证：

- ✅ Queues（队列）是否恢复
- ✅ Exchanges（交换机）是否恢复
- ✅ Users（用户）是否恢复

---

## 常见问题

### Q: 容器启动失败，提示权限错误

A: 检查数据目录权限是否为 999:999

### Q: 无法访问管理界面

A: 检查端口 15672 是否开放，检查防火墙规则

### Q: 队列数据丢失

A: 确认节点名（hostname）与旧服务器一致，数据目录路径是否正确

---

## 相关文档

- [RabbitMQ 官方迁移指南](https://www.rabbitmq.com/backup.html)
- [Docker RabbitMQ 镜像](https://hub.docker.com/_/rabbitmq)
