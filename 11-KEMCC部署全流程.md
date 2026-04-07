# KingbaseES V9R2C14 KEMCC 部署全流程

> 适用版本：KingbaseES V9R2C14
> 参考：https://docs.kingbase.com.cn/cn/KES-V9R2C14/

---

## 一、KEMCC 概述

KEMCC（KingbaseES Management and Control Center）是 KingbaseES 的管理与控制中心，提供：
- **图形化管理界面** — 数据库实例的图形化管理
- **性能监控** — 实时监控数据库性能指标
- **集群管理** — 主备集群的集中管理
- **告警管理** — 配置告警规则和通知
- **备份恢复** — 集中管理备份任务

---

## 二、环境要求

| 项目 | 最低要求 | 推荐配置 |
|------|---------|---------|
| CPU | 4 核 | 8 核 |
| 内存 | 8 GB | 16 GB |
| 磁盘 | 100 GB | 200 GB SSD |
| 操作系统 | CentOS 7+ / 麒麟 V10 / UOS | CentOS 7+ |
| JDK | JDK 1.8+ | JDK 11 |
| 浏览器 | Chrome 80+ / Firefox 80+ | Chrome 最新版 |

---

## 三、安装 KEMCC

### 3.1 下载安装包

```bash
# 下载 KEMCC V9R2C14 安装包
# 通常命名为 kingbase-mcc-V9R2C14-linux.tar.gz
```

### 3.2 解压安装包

```bash
cd /opt
tar -xzf kingbase-mcc-V9R2C14-linux.tar.gz
cd kingbase-mcc

ls -la
# bin/        启动脚本
# conf/       配置文件
# jre/        JDK 运行环境
# lib/        依赖库
# logs/       日志目录
# webapp/     Web 应用
```

### 3.3 创建数据库（KEMCC 元数据库）

```bash
# KEMCC 需要一个数据库存储元数据
# 在 KingbaseES 中创建

su - kingbase
cd /opt/Kingbase/ES/V9R2C14/Server/bin
./ksql -U system -d test -p 54321

# 创建 KEMCC 数据库
CREATE DATABASE kemcc_db OWNER system;
\c kemcc_db

# 安装扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "sys_kwr";

\q
```

---

## 四、配置 KEMCC

### 4.1 配置数据库连接

```bash
cat > /opt/kingbase-mcc/conf/kemcc.properties << 'EOF'
# === KEMCC 数据库连接 ===
kemcc.db.type=kingbase
kemcc.db.host=192.168.1.101
kemcc.db.port=54321
kemcc.db.name kemcc_db
kemcc.db.username=system
kemcc.db.password=your_password

# === KEMCC 服务端口 ===
kemcc.server.port=8080
kemcc.server.maxThreads=200
kemcc.server.minSpareThreads=10

# === 管理节点 ===
kemcc.agent.enabled=true
kemcc.agent.port=9888

# === 日志 ===
kemcc.log.dir=/opt/kingbase-mcc/logs
kemcc.log.level=INFO
EOF
```

### 4.2 配置 SSL（可选）

```bash
# 配置 SSL 连接
cat >> /opt/kingbase-mcc/conf/kemcc.properties << 'EOF'

# === SSL 配置 ===
kemcc.ssl.enabled=false
kemcc.ssl.keyStore=/opt/kingbase-mcc/conf/keystore.jks
kemcc.ssl.keyStorePassword=changeit
kemcc.ssl.keyAlias kemcc
EOF
```

### 4.3 内存配置

```bash
# 根据服务器内存调整 JVM 堆大小
cat > /opt/kingbase-mcc/bin/setenv.sh << 'EOF'
#!/bin/bash
# JVM 内存配置（根据实际情况调整）
export JAVA_OPTS="-Xms4g -Xmx8g -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
export JAVA_OPTS="$JAVA_OPTS -Dfile.encoding=UTF-8"
EOF

chmod +x /opt/kingbase-mcc/bin/setenv.sh
```

---

## 五、启动 KEMCC

### 5.1 启动服务

```bash
cd /opt/kingbase-mcc/bin

# 启动 KEMCC
./startup.sh

# 查看启动日志
tail -100 /opt/kingbase-mcc/logs/kemcc.log
```

### 5.2 验证启动

```bash
# 检查进程
ps -ef | grep kemcc | grep -v grep

# 检查端口
netstat -tlnp | grep 8080

# 访问 Web 界面
# http://<服务器IP>:8080/kemcc
```

### 5.3 首次登录

```
URL: http://192.168.1.101:8080/kemcc
默认用户名: admin
默认密码: admin
```

> ⚠️ **首次登录后请立即修改默认密码！**

---

## 六、添加监控节点

### 6.1 添加 KingbaseES 节点

1. 登录 KEMCC Web 界面
2. 进入「系统管理」→「节点管理」
3. 点击「添加节点」
4. 填写信息：

| 配置项 | 值 |
|-------|-----|
| 节点名称 | kes-node-01 |
| 节点类型 | KingbaseES |
| 主机地址 | 192.168.1.101 |
| 端口 | 54321 |
| 用户名 | system |
| 密码 | ******** |
| 数据库 | test |

### 6.2 安装 Agent（可选）

```bash
# 在被管理的 KingbaseES 节点安装 agent
cd /opt
tar -xzf kingbase-agent-V9R2C14-linux.tar.gz
cd kingbase-agent

# 配置 agent
cat > conf/agent.properties << 'EOF'
agent.server.host=192.168.1.100  # KEMCC 服务器地址
agent.server.port=9888
agent.node.name=kes-node-01
EOF

# 启动 agent
bin/agent.sh start
```

---

## 七、KEMCC 常用功能

### 7.1 性能监控

```
Web 界面路径：监控 → 性能监控
- CPU 使用率
- 内存使用率
- 连接数
- QPS/TPS
- 锁等待
- 会话列表
```

### 7.2 会话管理

```
Web 界面路径：运维 → 会话管理
- 查看当前会话
- 杀掉长时间运行的查询
- 查看等待事件
```

### 7.3 备份管理

```
Web 界面路径：运维 → 备份管理
- 创建备份任务
- 设置备份策略
- 查看备份历史
- 执行恢复
```

### 7.4 告警管理

```
Web 界面路径：告警 → 告警规则
- 配置告警阈值
- 设置告警通知方式（邮件/短信）
- 查看告警历史
```

---

## 八、服务管理

```bash
# 停止 KEMCC
cd /opt/kingbase-mcc/bin
./shutdown.sh

# 重启 KEMCC
./shutdown.sh
./startup.sh

# 查看状态
./status.sh
```

---

## 九、配置开机自启动

```bash
# 创建 systemd 服务文件
cat > /etc/systemd/system/kemcc.service << 'EOF'
[Unit]
Description=KingbaseES Management and Control Center
After=network.target

[Service]
Type=forking
ExecStart=/opt/kingbase-mcc/bin/startup.sh
ExecStop=/opt/kingbase-mcc/bin/shutdown.sh
User=root
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kemcc
systemctl start kemcc
```

---

## 十、常见问题

### 10.1 启动失败

```bash
# 查看日志
cat /opt/kingbase-mcc/logs/kemcc.log

# 常见原因：
# 1. 端口被占用
netstat -tlnp | grep 8080

# 2. JDK 版本不对
java -version

# 3. 数据库连接失败
# 检查 kemcc.db.* 配置是否正确
```

### 10.2 无法添加节点

```bash
# 1. 检查 KingbaseES 版本是否兼容
# 2. 检查网络连通性
ping 192.168.1.101

# 3. 检查端口
nc -zv 192.168.1.101 54321

# 4. 检查用户名密码
./ksql -h 192.168.1.101 -p 54321 -U system -d test -c "SELECT 1;"
```

### 10.3 监控数据不显示

```bash
# 1. 检查 agent 是否运行
ps -ef | grep kingbase-agent | grep -v grep

# 2. 检查 agent 日志
cat /opt/kingbase-agent/logs/agent.log

# 3. 重启 agent
/opt/kingbase-agent/bin/agent.sh restart
```
