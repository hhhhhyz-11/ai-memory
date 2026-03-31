# Gitlab+Gitlab-runner+sonarqube

> 来源: Trilium Notes 导出 | 路径: root/Gitlab+Gitlab-runner+sonarqube




Gitlab+Gitlab-runner+sonarqube搭建Gitlab CI代码检测流水线




## Gitlab+Gitlab-runner+sonarqube搭建Gitlab CI代码检测流水线


## 背景：本 `.gitlab-ci.yml` 文件用于实现 Java Spring Boot 项目的持续集成与代码质量分析。
在 master 分支提交时自动执行 Maven 构建，并调用 SonarQube 进行静态代码检测，
分析项目的可靠性、安全性及可维护性指标，从而提升代码质量并降低技术债务风险。



### 搭建sonarqube代码检测平台

#### 1.1 创建持久化目录

`mkdir -p /home/SonarQube/data
mkdir -p /home/SonarQube/logs
mkdir -p /home/SonarQube/extensions`
#### 1.2 启动 SonarQube

```
`docker run -d \
--name sonarqube \
-p 9000:9000 \
-v /home/SonarQube/data:/opt/sonarqube/data \
-v /home/SonarQube/logs:/opt/sonarqube/logs \
-v /home/SonarQube/extensions:/opt/sonarqube/extensions \
--restart always \
sonarqube:lts-community

访问地址：http://服务器IP:9000
默认账号：admin/admin`
```



### 创建Gitlab Runner（核心组件）

#### 2.1 安装 Runner

```
`docker run -d \
--name gitlab-runner \
--restart always \
-v /var/run/docker.sock:/var/run/docker.sock \
-v /home/gitlab-runner/config:/etc/gitlab-runner \
gitlab/gitlab-runner:latest`
```
#### 2.2 注册 Runner

```
`#注册命令
docker exec -it gitlab-runner gitlab-runner register

#以下是注册过程
Enter the GitLab instance URL (for example, https://gitlab.com/): #输入gitlab地址
http://192.168.0.18:8080
Enter the registration token: #在gitlab全局或者项目中查看Runner token并输入token到此
xxxxxxxxxxxxxxx
Enter a description for the runner: #默认回车下一个
Enter tags for the runner (comma-separated): #给新注册的Runner打标签（非必选）
Enter optional maintenance note for the runner: #输入一个备注说明 （非必选）
WARNING: Support for registration tokens and runner parameters in the 'register' command has been deprecated in GitLab Runner 15.6 and will be replaced with support for authentication tokens. For more information, see https://docs.gitlab.com/ci/runners/new_creation_workflow/ 
Registering runner... succeeded           correlation_id=1c6740bf44984102b3680a3e9cf70bac runner=McrpSWnt6 runner_name=694f116ab24c
Enter an executor: custom, shell, ssh, parallels, docker, docker-windows, docker+machine, docker-autoscaler, virtualbox, kubernetes, instance: #选择Runner的执行方式
docker #本地选择docker来执行
Enter the default Docker image (for example, ruby:3.3): #输入使用到的镜像，后面在项目的yml文件会用到
maven:3.9.6-eclipse-temurin-11 #本次使用到的镜像
Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded!

Configuration (with the authentication token) was saved in "/etc/gitlab-runner/config.toml" #注册成功

#注意事项
#要在/home/gitlab-runner/config.toml上配置一个本地加载镜像的，不然每次执行CI的时候会一直下载镜像
#以下为本次的文件
[[runners]]
name = "694f116ab24c"
url = "http://192.168.0.18:8080"
id = 6
token = "4a5258482a0dc5c527499b33a65c8b"
token_obtained_at = 2026-03-05T02:11:19Z
token_expires_at = 0001-01-01T00:00:00Z
executor = "docker"
[runners.cache]
MaxUploadedArchiveSize = 0
[runners.cache.s3]
[runners.cache.gcs]
[runners.cache.azure]
[runners.docker]
tls_verify = false
image = "sonarsource/sonar-scanner-cli:latest"
privileged = false
disable_entrypoint_overwrite = false
oom_kill_disable = false
disable_cache = false
volumes = ["/cache"]
shm_size = 0
network_mtu = 0
pull_policy = ["if-not-present"] #在末尾添加上这个，注意是在[runners.docker]下`
```



### 配置Gitlab与Sonar平台集成

#### 3.1 网址：http://SonarQube:9000，点击项目后新增项目 → 手动创建




#### 3.2 输入项目名称，项目分支





#### 3.3 创建项目后选择创建Gitlab CI项目




#### 3.4 选择之后会出现设置步骤，在代码仓库根目录下创建sonar-project.properties文件









#### 3.5 创建完成后选择下一步继续，生成SONAR_TOKEN并设置时间为永久，在项目 → 设置 → CICD → 变量 输入变量名、TOKEN





#### 3.6 在项目根目录下创建.gitlab-ci.yml文件，这是基础模板





`#以下是针对Java SpringBoot的配置文件
stages: #定义流水线阶段
- build #执行项目构建与代码质量分析

variables:
MAVEN_OPTS: "-Dmaven.repo.local=$CI_PROJECT_DIR/.m2/repository" #指定maven依赖下载到/root/.m2/repository

cache: #缓存 Maven 依赖
key: maven-cache
paths:
- .m2/repository

build-and-sonar:
stage: build
image: maven:3.9.6-eclipse-temurin-11 #指定CI运行环境
script:
- mvn -B --no-transfer-progress -T 1C clean verify sonar:sonar \
-DskipTests \
-Dsonar.projectKey=bike-server \
-Dsonar.host.url=$SONAR_HOST_URL \
-Dsonar.login=$SONAR_TOKEN
only:
- master #分支
# 构建命令解释
# -B Batch 模式，适用于 CI 环境
# --no-transfer-progress 关闭 Maven 下载进度条，减少日志输出
# -T 1C 多线程构建
# clean 删除旧的构建
# verify 执行完整 Maven 生命周期
# sonar:sonar 调用 SonarQube 进行静态代码分析 包含（读取字节码、构建语法树（AST）、数据流分析、安全漏洞检测、生成分析报告、上传到 Sonar 服务器）
# -DskipTests 跳过单元测试执行
# -Dsonar.projectKey=bike-server 项目唯一标识 需要跟SonarQube创建的项目名称对应
# -Dsonar.host.url Sonar 服务器地址
# -Dsonar.login 访问令牌（Token）
# 编译构建的原因：因Sonar java分析依赖编译之后的.class文件、完整的依赖信息、类型关系、控制流信息`
#### 3.7  配置步骤结束后CICD会自动执行一次流水线




#### 通过后可以在sonar平台看到代码情况

