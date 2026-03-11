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
sonarqube-check:
  image: 
    name: sonarsource/sonar-scanner-cli:latest
    entrypoint: [""]
  variables:
    SONAR_USER_HOME: "${CI_PROJECT_DIR}/.sonar"
    GIT_DEPTH: "0"
  cache:
    key: "${CI_JOB_NAME}"
    paths:
      - .sonar/cache
  script: 
    - sonar-scanner
  artifacts:
    paths:
      - data-board.pdf
    allow_failure: true
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
