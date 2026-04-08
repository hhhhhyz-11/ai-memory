# KingBaseES V9R2C4 主备集群部署

> 部署时间：2026-04-08
> 版本：V009R002C014B0009
> 部署环境：Vagrant 虚拟机 (CentOS 7)

---

## 一、环境信息

| 项目 | KingBase1 | KingBase2 |
|------|-----------|-----------|
| 主机名 | kingbase1 | kingbase2 |
| IP | 192.168.56.11 | 192.168.56.12 |
| VIP | 192.168.56.15/24 | - |
| 安装用户 | kingbase | kingbase |
| 数据库端口 | 54321 | 54321 |
| securecmdd 端口 | 8890 | 8890 |

---

## 二、部署前准备

### 1. 创建 kingbase 用户

```bash
# 两台节点都需要执行
groupadd kingbase
useradd -g kingbase -m -d /home/kingbase -s /bin/bash kingbase
echo "kingbase:kingbase" | chpasswd
```

### 2. 初始化用户目录

```bash
cp -a /etc/skel/. /home/kingbase/
chown -R kingbase:kingbase /home/kingbase
```

### 3. 检查/设置服务器语言

```bash
echo $LANG
export LANG=zh_CN.UTF-8
```

### 4. 更新 /etc/hosts

```bash
# 两台节点都需要执行
echo "192.168.56.11 kingbase1" >> /etc/hosts
echo "192.168.56.12 kingbase2" >> /etc/hosts
```

---

## 三、单机库部署

### 参考文档

详细步骤参考：[单机部署全流程](https://github.com/hhhhhyz-11/ai-memory/blob/master/kingbase-v9r2c4/01-%E5%8D%95%E6%9C%BA%E9%83%A8%E7%BD%B2%E5%85%A8%E6%B5%81%E7%A8%8B-2026-04-07.md)

### 关键路径

| 项目 | 路径 |
|------|------|
| 单机安装目录 | /home/kingbase |
| 单机数据目录 | /home/kingbase/data |
| 集群部署目录 | /home/kingbase/cluster |

---

## 四、集群部署

### 1. 目录结构准备

**在两台节点创建目录：**

```bash
mkdir -p /home/kingbase/cluster/kingbase
mkdir -p /home/kingbase/cluster/oracle
```

### 2. 复制文件到集群目录

**在 KingBase1 上执行：**

```bash
# 复制 license.dat
cp ./kingbase/KESRealPro/V009R002C014/Server/bin/license.dat /home/kingbase/cluster/kingbase/bin/

# 复制 db.zip
cp db.zip /home/kingbase/cluster/kingbase/

# 复制到 KingBase2
scp license.dat kingbase@192.168.56.12:/home/kingbase/cluster/kingbase/bin/
scp db.zip kingbase@192.168.56.12:/home/kingbase/cluster/kingbase/
```

### 3. 解压 db.zip

**两台节点都需要执行：**

```bash
cd /home/kingbase/cluster/kingbase/
unzip db.zip
```

### 4. 配置 install.conf

**文件路径：** `/home/kingbase/cluster/oracle/install.conf`

```conf
all_ip=(192.168.56.11 192.168.56.12)
install_dir="/home/kingbase/cluster/kingbase"
zip_package="/home/kingbase/cluster/kingbase/db.zip"
license_file=(license.dat)
db_user="system"
db_password="kingbase"
db_port="54321"
db_auth="scram-sha-256"
db_checksums="yes"
archive_mode="always"
encoding="UTF8"
locale="zh_CN.UTF-8"
trusted_servers="192.168.56.1"
virtual_ip="192.168.56.15/24"
net_device=(eth1 eth1)
net_device_ip=(192.168.56.11 192.168.56.12)
deploy_by_sshd=0
```

**配置说明：**

| 参数 | 值 | 说明 |
|------|-----|------|
| all_ip | (192.168.56.11 192.168.56.12) | 第一个为主节点 |
| install_dir | /home/kingbase/cluster/kingbase | 集群安装目录 |
| virtual_ip | 192.168.56.15/24 | VIP |
| net_device | (eth1 eth1) | 网卡名称 |
| deploy_by_sshd | 0 | SSH直连模式 |

### 5. 配置 SSH 互信

```bash
cd /home/kingbase/cluster/kingbase/
sh trust_cluster.sh
```

**预期输出：**
```
[INFO] [] check ssh connection success!
```

### 6. 修正目录结构（重要！）

**⚠️ 安装目录结构必须包含 Server/bin/**

```bash
cd /home/kingbase/cluster/kingbase/
mkdir -p Server
mv bin include lib share Server/
```

### 7. 配置 securecmdd 服务

**两台节点都需要执行：**

```bash
cd /home/kingbase/cluster/kingbase/bin/

# 初始化
./sys_HAscmdd.sh init

# 启动
./sys_HAscmdd.sh start

# 验证
netstat -tlunp |grep 8890
```

### 8. 验证 securecmdd 互信

**KingBase1 上执行：**
```bash
./sys_securecmd root@192.168.56.12 'whoami'
./sys_securecmd kingbase@192.168.56.12 'whoami'
```

**KingBase2 上执行：**
```bash
./sys_securecmd root@192.168.56.11 'whoami'
./sys_securecmd kingbase@192.168.56.11 'whoami'
```

### 9. 关闭防火墙（测试环境）

**两台节点都需要执行：**

```bash
systemctl stop firewalld
systemctl disable firewalld
```

### 10. 执行集群部署

**以 kingbase 用户在主节点执行：**

```bash
su - kingbase
cd /home/kingbase/cluster/oracle
sh cluster_install.sh
```

---

## 五、部署结果

### 集群状态

```
 ID | Name  | Role    | Status  | Upstream | repmgrd | PID   | Paused? | Upstream last seen
----+-------+---------+---------+----------+---------+-------+---------+--------------------
 1  | node1 | primary | * running |          | running | 12650 | no      | n/a
 2  | node2 | standby | running  | node1    | running | 5041  | no      | 0 second(s) ago
```

### 关键路径

| 项目 | 路径 |
|------|------|
| 集群安装目录 | /home/kingbase/cluster/kingbase |
| 数据库数据目录 | /home/kingbase/cluster/kingbase/Server/data |
| KBHA 日志 | /home/kingbase/cluster/kingbase/Server/log/kbha.log |
| 集群服务管理 | /home/kingbase/cluster/kingbase/bin/sys_HAscmdd.sh |

---

## 六、常见问题

### 问题1：目录结构错误

**错误：**
```
[ERROR] [RWC-07455] can not connect to 192.168.56.11 by '/home/kingbase/cluster/kingbase/Server/bin/sys_securecmd'
```

**原因：** install_dir 路径下缺少 Server/bin/ 目录结构

**解决：**
```bash
cd /home/kingbase/cluster/kingbase/
mkdir -p Server
mv bin include lib share Server/
```

### 问题2：ping 不通网关

**错误：**
```
[ERROR] [RWC-08200] Failed to ping trusted_servers on host 192.168.56.1
```

**原因：** 防火墙阻止了 ICMP

**解决：**
```bash
systemctl stop firewalld
systemctl disable firewalld
```

---

## 七、集群管理

### 查看集群状态

```bash
cd /home/kingbase/cluster/kingbase/bin/
./sys_HAscmdd.sh show
```

### 启停集群

```bash
# 停止
./sys_HAscmdd.sh stop

# 启动
./sys_HAscmdd.sh start

# 重启
./sys_HAscmdd.sh restart
```

### 连接数据库

```bash
# 本地连接
/home/kingbase/Server/bin/ksql -U system -d test

# VIP 连接
/home/kingbase/Server/bin/ksql -U system -d test -h 192.168.56.15 -p 54321
```

---

## 八、⚠️ 注意事项

1. **安装用户**：集群部署脚本必须用 kingbase 用户执行
2. **目录结构**：install_dir 路径下必须包含 Server/bin/ 目录
3. **防火墙**：测试环境建议关闭防火墙，生产环境需放行对应端口
4. **trusted_servers**：需配置为可达的网关 IP，或留空
5. **单机部署**：生产环境必须先完成单机部署验证
