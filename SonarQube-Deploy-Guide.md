# SonarQube Docker Compose 部署指南

---

## 1. 搭建 SonarQube 代码检测平台（Docker Compose + 外置 PostgreSQL）

### 1.1 创建持久化目录

```bash
mkdir -p /home/SonarQube/postgres/data
mkdir -p /home/SonarQube/logs
mkdir -p /home/SonarQube/data
mkdir -p /home/SonarQube/extensions
```

### 1.2 目录权限配置 ⚠️

SonarQube 容器内以 `sonarqube` 用户（UID 1000）运行，需要给目录授权：

```bash
# 方式一：直接授权（推荐）
chmod -R 777 /home/SonarQube/data
chmod -R 777 /home/SonarQube/logs
chmod -R 777 /home/SonarQube/extensions
chmod -R 777 /home/SonarQube/postgres/data

# 方式二：修改所有者（更安全）
chown -R 1000:1000 /home/SonarQube/data
chown -R 1000:1000 /home/SonarQube/logs
chown -R 1000:1000 /home/SonarQube/extensions
chown -R 999:999 /home/SonarQube/postgres/data   # PostgreSQL 用户 UID 是 999
```

### 1.3 创建 docker-compose.yml

```bash
cd /home/SonarQube
vim docker-compose.yml
```

```yaml
version: '3'

services:

 postgres:
  image: postgres:12
  container_name: postgres
  restart: always
  volumes:
   - ./postgres/data:/var/lib/postgresql/data
   - /etc/localtime:/etc/localtime:ro
  ports:
   - "5432:5432"
  environment:
   POSTGRES_USER: sonar
   POSTGRES_PASSWORD: Sonar@2026_com.cn
   POSTGRES_DB: sonar
   TZ: Asia/Shanghai

 sonar:
  image: sonarqube:lts-community 
  container_name: sonarqube
  restart: always
  privileged: true
  depends_on:
   - postgres
  ports:
   - "9000:9000"
  volumes:
   - ./logs:/opt/sonarqube/logs
   - ./data:/opt/sonarqube/data
   - ./extensions:/opt/sonarqube/extensions
  environment:
   SONAR_JDBC_USERNAME: sonar
   SONAR_JDBC_PASSWORD: Sonar@2026_com.cn
   SONAR_JDBC_URL: jdbc:postgresql://postgres:5432/sonar
  ulimits:
   nofile:
    soft: 65536
    hard: 65536
```

### 1.4 启动 SonarQube

```bash
# 启动服务
cd /home/SonarQube
docker-compose up -d

# 查看启动状态
docker ps

# 查看日志（确认连接 PostgreSQL）
docker logs -f sonarqube 2>&1 | grep -i jdbc

# 看到以下内容表示成功：
# Create JDBC data source for jdbc:postgresql://postgres:5432/sonar
```

### 1.5 访问 SonarQube

- **访问地址：** `http://服务器IP:9000`
- **默认账号：** `admin` / `admin`

---

## 2. 配置 GitLab CI

### 2.1 在 SonarQube 创建项目

1. 访问 `http://服务器IP:9000`
2. 点击"项目" → "手动创建"
3. 输入项目名称和分支

### 2.2 生成 SONAR_TOKEN

1. 进入项目 → "我的账号" → "安全"
2. 填写令牌名称，选择"永久"
3. 点击生成，**复制保存好 Token**（只显示一次）

### 2.3 在 GitLab 添加变量

进入项目 → 设置 → CI/CD → 变量，添加：

| 变量名 | 值 |
|-------|-----|
| `SONAR_HOST_URL` | `http://新服务器IP:9000` |
| `SONAR_TOKEN` | 生成的 Token |

### 2.4 .gitlab-ci.yml（无需修改）

```yaml
stages:
 - build

variables:
 MAVEN_OPTS: "-Dmaven.repo_local=$CI_PROJECT_DIR/.m2/repository"

cache:
 key: maven-cache
 paths:
 - .m2/repository

build-and-sonar:
 stage: build
 image: maven:3.9.6-eclipse-temurin-11
 script:
 - mvn -B --no-transfer-progress -T 1C clean verify sonar:sonar \
 -DskipTests \
 -Dsonar.projectKey=bike-server \
 -Dsonar.host.url=$SONAR_HOST_URL \
 -Dsonar.login=$SONAR_TOKEN
 only:
 - master
```

---

## 3. 常用命令

```bash
# 停止服务
docker-compose down

# 重启服务
docker-compose restart

# 查看日志
docker logs -f sonarqube
docker logs -f postgres

# 进入容器
docker exec -it sonarqube /bin/bash
docker exec -it postgres psql -U sonar -d sonar
```

---

## ⚠️ 常见问题

### 权限不足

如果启动报错 `Permission denied`，执行：

```bash
chmod -R 777 /home/SonarQube/data
chmod -R 777 /home/SonarQube/logs
chmod -R 777 /home/SonarQube/extensions
```

### 连接不上 PostgreSQL

检查 PostgreSQL 是否先启动成功：

```bash
docker logs postgres
docker exec -it postgres psql -U sonar -d sonar -c "SELECT 1;"
```
