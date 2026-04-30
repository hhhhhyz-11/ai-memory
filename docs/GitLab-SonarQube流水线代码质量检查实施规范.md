# GitLab + SonarQube 流水线代码质量检查实施规范

> **文件编号：** SJ-STD-2026-001
> **版本：** V1.0
> **编制日期：** 2026-04-27
> **适用范围：** Java Maven 项目
> **评审状态：** 待部门正式评审

---

## 1. 背景与目的

### 1.1 背景

随着项目代码量不断增长，手动代码 review 难以覆盖全部问题，代码质量技术债务持续累积。为提升代码可靠性、安全性及可维护性，引入 SonarQube 静态代码分析平台，结合 GitLab CI/CD 实现自动化代码质量检测。

### 1.2 目标

- 接入 GitLab CI/CD 流水线，实现提交代码自动检测
- 支持增量扫描，仅检测 MR 新增代码，降低扫描时长
- 生成中文 PDF 分析报告并上传 MinIO 文件服务器
- 自动同步扫描结果到 MR 评论区，辅助 Code Review
- 质量门（Quality Gate）未通过的代码阻止合并
- 统一代码质量规范，形成可复用的实施流程

### 1.3 涉及项目

| 项目 | 分支策略 | 说明 |
|------|---------|------|
| bike-server | uat / master | 首批接入项目 |
| 其他 Java Maven 项目 | uat / master | 按计划逐步接入 |

---

## 2. 前置准备

### 2.1 技术选型

| 项目 | 选型 | 理由 |
|------|------|------|
| SonarQube | LTS Community 10+ | 免费开源，支持中文 PDF 报告 |
| PostgreSQL | 12+ | SonarQube 推荐数据库 |
| GitLab Runner | Docker 部署 | 跨平台，支持 docker executor |
| CI 镜像 | 自定义镜像 | 内置 Maven + Python + MinIO Client |
| PDF 生成 | WeasyPrint + Python | 支持中文，支持 CSS 分页 |
| 报告存储 | MinIO 对象存储 | 部署在内网，下载速度快 |

### 2.2 环境依赖

**基础设施：**

| 组件 | 最低配置 | 推荐配置 |
|------|---------|---------|
| SonarQube Server | 4核8G | 8核16G，SonarQube 本身不耗资源 |
| PostgreSQL | 2核4G | 4核8G |
| GitLab Runner | 2核2G | 4核4G，高并发场景需更多资源 |
| MinIO | 2核4G | 与其他服务共用 |

**网络要求：**

| 连通性 | 说明 |
|--------|------|
| GitLab Runner → SonarQube | Runner 节点需能访问 SonarQube 9000 端口 |
| GitLab Runner → MinIO | Runner 节点需能访问 MinIO API 端口 |
| GitLab Runner → GitLab | Runner 节点需能访问 GitLab API |

### 2.3 权限配置

**SonarQube 端：**

- 创建项目时，分别为 master 和 uat 分支创建独立项目（不同 projectKey）
- 为每个项目生成具有执行分析权限的 Token（Project Analysis Token）
- 建议使用全局 Web API Token，方便管理

**GitLab 端：**

- 在 Settings → CI/CD → Variables 中配置以下变量（需保护级别）：

| 变量名 | 说明 | 保护级别 |
|--------|------|---------|
| `SONAR_MASTER` | master 分支 SonarQube Token | Protected |
| `SONAR_UAT` | uat 分支 SonarQube Token | Protected |
| `MERGE_TOKEN` | 具有 Merge 权限的 GitLab PAT | Protected |
| `DINGTALK_WEBHOOK` | 钉钉群机器人 WebHook | Protected |
| `MINIO_ACCESS_KEY` | MinIO 用户名 | Protected |
| `MINIO_SECRET_KEY` | MinIO 密码 | Protected |

- `MERGE_TOKEN` 必须具有 `api` 权限（读取所有项目 + 合并 MR）

**MinIO 端：**

- 创建专用 Bucket（如 `sonar-reports`），设置公开或通过 Policy 控制访问
- 配置 Lifecycle 规则，自动清理超过 90 天的报告

---

## 3. 配置过程

### 3.1 SonarQube 部署（Docker Compose）

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

> **注意：** SonarQube 首次启动需要 3-5 分钟初始化。启动后访问 `http://IP:9000`，默认账号 `admin/admin`，建议立即修改密码。

### 3.2 GitLab Runner 部署（Docker）

```bash
docker run -d \
  --name gitlab-runner \
  --restart always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /home/gitlab-runner/config:/etc/gitlab-runner \
  gitlab/gitlab-runner:latest
```

### 3.3 GitLab Runner 注册

```bash
docker exec -it gitlab-runner gitlab-runner register
```

注册过程交互输入：

```
Enter the GitLab instance URL: http://192.168.x.x:8080
Enter the registration token:  （来自 GitLab Settings → CI/CD → Runners）
Enter a description: sonar-runner
Enter tags: yyyz
Enter executor: docker
Enter default Docker image: maven:3.9.6-eclipse-temurin-11
```

> **说明：** `tags: yyyz` 用于在 .gitlab-ci.yml 中匹配特定 Runner。

### 3.4 CI 镜像构建

sonar-ci 镜像包含：Maven 3.9.6 + Java 11、Python 3 + WeasyPrint（中文 PDF 支持）、MinIO Client、Jinja2

```bash
docker build -f Dockerfile.sonar -t sonar-ci:latest /path/to/gitlab-ci/
```

Dockerfile.sonar 关键内容：

```dockerfile
FROM maven:3.9.6-eclipse-temurin-11
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl jq wget python3 python3-pip \
    fonts-noto-cjk fonts-wqy-microhei fonts-wqy-zenhei \
    libcairo2 libffi-dev shared-mime-info \
    && rm -rf /var/lib/apt/lists/*
RUN pip3 install --no-cache-dir jinja2==3.1.3 weasyprint==55.0 pydyf==0.10.0
COPY mc /usr/local/bin/mc
RUN chmod +x /usr/local/bin/mc
```

### 3.5 .gitlab-ci.yml 流水线配置

在项目根目录创建 `.gitlab-ci.yml`：

```yaml
stages:
  - analysis
  - merge

variables:
  MAVEN_OPTS: "-Dmaven.repo.local=$CI_PROJECT_DIR/.m2/repository"
  GIT_DEPTH: "0"
  SONAR_CACHE_DIR: ".sonar/cache"
  SONAR_REPORT_DIR: "sonar-report"

cache:
  key: ${CI_PROJECT_NAME}-maven
  policy: pull-push
  paths:
    - .m2/repository
    - .sonar/cache

# ========== UAT 分支流水线 ==========

scan-uat:
  stage: analysis
  image: sonar-ci:latest
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
      -Dsonar.exclusions=**/target/**,**/test/**,**/resources/**
  rules:
    - if: $CI_COMMIT_BRANCH == "uat"

merge-uat:
  stage: merge
  image: sonar-ci:latest
  tags:
    - yyyz
  script:
    - /scripts/auto-merge.sh
  rules:
    - if: $CI_COMMIT_BRANCH == "uat"
  needs:
    - scan-uat

# ========== Master 分支流水线 ==========

scan-master:
  stage: analysis
  image: sonar-ci:latest
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
      -Dsonar.exclusions=**/target/**,**/test/**,**/resources/**
  rules:
    - if: $CI_COMMIT_BRANCH == "master"

merge-master:
  stage: merge
  image: sonar-ci:latest
  tags:
    - yyyz
  script:
    - /scripts/auto-merge.sh
  rules:
    - if: $CI_COMMIT_BRANCH == "master"
  needs:
    - scan-master
```

### 3.6 分支门禁规则

| 目标分支 | 允许的源分支 | 合并方式 |
|----------|-------------|---------|
| `uat` | `feature/*`、`hotfix/*` | 自动合并 |
| `master` | `release/*` | 手动合并 |

---

## 4. 实现效果

### 4.1 实施前（无流水线）

| 环节 | 现状 |
|------|------|
| 代码提交 | 无检测，直接合入 |
| Code Review | 纯人工，受限于 reviewer 时间 |
| 质量问题 | 上线后发现，修复成本高 |
| 报告生成 | 无自动报告 |
| 合并控制 | 人工判断，无技术手段 |

### 4.2 实施后（SonarQube + GitLab CI）

| 环节 | 实施后 |
|------|--------|
| 代码提交 | 自动触发 SonarQube 扫描 |
| Code Review | 扫描结果自动同步 MR 评论区 |
| 质量问题 | 提交前发现，质量门拦截 |
| 报告生成 | 自动生成中文 PDF，上传 MinIO |
| 合并控制 | 质量门通过才允许合并 |
| 分支管控 | feature/hotfix → uat → release → master |

**效果图：**

> 📸 **图1：GitLab MR 评论 — SonarQube 扫描结果自动同步**
> ![GitLab MR SonarQube 评论](imgs/gitlab-mr-comment.png)

> 📸 **图2：质量门拦截 — 流水线失败/合并被阻止**
> ![质量门拦截](imgs/quality-gate-blocked.png)

> 📸 **图3：SonarQube Web UI — 新增代码分析结果**
> ![SonarQube 分析结果](imgs/sonarqube-result.png)

> 📸 **图4：PDF 报告 — 浏览器打开效果**
> ![PDF 报告](imgs/sonar-pdf-report.png)

### 4.3 质量门规则

| 指标 | 阈值 | 说明 |
|------|------|------|
| 可靠性（Bugs） | 新增 ≤ 0 | 严重 Bug 必须修复 |
| 安全性（Vulnerabilities） | 新增 ≤ 0 | 安全漏洞必须修复 |
| 安全热点（Security Hotspots） | 新增 ≤ 5 | 高危安全热点需 review |
| 代码异味（Code Smells） | 新增 ≤ 50 | 允许少量异味，分批优化 |
| 覆盖率（Coverage） | ≥ 50% | 目标值，可根据项目调整 |
| 重复率（Duplications） | 新增 ≤ 3% | 超过则阻止合并 |

---

## 5. 各项目实施阶段计划

### 5.1 试用阶段（2026年4月）

**目标项目：** bike-server

| 阶段 | 时间 | 内容 | 负责人 |
|------|------|------|--------|
| 流水线搭建 | 第1-2天 | SonarQube + GitLab Runner 部署，bike-server 首批接入 | 运维 |
| 扫描调优 | 第3天 | 调整质量门阈值，验证增量扫描准确性 | 开发 |
| 效果验证 | 第4天 | 对比人工 review 和流水线检测结果，优化规则 | 双方 |
| 规范制定 | 第5天 | 输出代码质量规范文档，提交评审 | 运维 |

### 5.2 复用推广阶段（2026年5月起）

| 批次 | 项目 | 计划接入时间 | 说明 |
|------|------|-------------|------|
| 第1批 | 项目A、项目B | 5月第1周 | 积累经验，完善 SOP |
| 第2批 | 项目C、项目D | 5月第2周 | 标准化配置模板 |
| 第3批 | 其他 Java Maven 项目 | 5月下旬起 | 按需接入，持续优化 |

### 5.3 后续规划

- 接入JaCoCo 覆盖率收集，覆盖率 ≥ 60%
- 接入 SpotBugs、Checkstyle 等扩展检测
- 探索 AI Code Review 辅助（结合 SonarQube LLM Integration）
- 统计数据看板，周期性输出质量报告

---

## 6. 附录

### 6.1 凭证信息（示例）

| 项目 | 值 |
|------|-----|
| SonarQube | http://192.168.x.x:9000 |
| SonarQube 账号 | admin / Sonar@2026_com.cn |
| PostgreSQL | 192.168.x.x:5432 / sonar / Sonar@2026_com.cn / sonar |
| GitLab PAT（MERGE_TOKEN） | glpat-xxx（需具有 api 权限） |
| MinIO | http://192.168.x.x:9000 / minioadmin / minioadmin |

### 6.2 相关文档

- `gitlab-ci/README.md` — 流水线配置说明
- `learnings/sonarqube-gitlab-ci.md` — 部署与配置详细记录
- SonarQube 官方文档：https://docs.sonarsource.com/sonarqube/

---

*本规范由 AI 辅助编制，内容基于实际实施经验总结。*
*评审通过后生效。*
