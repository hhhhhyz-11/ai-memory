# GitLab + SonarQube 流水线代码质量检查实施手册

> **文件编号：** SJ-IMP-2026-001
> **版本：** V1.0
> **编制日期：** 2026-04-27
> **对应规范：** SJ-STD-2026-001
> **适用范围：** Java Maven 项目技术实施人员

---

## 1. 概述

本手册是《GitLab + SonarQube 流水线代码质量检查实施规范》的配套实施文档，用于指导技术人员实际部署和接入流水线。

**配套关系：**

| 文档 | 用途 |
|------|------|
| 实施规范（SJ-STD） | 供评审和项目管理：背景、前置要求、分支规则、各阶段计划 |
| 本手册（SJ-IMP） | 供技术人员实施：部署步骤、配置细节、操作命令 |

---

## 2. 环境信息

### 2.1 当前环境

| 组件 | 地址 | 账号 |
|------|------|------|
| GitLab | http://192.168.0.18:8080 | — |
| SonarQube | http://192.168.0.18:9000 | admin / Sonar@2026_com.cn |
| PostgreSQL（SonarQube DB） | 192.168.0.18:5432 | sonar / Sonar@2026_com.cn |
| MinIO | http://192.168.0.18:9000 | minioadmin / minioadmin |
| GitLab Runner | 容器名 gitlab-runner | — |

### 2.2 GitLab CI/CD 变量（需在 GitLab Settings → CI/CD → Variables 中配置）

| 变量名 | 值 | 说明 |
|--------|-----|------|
| `SONAR_HOST_URL` | http://192.168.0.18:9000 | SonarQube 服务地址 |
| `SONAR_MASTER` | sqp_xxxxxxxxxxxx | master 分支项目 Token |
| `SONAR_UAT` | sqp_xxxxxxxxxxxx | uat 分支项目 Token |
| `MERGE_TOKEN` | glpat-xxxxxxxxxxxx | GitLab PAT（需 api 权限） |
| `DINGTALK_WEBHOOK` | https://oapi.dingtalk.com/robot/send?access_token=xxx | 钉钉 Webhook |
| `MINIO_ACCESS_KEY` | minioadmin | MinIO 用户名 |
| `MINIO_SECRET_KEY` | minioadmin | MinIO 密码 |
| `SONAR_HOST_URL` | http://192.168.0.18:9000 | SonarQube 地址 |

---

## 3. 部署实施步骤

### 3.1 SonarQube 部署

**Step 1：创建目录并启动**

```bash
mkdir -p /home/sonarqube/{data,logs,extensions}
cd /home/sonarqube

cat > docker-compose.yml << 'EOF'
version: '3'
services:
  postgres:
    image: postgres:12
    container_name: postgres
    restart: always
    volumes:
      - ./data:/var/lib/postgresql/data
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
      SONAR_JAVA_OPTS: "-Xmx4g"
    ulimits:
      nofile:
        soft: 65536
        hard: 65536
EOF

docker-compose up -d
```

**Step 2：等待启动（约3-5分钟）**

```bash
# 查看启动日志
docker-compose logs -f sonar

# 确认容器运行正常
docker ps | grep sonarqube
```

**Step 3：初始化 SonarQube**

- 访问 http://192.168.0.18:9000
- 首次登录：账号 `admin`，密码 `admin`
- 登录后修改密码为 `Sonar@2026_com.cn`

**Step 4：创建 Token**

1. 进入 SonarQube → My Account → Security → Users
2. 点击 Token 输入名称（如 `gitlab-ci-token`）生成 Token
3. **保存 Token**，后续配置 GitLab CI/CD 变量时使用

> **注意：** Token 只显示一次，关闭页面后无法找回，需重新生成。

---

### 3.2 GitLab Runner 部署与注册

**Step 1：启动 Runner 容器**

```bash
docker run -d \
  --name gitlab-runner \
  --restart always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /home/gitlab-runner/config:/etc/gitlab-runner \
  gitlab/gitlab-runner:latest
```

**Step 2：注册 Runner**

```bash
docker exec -it gitlab-runner gitlab-runner register
```

交互输入：

```
# GitLab 实例地址
Please enter the GitLab instance URL (for example: https://gitlab.com):
http://192.168.0.18:8080

# Registration Token（从 GitLab Settings → CI/CD → Runners 获取）
Please enter the registration token:
xxxxxxxxxxxxxxxxxxxx

# Runner 描述
Please enter a description for the runner:
sonar-runner

# Runner Tag（用于匹配 job）
Please enter a tag for the runner:
yyyz

# 执行器类型
Please select an executor:
docker

# 默认镜像
Please enter the default Docker image:
maven:3.9.6-eclipse-temurin-11
```

**Step 3：确认 Runner 已注册**

```bash
# 查看 Runner 配置
docker exec -it gitlab-runner gitlab-runner verify

# 列出所有 Runner
docker exec -it gitlab-runner gitlab-runner list
```

**Step 4：在 GitLab 确认 Runner 已激活**

- GitLab → Settings → CI/CD → Runners
- 确认 Runner 显示为绿色 `✓` 可用状态

---

### 3.3 CI 镜像构建

sonar-ci 镜像是运行流水线 job 的环境，内置 Maven + Python + MinIO Client + WeasyPrint。

**Step 1：下载 MinIO Client**

```bash
cd /path/to/gitlab-ci/
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
```

**Step 2：构建镜像**

```bash
docker build -f Dockerfile.sonar -t sonar-ci:20260323 .
```

**Step 3：验证镜像**

```bash
docker run --rm sonar-ci:20260323 \
  java -version && mvn -version && python3 --version && mc --version
```

**Step 4：推送镜像到私有仓库（如需）**

```bash
docker tag sonar-ci:20260323 registry.example.com/sonar-ci:20260323
docker push registry.example.com/sonar-ci:20260323
```

---

### 3.4 项目接入

**Step 1：配置 GitLab CI/CD 变量**

GitLab → 项目 → Settings → CI/CD → Variables：

| 变量名 | 值 | 保护级别 |
|--------|-----|---------|
| `SONAR_HOST_URL` | http://192.168.0.18:9000 | ✅ |
| `SONAR_UAT` | sqp_xxxxxxxx | ✅ |
| `SONAR_MASTER` | sqp_xxxxxxxx | ✅ |
| `MERGE_TOKEN` | glpat-xxxxxxxx | ✅ |
| `DINGTALK_WEBHOOK` | https://oapi.dingtalk.com/robot/send?access_token=xxx | ✅ |
| `MINIO_ACCESS_KEY` | minioadmin | ✅ |
| `MINIO_SECRET_KEY` | minioadmin | ✅ |

**Step 2：在项目根目录创建 .gitlab-ci.yml**

```yaml
stages:
  - analysis
  - merge

variables:
  MAVEN_OPTS: "-Dmaven.repo.local=$CI_PROJECT_DIR/.m2/repository"
  GIT_DEPTH: "0"

cache:
  key: ${CI_PROJECT_NAME}-maven
  policy: pull-push
  paths:
    - .m2/repository

# ========== UAT 分支 ==========

scan-uat:
  stage: analysis
  image: sonar-ci:20260323
  tags:
    - yyyz
  script:
    - mvn -B -T 2C clean package sonar:sonar \
      -DskipTests \
      -Dsonar.projectKey=bike-server-uat \
      -Dsonar.host.url=$SONAR_HOST_URL \
      -Dsonar.login=$SONAR_UAT \
      -Dsonar.sourceEncoding=UTF-8 \
      -Dsonar.java.binaries=target/classes \
      -Dsonar.exclusions=**/target/**,**/test/**,**/resources/**,**/node_modules/**
  rules:
    - if: $CI_COMMIT_BRANCH == "uat"

merge-uat:
  stage: merge
  image: sonar-ci:20260323
  tags:
    - yyyz
  script:
    - apk add --no-cache curl jq
    - |
      MR_STATE=$(curl -s -H "PRIVATE-TOKEN: $MERGE_TOKEN" \
        "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID" \
        | jq -r '.state')
      CAN_MERGE=$(curl -s -H "PRIVATE-TOKEN: $MERGE_TOKEN" \
        "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID" \
        | jq -r '.detailed_merge_status')
      if [ "$MR_STATE" = "opened" ] && [ "$CAN_MERGE" = "mergeable" ]; then
        curl -s -X PUT -H "PRIVATE-TOKEN: $MERGE_TOKEN" \
          "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID/merge"
      fi
  rules:
    - if: $CI_COMMIT_BRANCH == "uat"
  needs:
    - scan-uat

# ========== Master 分支 ==========

scan-master:
  stage: analysis
  image: sonar-ci:20260323
  tags:
    - yyyz
  script:
    - mvn -B -T 2C clean package sonar:sonar \
      -DskipTests \
      -Dsonar.projectKey=bike-server-master \
      -Dsonar.host.url=$SONAR_HOST_URL \
      -Dsonar.login=$SONAR_MASTER \
      -Dsonar.sourceEncoding=UTF-8 \
      -Dsonar.java.binaries=target/classes \
      -Dsonar.exclusions=**/target/**,**/test/**,**/resources/**,**/node_modules/**
  rules:
    - if: $CI_COMMIT_BRANCH == "master"

merge-master:
  stage: merge
  image: sonar-ci:20260323
  tags:
    - yyyz
  script:
    - apk add --no-cache curl jq
    - |
      MR_STATE=$(curl -s -H "PRIVATE-TOKEN: $MERGE_TOKEN" \
        "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID" \
        | jq -r '.state')
      CAN_MERGE=$(curl -s -H "PRIVATE-TOKEN: $MERGE_TOKEN" \
        "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID" \
        | jq -r '.detailed_merge_status')
      if [ "$MR_STATE" = "opened" ] && [ "$CAN_MERGE" = "mergeable" ]; then
        curl -s -X PUT -H "PRIVATE-TOKEN: $MERGE_TOKEN" \
          "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID/merge"
      fi
  rules:
    - if: $CI_COMMIT_BRANCH == "master"
  needs:
    - scan-master
```

**Step 3：提交 .gitlab-ci.yml**

```bash
git add .gitlab-ci.yml
git commit -m "feat: 添加 SonarQube 代码质量检测流水线"
git push
```

**Step 4：验证流水线触发**

- GitLab → 项目 → CI/CD → Pipelines
- 确认流水线已触发，scan-uat / scan-master job 正常运行
- 如失败，点击 job 查看日志排查问题

---

## 4. 流水线执行流程

### 4.1 正常流程（uat 分支）

```
开发者提交 MR（feature → uat）
    ↓
scan-uat 自动触发
    ↓
Maven 编译 + SonarQube 扫描（约 2-5 分钟）
    ↓
质量门判定
    ↓
merge-uat 自动合并（质量门通过）
    ↓
结果通知（钉钉）
```

### 4.2 Master 分支流程

```
发布经理提交 MR（release → master）
    ↓
scan-master 自动触发
    ↓
质量门判定
    ↓
merge-master 需手动触发（manual）
    ↓
发布经理确认后手动合并
```

---

## 5. 质量门配置（SonarQube 端）

### 5.1 质量门规则

进入 SonarQube → Quality Gates → 默认质量门，配置以下条件：

| 指标 | 操作 | 阈值 |
|------|------|------|
| Bugs | 新增 | = 0 |
| Vulnerabilities | 新增 | = 0 |
| Security Hotspots | 新增 | ≤ 5 |
| Code Smells | 新增 | ≤ 50 |
| Coverage | 整体 | ≥ 50% |
| Duplications | 新增 | ≤ 3% |

### 5.2 质量门分配

将配置好的质量门分配给所有接入项目：

- GitLab → 项目 → Administration → Quality Gates
- 或 SonarQube Webhook 统一配置

---

## 6. 常见问题排查

### 6.1 流水线失败常见原因

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| `sonar-scanner not found` | 镜像内未安装 scanner | 使用包含 scanner 的镜像，或在 pipeline 中安装 |
| `Compilation Failed` | target/classes 不存在 | 确保 build job 在 sonar job 之前完成 |
| `Coverage = 0%` | 未配置 JaCoCo | 添加 JaCoCo 参数，不用 `-Dmaven.test.skip=true` |
| `Quality Gate Failed` | 代码质量问题超标 | 修复问题或调整质量门阈值 |
| `connection refused` | SonarQube 未启动 | 检查 SonarQube 容器状态 |

### 6.2 JaCoCo 覆盖率配置

如需收集覆盖率，在 .gitlab-ci.yml 中添加 JaCoCo 参数：

```yaml
script:
  - mvn -B -T 2C clean verify sonar:sonar \
    -Dsonar.projectKey=bike-server-uat \
    -Dsonar.host.url=$SONAR_HOST_URL \
    -Dsonar.login=$SONAR_UAT \
    -Dsonar.java.binaries=target/classes \
    -Dsonar.java.test.binaries=target/test-classes \
    -Dsonar.jacoco.reportPaths=target/jacoco.exec \
    -Dsonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml
```

> **注意：** 使用 `-DskipTests` 会导致不执行测试，JaCoCo 无法收集覆盖率数据。应使用 `-Dsonar.skip=true` 跳过 sonar 阶段，在测试阶段正常收集覆盖率。

### 6.3 增量扫描配置

SonarQube 支持按分支/MR 增量扫描，在 scan job 中添加：

```yaml
script:
  - mvn -B -T 2C clean verify sonar:sonar \
    -Dsonar.newCode.referenceBranch=uat
```

---

## 7. 运维命令

### 7.1 SonarQube 运维

```bash
# 查看日志
docker-compose logs -f sonar

# 重启
docker-compose restart sonar

# 完全重建（慎用，会清除数据）
docker-compose down
docker-compose up -d

# 备份数据
tar -zcf sonarqube-data-$(date +%Y%m%d).tar.gz ./data ./extensions
```

### 7.2 GitLab Runner 运维

```bash
# 查看 Runner 状态
docker exec -it gitlab-runner gitlab-runner verify

# 重启 Runner
docker restart gitlab-runner

# 清除缓存
docker exec -it gitlab-runner gitlab-runner cache clear

# 查看 Runner 配置
docker exec -it gitlab-runner gitlab-runner list
```

---

*本手册与实施规范配套使用，技术细节以本手册为准。*
