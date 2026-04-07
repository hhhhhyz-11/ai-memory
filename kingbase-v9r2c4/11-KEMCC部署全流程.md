# KingbaseES V9R2C14 KEMCC 部署全流程

> 本文档介绍 KEMCC（Kingbase Enterprise Management Control Center）控制中心的完整部署流程。

---

## 一、KEMCC 概述

### 1.1 KEMCC 简介

KEMCC 是金仓提供的数据库管理控制中心，提供：
- 图形化数据库监控
- 告警规则配置与通知
- 性能指标可视化
- 集群管理
- 备份恢复管理

### 1.2 系统要求

| 项目 | 最低要求 | 推荐配置 |
|------|---------|---------|
| CPU | 4 核 | 8 核 |
| 内存 | 8 GB | 16 GB |
| 磁盘 | 100 GB | 200 GB |
| 操作系统 | CentOS 7+ / 麒麟 V10 | 同左 |
| JDK | JDK 8 / JDK 11 | JDK 11 |

---

## 二、环境准备

### 2.1 检查 JDK 安装

```bash
# 检查 Java 版本
java -version
# openjdk version "1.8.0_xxx" or openjdk version "11.x.x"

# 如果未安装，安装 JDK
yum install -y java-11-openjdk java-11-openjdk-devel

# 设置 JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk
echo "export JAVA_HOME=/usr/lib/jvm/java-11-openjdk" >> ~/.bash_profile
source ~/.bash_profile
```

### 2.2 创建 KEMCC 用户

```bash
# 创建管理用户
useradd -m -s /bin/bash kemcc
echo "kemcc:KemccPassword123" | chpasswd

# 创建安装目录
mkdir -p /opt/KEMCC
chown -R kemcc:kemcc /opt/KEMCC
```

### 2.3 数据库授权

```sql
-- 创建 KEMCC 使用的数据库用户
CREATE USER kemcc_admin WITH PASSWORD 'KemccAdmin123';
GRANT CONNECT ON DATABASE test TO kemcc_admin;
GRANT ALL PRIVILEGES ON SCHEMA public TO kemcc_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO kemcc_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO kemcc_admin;
```

---

## 三、KEMCC 安装

### 3.1 下载和解压

```bash
# 上传 KEMCC 安装包
# 假设安装包为：KEMCC_V9R2C14_linux_x86_64.tar.gz

# 解压
cd /opt
tar -xzf KEMCC_V9R2C14_linux_x86_64.tar.gz -C /opt/KEMCC/

# 查看解压内容
ls -la /opt/KEMCC/
```

### 3.2 目录结构

```
/opt/KEMCC/
├── bin/              # 启动脚本
├── conf/             # 配置文件
├── lib/              # Java 类库
├── logs/             # 日志目录
├── jre/              # Java 运行环境（可选）
└── data/             # KEMCC 数据目录
```

### 3.3 配置 KEMCC

```bash
su - kemcc
vim /opt/KEMCC/conf/kemcc.properties

# ================== KEMCC 配置文件 ==================

# KEMCC 服务端口
server.port=8080
server.https.port=8443

# 数据库连接配置
db.type=kingbase
db.host=192.168.1.100
db.port=54321
db.name=test
db.username kemcc_admin
db.password=KemccAdmin123

# 数据库连接池
db.pool.initialSize=5
db.pool.maxActive=20
db.pool.maxWait=60000

# 日志配置
log.level=INFO
log.path=/opt/KEMCC/logs

# 会话超时（分钟）
session.timeout=30

# 监控数据采集间隔（秒）
monitor.interval=60

# 告警检测间隔（秒）
alert.check.interval=30
```

### 3.4 配置监控目标

```bash
vim /opt/KEMCC/conf/targets.properties

# ================== 监控目标配置 ==================

# 目标数据库列表
target.1.name=kingbase_prod
target.1.host=192.168.1.100
target.1.port=54321
target.1.user=system
target.1.password=YourPassword123
target.1.type=kingbase
target.1.enabled=true

target.2.name=kingbase_standby
target.2.host=192.168.1.101
target.2.port=54321
target.2.user=system
target.2.password=YourPassword123
target.2.type=kingbase
target.2.enabled=true
```

---

## 四、启动 KEMCC

### 4.1 启动服务

```bash
# 切换到 kemcc 用户
su - kemcc

# 进入 KEMCC 目录
cd /opt/KEMCC

# 启动 KEMCC（前台运行，首次验证）
bin/kemcc.sh start

# 后台运行
nohup bin/kemcc.sh start > /opt/KEMCC/logs/kemcc.log 2>&1 &

# 检查进程
ps -ef | grep kemcc | grep -v grep
```

### 4.2 验证启动

```bash
# 检查端口
netstat -tlnp | grep 8080

# 检查健康状态
curl -s http://localhost:8080/kemcc/health

# 查看日志
tail -f /opt/KEMCC/logs/kemcc.log
```

---

## 五、Web 控制台访问

### 5.1 访问地址

```
http://<KEMCC服务器IP>:8080/kemcc
```

默认账号密码：
- 用户名：`admin`
- 密码：`admin`（建议首次登录后修改）

### 5.2 首次登录配置

1. 登录后修改 admin 密码
2. 添加监控的数据库实例
3. 配置告警规则
4. 配置通知渠道（邮件、短信等）

---

## 六、添加监控目标

### 6.1 通过 Web 界面添加

1. 登录 KEMCC Web 控制台
2. 进入「系统管理」→「数据库实例」
3. 点击「添加实例」
4. 填写数据库连接信息
5. 点击「测试连接」确认连通性
6. 保存配置

### 6.2 通过配置文件添加

```bash
vim /opt/KEMCC/conf/targets.properties

# 添加更多目标
target.3.name=kingbase_node1
target.3.host=192.168.1.100
target.3.port=54321
target.3.user=system
target.3.password=YourPassword123
target.3.type=kingbase
target.3.enabled=true
target.3.tags=prod,primary
```

---

## 七、常用运维命令

### 7.1 服务管理

```bash
# 进入 KEMCC 目录
cd /opt/KEMCC

# 启动
bin/kemcc.sh start

# 停止
bin/kemcc.sh stop

# 重启
bin/kemcc.sh restart

# 查看状态
bin/kemcc.sh status

# 查看版本
bin/kemcc.sh version
```

### 7.2 日志管理

```bash
# KEMCC 日志
ls -la /opt/KEMCC/logs/

# 实时查看日志
tail -f /opt/KEMCC/logs/kemcc.log

# 清理旧日志
find /opt/KEMCC/logs -name "*.log" -mtime +30 -delete
```

---

## 八、常见问题

### 8.1 启动失败

**错误**：`Unable to start KEMCC server`

**排查**：
```bash
# 检查端口占用
netstat -tlnp | grep 8080

# 检查 JDK 版本
java -version

# 检查配置文件语法
cat /opt/KEMCC/conf/kemcc.properties | grep -v "^#" | grep -v "^$"
```

**解决**：
```bash
# 端口占用，更换端口
sed -i 's/server.port=8080/server.port=8081/' /opt/KEMCC/conf/kemcc.properties

# JDK 版本问题，使用 KEMCC 自带 JRE
export JAVA_HOME=/opt/KEMCC/jre
```

### 8.2 无法连接数据库

**排查**：
```bash
# 测试数据库连接
ksql -U kemcc_admin -d test -h 192.168.1.100 -p 54321 -c "SELECT 1;"

# 检查防火墙
firewall-cmd --list-all
```

### 8.3 监控数据不更新

**排查**：
```bash
# 检查监控任务是否运行
ps -ef | grep monitor | grep -v grep

# 检查监控目标配置
cat /opt/KEMCC/conf/targets.properties

# 重启 KEMCC
bin/kemcc.sh restart
```

---

## 九、备份与恢复

### 9.1 KEMCC 数据备份

```bash
# 备份 KEMCC 配置和数据
tar -czpf /tmp/kemcc_backup_$(date +%Y%m%d).tar.gz \
    /opt/KEMCC/conf/ \
    /opt/KEMCC/data/ \
    /opt/KEMCC/logs/
```

### 9.2 KEMCC 数据恢复

```bash
# 停止服务
bin/kemcc.sh stop

# 恢复数据
tar -xzpf /tmp/kemcc_backup_20240115.tar.gz -C /

# 启动服务
bin/kemcc.sh start
```

---

## 十、卸载

```bash
# 停止服务
/opt/KEMCC/bin/kemcc.sh stop

# 删除安装目录
rm -rf /opt/KEMCC

# 删除用户（可选）
userdel kemcc

# 删除日志残留
rm -rf /var/log/kemcc/
```

---
