# 金仓监控软件 KEMCC 安装指南

> 来源：[Kemcc快速安装指南_人大金仓_2025-07-V1.0](./attachments/Kemcc快速安装指南_1776907425137_20c9ad.docx)
> 整理：OpenClaw
> 日期：2026-04-23

---

## 一、产品概述

KEMCC（Kingbase Enterprise Monitoring and Control Center）是北京人大金仓信息技术股份有限公司出品的数据库监控管理软件，用于监控和管理 KingBase（金仓）数据库实例。

**官方默认端口一览**

| 端口 | 用途 |
|------|------|
| 19000 | KEMCC Web 管控平台访问端口 |
| 54321 | KEMCC 内置数据库端口 |
| 8081 | KStudio 访问端口 |
| 54544 | Collector 采集服务端口 |
| 11234 | LAC 授权管理服务端口 |

> ⚠️ 如端口冲突，可在安装程序中自定义修改。

---

## 二、环境要求

### 2.1 硬件环境

| 项目 | 要求 |
|------|------|
| CPU | 64 位 |
| 内存 | 16 GB 以上 |
| 软件包磁盘空间 | 2 GB |
| 安装路径磁盘空间 | 3 GB + 5 GB × 被管理实例数 |

### 2.2 软件环境

**支持的操作系统：**
- Red Hat / CentOS
- 红旗 Linux
- 麒麟 Kylin
- UOS
- 中科方德

**运行依赖（so 库）：**
```
libuuid.so.1
libcrypt.so.1
libdl.so.2
libm.so.6
libpthread.so.0
libc.so.6
```

---

## 三、安装准备

### 3.1 环境检查

```bash
# 检查 CPU（64位）
lscpu

# 检查内存（16GB+）
free -g

# 检查硬盘空间
df -h

# 检查操作系统时间
date
# 如不正确则修正：
date -s "2025-07-01 12:00:00"
```

### 3.2 创建专用用户

> ⚠️ **必须使用非 root 用户安装**，这是硬性要求。

```bash
# 创建用户
useradd -m -U -s /bin/bash kemcc -d /home/kemcc
# 参数说明：
#   -m    创建用户家目录
#   -U    创建同名用户组

# 设置密码
passwd kemcc
```

### 3.3 创建目录并授权

```bash
# 安装包存放目录
mkdir /data/install
chown -R kemcc:kemcc /data/install

# 监控软件安装目录
mkdir -p /data/kemcc
chown -R kemcc:kemcc /data/kemcc

# ⚠️ 无论规划到哪个目录，属主属组必须是 kemcc 用户
```

---

## 四、安装步骤

### 4.1 上传并解压安装包

```bash
# 使用 U盘/FTP/Xshell 等工具上传安装包到服务器
# 假设上传到 /data/install/

# 解压
cd /data/install/
tar zxvf KEMCC-V003R001C003B0004-x86.tar.gz

# 更改属主属组
cd /data/install/
chown -R kemcc:kemcc *
```

### 4.2 命令行方式安装

> 如果当前是 root 用户，先切换到 kemcc 用户，再用 `-i console` 参数直接进入命令行安装模式。

```bash
su - kemcc
cd /data/install
bash setup.sh -i console
```

安装流程如下：

| 步骤 | 操作 |
|------|------|
| 1 | 显示简介，按 `Enter` 继续 |
| 2 | 阅读许可协议，按 `Enter` 直至出现 "是否接受"，输入 `Y`（输入 N 则退出） |
| 3 | 选择安装集：`1`=完全安装 / `2`=LAC授权管理服务，默认选 `1` |
| 4 | 输入安装路径（绝对路径），确认后继续 |
| 5 | 填入服务信息配置 |
| 6 | 等待安装完成 |

### 4.3 执行 root.sh 脚本（必须）

安装完成后，**必须由 root 用户**执行此脚本，将 KEMCC 注册为系统服务并实现开机自启：

```bash
su root
bash /data/install/1/scripts/root.sh
```

执行后会提示启动成功。如未成功，根据提示查看相关 log 日志。

---

## 五、访问 KEMCC

```
http://<管控平台所在机器IP>:19000/
```

使用安装时配置的账号密码登录即可进入 Web 管理界面。

---

## 六、纳管现有数据库实例

### 6.1 新增平台

1. 进入 **IaaS 管理** → 点击 **新增**
2. 配置信息选择 **非云平台** → 保存

### 6.2 纳管服务器

1. 进入平台 → **纳管服务器**
2. 点击 **添加实例服务器**
3. 输入被纳管的服务器信息（IP、SSH 端口、用户名/密码等）
4. 点击 **纳管服务器** → 等待标准化过程完成

### 6.3 纳管数据库

1. **实例管理** → **实例列表** → 添加实例
2. 输入被纳管的数据库信息（Host、Port、数据库名、用户名/密码）
3. 完成纳管后可直接打开监控视图

---

## 七、启停与管理

### 7.1 通过系统服务管理

```bash
# 停止
systemctl stop kemcc

# 启动
systemctl start kemcc

# 重启
systemctl restart kemcc

# 查看状态
systemctl status kemcc
```

### 7.2 通过脚本管理

```bash
# 停止
kemcc-ctl stop

# 启动
kemcc-ctl start

# 查看状态
kemcc-ctl status
```

---

## 八、卸载

### 8.1 安装用户执行卸载脚本

```bash
su - kemcc
# 执行 uninstall.sh 或对应卸载脚本
```

### 8.2 root 用户执行卸载脚本

```bash
su root
# 执行 root 用户专属卸载脚本
```

---

## 九、运维注意事项

1. **端口冲突**：安装前检查 19000/54321/8081/54544/11234 是否被占用
2. **非 root 安装**：强制要求，创建专用 `kemcc` 用户并授权目录
3. **root.sh 必须执行**：否则服务无法注册为系统服务，开机不会自启
4. **磁盘规划**：被管实例数量多时，按 `3GB + 5GB × 实例数` 提前规划存储
5. **防火墙**：若需远程访问，确保 `19000` 端口在防火墙中开放

---

## 十、相关文件

| 文件 | 说明 |
|------|------|
| `KEMCC-V003R001C003B0004-x86.tar.gz` | 安装包 |
| `setup.sh` | 安装脚本 |
| `root.sh` | 服务注册脚本（root 执行） |
| `kemcc-ctl` | 服务控制脚本 |

---

*整理自人大金仓官方文档，如有不一致请以官方最新版本为准。*
