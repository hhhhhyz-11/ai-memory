# MySQL 数据备份与 Docker 恢复指南

> 旧服务器（Systemd 管理）MySQL 8.0 备份 → 新服务器 Docker MySQL 8.0 恢复

## 迁移概述

| 项目 | 说明 |
|------|------|
| 迁移方向 | Systemd MySQL → Docker MySQL |
| 原版本 | MySQL 8.0.39 |
| 新版本 | MySQL 8.0.43 |
| 备份文件大小 | 1.3M |

---

## 第一部分：旧服务器备份 MySQL

### 1.1 执行备份

```bash
mysqldump -u root -p \
--all-databases \
--single-transaction \
--triggers \
--routines \
--events \
--set-gtid-purged=OFF \
> /tmp/mysql_backup_all_$(date +%Y%m%d).sql
```

输入密码后等待完成。

### 1.2 验证备份文件

```bash
ls -lh /tmp/mysql_backup_all_*.sql
```

确认文件大小正常（不为 0）。

### 1.3 传输备份到新服务器

```bash
scp /tmp/mysql_backup_all_20260326.sql root@新服务器IP:/tmp/
```

---

## 第二部分：新服务器启动 Docker MySQL

### 2.1 创建数据目录

```bash
mkdir -p /home/mysql/data
chown -R 999:999 /home/mysql/data
```

### 2.2 启动 Docker MySQL 容器

```bash
docker run -d \
 --name mysql \
 -p 3306:3306 \
 -e MYSQL_ROOT_PASSWORD='Yunst_50_com.cn' \
 -v /home/mysql/data:/var/lib/mysql \
 mysql:8.0.43
```

### 2.3 等待容器完全启动

```bash
docker logs -f mysql
```

看到以下日志表示启动成功：

```
[System] Ready for connections
```

按 `Ctrl+C` 退出日志。

### 2.4 确认容器状态

```bash
docker ps
```

确保 Status 为 `Up`。

---

## 第三部分：导入备份数据

### 3.1 执行导入

```bash
docker exec -i mysql mysql -u root -pYunst_50_com.cn < /tmp/mysql_backup_all_20260326.sql
```

> 注意：密码 `Yunst_50_com.cn` 直接跟在 `-p` 后面，中间没有空格。

### 3.2 验证导入结果

```bash
docker exec -i mysql mysql -u root -pYunst_50_com.cn -e "SHOW DATABASES;"
```

能看到原服务器的所有数据库即为成功。

---

## 常见问题

### Q1：导入时提示 "Can't connect to local MySQL server through socket"

**原因**：容器还未完全启动就执行了导入命令

**解决**：确认容器 Status 为 `Up` 后再导入

### Q2：导入后远程连接失败

**原因**：原备份中的用户 host 限制（如 `root@192.168.%` 不包含新服务器地址）

**解决**：

```sql
-- 创建允许远程登录的 root 用户
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'Yunst_50_com.cn';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
```

### Q3：密码错误

**原因**：Docker 启动时指定的密码与备份中的密码不一致

**解决**：删除容器和数据目录，重新用正确密码启动

```bash
docker stop mysql
docker rm mysql
rm -rf /home/mysql/data/*
docker run -d \
 --name mysql \
 -p 3306:3306 \
 -e MYSQL_ROOT_PASSWORD='正确密码' \
 -v /home/mysql/data:/var/lib/mysql \
 mysql:8.0.43
```

---

## 相关操作命令速查

```bash
# 启动容器
docker start mysql

# 停止容器
docker stop mysql

# 重启容器
docker restart mysql

# 进入 MySQL 控制台
docker exec -it mysql mysql -u root -p

# 查看容器日志
docker logs -f mysql

# 查看运行状态
docker ps
```

---

*文档创建时间：2026-03-26*
