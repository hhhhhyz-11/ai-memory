# SonarQube + PostgreSQL + GitLab CI 代码质量检测流程

> 使用 SonarQube 进行代码静态分析，PostgreSQL 存储数据，GitLab CI 触发扫描

## 架构

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  GitLab CI  │────▶│GitLab Runner│────▶│ SonarQube   │
└─────────────┘     └─────────────┘     └─────────────┘
                                               │
                                        ┌──────┴──────┐
                                        │ PostgreSQL  │
                                        └─────────────┘
```

## 1. Docker Compose 部署 SonarQube

### docker-compose.yml

```yaml
version: '3'

services:

  postgres:
    image: postgres:12
    container_name: postgres
    restart: always
    volumes:
      - /home/postgres/data:/var/lib/postgresql/data
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
```

### 启动

```bash
docker-compose up -d
```

首次启动后访问 `http://localhost:9000`，默认账号 `admin/admin`

## 2. GitLab Runner 部署

```bash
docker run -d \
  --name gitlab-runner \
  --restart always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /home/gitlab-runner/config:/etc/gitlab-runner \
  gitlab/gitlab-runner:latest
```

## 3. GitLab CI 配置

在项目中添加 `.gitlab-ci.yml`:

```yaml
stages:
  - build

variables:
  MAVEN_OPTS: "-Dmaven.repo.local=$CI_PROJECT_DIR/.m2/repository"

cache:
  key: ${CI_PROJECT_NAME}-maven
  policy: pull-push
  paths:
    - .m2/repository

build-and-sonar:
  stage: build
  image: maven:3.9.6-eclipse-temurin-11
  script:
    - mvn -B --no-transfer-progress -T 2C clean package sonar:sonar -DskipTests -Dmaven.test.skip=true -Dsonar.projectKey=bike-server-master -Dsonar.host.url=$SONAR_HOST_URL -Dsonar.login=$SONAR_TOKEN -Dsonar.sourceEncoding=UTF-8 -Dsonar.java.binaries=target/classes -Dsonar.exclusions=**/target/**,**/test/**,**/resources/** 
  when: manual
  only:
    - master

```

### 配置说明

| 配置项 | 说明 |
|--------|------|
| `SONAR_USER_HOME` | Sonar scanner 缓存目录 |
| `GIT_DEPTH: "0"` | 获取所有分支，确保分析任务正常 |
| `cache` | 缓存 .sonar 目录加速后续扫描 |
| `allow_failure: true` | 允许失败，不阻塞 CI |
| `only: master` | 仅在 master 分支触发 |

### SonarQube 项目配置

在 SonarQube 中创建项目后，需要在项目根目录添加 `sonar-project.properties`:

```properties
sonar.projectKey=your-project-key
sonar.projectName=Your Project Name
sonar.sources=.
sonar.sourceEncoding=UTF-8
```

## 4. 常见问题

### SonarQube 启动失败

- 检查 `ulimits` 是否设置足够（建议 65536）
- 首次启动初始化较慢，等待几分钟

### CI 中找不到 sonar-scanner

- 确保镜像 `sonarsource/sonar-scanner-cli:latest` 可访问
- 可配置私有镜像仓库

### 分析报告生成

- `artifacts` 中的 `data-board.pdf` 需要配置 SonarQube 报告导出插件

## GitLab CI 自动合并 MR

### 需求
- 开发无合并权限
- MR 测试通过后自动合并

### 方案
在 CI pipeline 末尾添加 `auto-merge` job

### 实现

1. 用有 Merge 权限的 PAT（Personal Access Token）
2. 调用 GitLab Merge API 自动合并

```yaml
auto-merge:
  stage: deploy
  image: alpine:latest
  script:
    - apk add --no-cache curl jq
    - |
      # 检查 MR 状态
      MR_STATE=$(curl -s -H "PRIVATE-TOKEN: $MERGE_TOKEN" \
        "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID" | jq -r '.state')
      
      # 检查是否可以合并
      CAN_MERGE=$(curl -s -H "PRIVATE-TOKEN: $MERGE_TOKEN" \
        "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID" | jq -r '.detailed_merge_status')
      
      if [ "$MR_STATE" = "opened" ] && [ "$CAN_MERGE" = "mergeable" ]; then
        curl -s -X PUT -H "PRIVATE-TOKEN: $MERGE_TOKEN" \
          "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID/merge"
      fi
  when: manual
```

### 关键变量

| 变量 | 说明 |
|------|------|
| `MERGE_TOKEN` | 有 Merge 权限的 PAT |
| `CI_MERGE_REQUEST_IID` | GitLab 自动提供的 MR 编号 |

### GitLab API

- 检查 MR 状态：`GET /projects/:id/merge_requests/:iid`
- 合并 MR：`PUT /projects/:id/merge_requests/:iid/merge`
