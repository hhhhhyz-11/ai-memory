# PostgreSQL 15 Docker 容器化迁移方案

> 从物理服务器 Systemd 管理 → Docker 容器化
>
> 源环境：192.168.0.50，PostgreSQL 15（Systemd 管理）
> 目标环境：192.168.0.53，Docker 容器 PostgreSQL 15.15


## 一、迁移背景

| 项目 | 旧环境 | 新环境 |
|------|--------|--------|
| 部署方式 | Systemd 守护进程 | Docker 容器 |
| 版本 | PostgreSQL 15.15 | postgres:15.15 |
| 数据目录 | /var/lib/pgsql/15/data | /home/postgres15/data |
| 管理用户 | postgres（Systemd 启动） | postgres（容器内） |
| 连接密码 | Yst@163.com | Yst@163.com |

**迁移内容：**
- 19 个业务数据库
- 所有角色（用户）和权限
- PostGIS 空间扩展
- 中文语言环境 zh_CN.UTF-8


## 二、迁移前准备

### 2.1 源端数据导出（在 192.168.0.50 上执行）

```bash
# 1. 停止应用访问，确保数据静止（可选，如果允许短暂停服）
# systemctl stop <应用服务名>

# 2. 停止 PostgreSQL
systemctl stop postgresql-15

# 3. 执行全库导出（包含数据库、用户、权限、模式）
sudo -u postgres /usr/pgsql-15/bin/pg_dumpall > /home/postgres_full_dump.sql

# 4. 确认导出成功
ls -lh /home/postgres_full_dump.sql

# 5. 传输到目标机器
scp /home/postgres_full_dump.sql root@192.168.0.53:/home/
```

### 2.2 目标端环境检查（在 192.168.0.53 上执行）

```bash
# 确认 Docker 已安装
docker --version

# 确认 docker-compose 或 docker compose 已安装
docker compose version
```


## 三、自定义 Dockerfile（解决官方镜像缺陷）

官方 `postgres:15.15` 镜像缺少两个关键组件，必须通过自定义 Dockerfile 补上：

1. **中文语言包 zh_CN.UTF-8** — 不然建库时报 `invalid locale name`
2. **PostGIS 3 扩展** — 涉及地图/空间数据的业务必需

### 3.1 创建 Dockerfile

在 `/home/postgres15/` 目录下创建 `Dockerfile`：

```dockerfile
FROM postgres:15.15

# ============================================================
# 解决中文语言环境缺失问题
# 官方镜像默认没有 zh_CN.UTF-8，会导致创建数据库时报错：
# "invalid locale name: zh_CN.UTF-8"
# ============================================================
RUN apt-get update && apt-get install -y \
locales \
&& localedef -i zh_CN -c -f UTF-8 -A /usr/share/locale/locale.alias zh_CN.UTF-8 \
&& rm -rf /var/lib/apt/lists/*

# 设置容器默认语言环境
ENV LANG=zh_CN.utf8
ENV LC_ALL=zh_CN.utf8

# ============================================================
# 解决 PostGIS 空间扩展缺失问题
# 执行 "CREATE EXTENSION postgis;" 时如果没装会报错：
# "ERROR: could not open extension control file"
# ============================================================
RUN apt-get update && apt-get install -y \
postgresql-15-postgis-3 \
postgresql-15-postgis-3-scripts \
&& rm -rf /var/lib/apt/lists/*
```

### 3.2 创建 docker-compose.yml

在 `/home/postgres15/` 目录下创建 `docker-compose.yml`：

```yaml
version: '3.8'

services:
db:
build: .
container_name: postgres15
restart: always
environment:
# 管理员密码（导入后会被旧密码覆盖，需手动重置）
- POSTGRES_PASSWORD=Yst@163.com
# 容器时区
- TZ=Asia/Shanghai
ports:
# 映射到宿主机端口，外部应用通过 <53IP>:5432 访问
- "5432:5432"
volumes:
# 数据持久化目录（宿主机挂载）
- /home/postgres15/data:/var/lib/postgresql/data
# 导入脚本（方便容器内直接执行导入）
- /home/postgres_full_dump.sql:/tmp/postgres_full_dump.sql
```

### 3.3 目录结构

```
/home/postgres15/
├── Dockerfile
├── docker-compose.yml
└── data/     # 运行后自动创建，存放 PG 数据文件
```


## 四、数据导入（完整流程）

### 4.1 初始化目录（重要！）

```bash
cd /home/postgres15

# 创建数据目录
mkdir -p data

# 【关键】Docker 容器内的 postgres 用户 UID 是 999
# 必须将挂载目录的所有权交给 UID 999，否则容器启动失败
chown -R 999:999 data

# 【重要】如果是重试迁移（之前失败过），必须彻底清理残留数据
# 不清理会导致大量 "already exists" 错误
rm -rf data/*
```

### 4.2 构建并启动容器

```bash
cd /home/postgres15

# 构建镜像 + 启动容器
docker compose up -d --build

# 确认容器运行中
docker ps | grep postgres15
```

**常见启动失败原因：**

| 错误现象 | 原因 | 解决 |
|---------|------|------|
| Permission denied | 目录权限不对 | `chown -R 999:999 data` |
| invalid locale name | 没装 zh_CN.UTF-8 | 检查 Dockerfile 的 localedef |
| extension postgis not available | 没装 PostGIS | 检查 Dockerfile 的 apt-get |

### 4.3 执行数据恢复

```bash
# 导入全量备份（数据库、用户、权限全部导入）
docker exec -i postgres15 psql -U postgres -f /tmp/postgres_full_dump.sql

# 导入过程会看到很多输出，忽略那些表创建失败的连锁反应（通常是权限依赖问题，修复后会消失）
```

### 4.4 修正管理员密码（重要！）

⚠️ **必须执行！** `pg_dumpall` 会导出旧密码，导入后容器设置的密码会被覆盖。

```bash
# 重置 postgres 密码
docker exec -it postgres15 psql -U postgres -c "ALTER USER postgres WITH PASSWORD 'Yst@163.com';"

# 验证密码修改成功
docker exec -it postgres15 psql -U postgres -c "SELECT 1;"
```

### 4.5 配置远程访问（pg_hba.conf）

容器默认只允许本地连接，外部访问需要修改 `pg_hba.conf`：

```bash
# 进入容器
docker exec -it postgres15 sh

# 在容器内编辑 pg_hba.conf
cat >> /var/lib/postgresql/data/pg_hba.conf << 'EOF'

# 允许外部应用访问（根据实际 IP 段调整）
host  all  all  0.0.0.0/0  md5
host  all  all  ::0/0    md5
EOF

# 重载配置（无需重启容器）
psql -U postgres -c "SELECT pg_reload_conf();"
exit
```


## 五、迁移后验证清单

### 5.1 环境检查

```bash
# 查看所有数据库（确认 19 个库都在，编码为 utf8）
docker exec -it postgres15 psql -U postgres -c "\l"
```

**期望结果：** 所有数据库的 Encoding 为 `UTF8`，Collate 和 Ctype 为 `zh_CN.UTF-8`

### 5.2 用户权限检查

```bash
# 查看所有角色（用户）
docker exec -it postgres15 psql -U postgres -c "\du"
```

### 5.3 PostGIS 插件检查

```bash
# 在涉及空间数据的库上执行
docker exec -it postgres15 psql -U postgres -d <空间数据库名> -c "SELECT postgis_full_version();"

# 期望返回类似：
# POSTGIS="3.3.2" [EXTENSION] GEOS="3.11.0" PROJ="9.2.0" ...
```

```bash
# 检查空间参考表是否有数据（正常应该有约 8500 条）
docker exec -it postgres15 psql -U postgres -d <空间数据库名> -c "SELECT count(*) FROM spatial_ref_sys;"
```

### 5.4 数据量核对

```bash
# 抽查核心业务表记录数
docker exec -it postgres15 psql -U postgres -d <业务库名> -c "SELECT count(*) FROM <表名>;"

# 对比源库记录数，确认数据完整
```

### 5.5 连接性测试

```bash
# 从其他服务器测试连接
psql -h 192.168.0.53 -U postgres -d <库名>

# 或用 Navicat/DBeaver 等工具连接测试
# 主机：192.168.0.53
# 端口：5432
# 用户：postgres
# 密码：Yst@163.com
```


## 六、核心避坑点汇总

| 风险点 | 现象 | 解决方案 |
|--------|------|---------|
| **Locale 缺失** | 报错 `invalid locale name: "zh_CN.UTF-8"` | Dockerfile 中 `apt-get install locales` + `localedef -i zh_CN` |
| **PostGIS 缺失** | 报错 `extension "postgis" is not available` | Dockerfile 中 `apt-get install postgresql-15-postgis-3` |
| **数据残留** | 修复环境后重试，报大量 `already exists` | `rm -rf /home/postgres15/data/*` 彻底清理 |
| **权限冲突** | 容器启动失败或 `Permission denied` | `chown -R 999:999 data` |
| **密码覆盖** | 镜像配置的密码失效，应用连不上 | 导入后手动 `ALTER USER postgres WITH PASSWORD` |
| **伪语法错误** | 导入时大量表创建失败的连锁反应 | 忽略它们，后续修复插件/语言环境后重建即可 |


## 七、应用切换步骤

确认 PostgreSQL Docker 运行正常后，按以下顺序切换：

### 7.1 确认旧库已停止写入

在应用侧确认没有新数据写入。

### 7.2 更新应用数据库连接地址

将应用的数据库连接从：
```
192.168.0.50:5432
```
改为：
```
192.168.0.53:5432
```

Spring Boot 项目通常是修改 `application.yml`：
```yaml
spring:
datasource:
url: jdbc:postgresql://192.168.0.53:5432/<库名>
username: postgres
password: Yst@163.com
```

### 7.3 重启应用

```bash
# 在应用服务器上
systemctl restart <应用服务名>

# 观察日志确认连接成功
journalctl -u <应用服务名> -f
```


## 八、回滚方案

如果迁移失败，切回旧库：

```bash
# 1. 在 50 上恢复 PostgreSQL
systemctl start postgresql-15

# 2. 确认启动成功
systemctl status postgresql-15

# 3. 将应用连接改回 50
# 4. 重启应用
```


## 九、运维命令

```bash
# 启动
docker compose -f /home/postgres15/docker-compose.yml up -d

# 停止
docker compose -f /home/postgres15/docker-compose.yml down

# 查看状态
docker ps | grep postgres15

# 进入容器
docker exec -it postgres15 psql -U postgres

# 查看日志
docker logs -f postgres15

# 重启
docker restart postgres15
```
