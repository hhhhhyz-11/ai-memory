# Jenkins配置多jar包构建并传输到远程服务器本地启动项

> 来源: Trilium Notes 导出 | 路径: root/Jenkins流水线/Jenkins配置多jar包构建并传输到远程服务器本地启动项


Jenkins配置多jar包构建并传输到远程服务器本地启动项目




## Jenkins配置多jar包构建并传输到远程服务器本地启动项目


### 1.流水线

```
`pipeline {
agent {
label 'master'
} // 指定Jenkins代理，any表示任何可用代理

parameters {
extendedChoice multiSelectDelimiter: ',', name: 'SERVICE_NAMES', quoteValue: false, saveJSONParameterToFile: false, type: 'PT_CHECKBOX', value: 'yunst-biz-xxljob-admin,yunst-biz-admin,yunst-biz-auth,yunst-biz-gateway,yunst-biz-resource,yunst-biz-system-log,yunst-biz-call-center,yunst-biz-stats-analy,yunst-biz-insurance,yunst-biz-user,yunst-biz-system-manage', visibleItemCount: 11
string(
name: 'SERVICE_PORT',
defaultValue: '',
description: '服务监听端口（留空则使用配置文件的默认值,批量发布无需修改此项）'
)
string(
name: 'NACOS_SIGN',
defaultValue: 'prod',
description: 'NACOS配置ID'
)
text(
name: 'JAVA_OPTS',
defaultValue: '-Xms512M -Xmx512M -Xmn192M -Xss1M -XX:MetaspaceSize=256M -XX:MaxMetaspaceSize=256M',
description: '设置JVM参数（最大堆内存大小）'
)
choice(
name: 'TARGET_NODE',
choices: ['202.105.27.186'], // 更新节点选项
description: '选择部署的服务器节点'
)
booleanParam(
name: 'ROLLBACK',
defaultValue: false,
description: '是否回滚到上一个版本'
)
}

environment {
CREDENTIALS_ID = 'gitlab'
M2_HOME = '/home/maven/apache-maven-3.8.1'
GIT_URL = 'http://192.168.0.18:8080/foshandiandongzixingche/fscxyh/fscxyh.git' // Git仓库URL
SYSTEMD_DIR = "/home/cxyh" // Jenkins Agent上Systemd服务文件模板的源目录
REMOTE_BASE_DIR = "/home/cxyh-server" // 远程服务器上所有ddc服务的根部署目录
JAR_BUILD_DIR_ON_AGENT = "cxyh-jar" // Jar包在Jenkins Agent上的构建产物存放目录
BRANCHES = 'master' // Git检出分支名
}

stages {
stage("环境检查与代码检出") {
steps {
script { // 使用script块以运行多行shell命令和Groovy steps
echo "\033[32m ******开始环境检查****** \033[0m"
sh 'echo "Current PATH: $PATH"' // 打印当前PATH
sh 'command -v nohup || echo "nohup command not found in PATH"' // 检查nohup是否存在
sh 'command -v cp || echo "cp command not found in PATH"'   // 检查cp是否存在
// 尝试运行一个基本命令来确认PATH是否可用
sh 'ls -l /tmp > /dev/null || echo "ls command failed, PATH might be bad"'

echo "\033[32m ******开始检出项目代码****** \033[0m"
}
checkout scmGit(
branches: [[name: "${env.BRANCHES}"]], // 使用环境变量 BRANCHES
extensions: [authorInChangelog()], // 记录作者信息到changelog
userRemoteConfigs: [[
credentialsId: 'gitlab', // Jenkins中配置的GitLab凭据ID
url: "${env.GIT_URL}" // Git仓库URL
]]
)
echo "\033[32m ******checkOut ok****** \033[0m"
}
}

stage('开始打包') {
steps {
echo "\033[32m ******开始进行Maven打包****** \033[0m"
// 添加 M2_HOME 到 PATH，确保 mvn 命令可用
sh "mvn -T 5 clean install -Dmaven.test.skip=true -U -P ${params.NACOS_SIGN}"
echo '\033[32m ******buildJar ok****** \033[0m'
}
}

stage('提取Jar包') {
when { expression { !params.ROLLBACK } } // 仅在非回滚模式下提取Jar包
steps {
script {
echo "\033[32m ******开始提取构建完成的Jar包到 ${env.JAR_BUILD_DIR_ON_AGENT} ****** \033[0m"
sh "mkdir -p ${env.JAR_BUILD_DIR_ON_AGENT} && rm -f ${env.JAR_BUILD_DIR_ON_AGENT}/*.jar" // 清理并创建Jar产物目录
// 查找并复制Jar包到指定目录，排除API和CORE模块的Jar
sh "find ${WORKSPACE} -name '*.jar' ! -path '*target/*api*' ! -path '*target/*core*' ! -path '*target/*1.0.0*' -exec cp {} ${env.JAR_BUILD_DIR_ON_AGENT}/ \\;"
echo "\033[32m ******Jar包提取完成****** \033[0m"
}
}
}

stage('jar包同步') {
when { expression { !params.ROLLBACK } }
steps {
echo '复制文件到Jenkins工作空间'
script {
// 定义服务名到端口的默认映射
def servicePortsMap = [
'yunst-biz-admin': '16060', 'yunst-biz-auth': '16061', 'yunst-biz-call-center': '16062',
'yunst-biz-gateway': '16066', 'yunst-biz-insurance': '16063', 'yunst-biz-system-manage': '16064',
'yunst-biz-user': '16065', 'yunst-biz-xxljob-admin': '16070', 'yunst-biz-resource': '16069',
'yunst-biz-stats-analy': '16071', 'yunst-biz-system-log': '16072'
]

// 将Systemd模板文件复制到Jenkins工作空间，便于传输
sh "mkdir -p ${WORKSPACE}/systemd-templates-local"
sh "cp -f ${env.SYSTEMD_DIR}/cxyh-service@.service ${WORKSPACE}/systemd-templates-local/"

for (def ddc_name : params.SERVICE_NAMES.tokenize(',')) {
echo "\n\033[34m === 正在处理服务: ${ddc_name} === \033[0m"
def CURRENT_SERVICE_REMOTE_DIR = "${env.REMOTE_BASE_DIR}/${ddc_name}"
echo "${JAR_BUILD_DIR_ON_AGENT}/${ddc_name}.jar"
// 使用 sshPublisher 插件将 JAR 包传输到目标节点
sshPublisher(
publishers: [
sshPublisherDesc(
configName: "${params.TARGET_NODE}", 
verbose: true, // 开启详细日志
transfers: [
sshTransfer(
sourceFiles: "${JAR_BUILD_DIR_ON_AGENT}/${ddc_name}.jar",
removePrefix: "${JAR_BUILD_DIR_ON_AGENT}",
remoteDirectory: "${CURRENT_SERVICE_REMOTE_DIR}",
usePty: true,
execCommand: ""
)
]
)
]
)
}

}
}
}

stage('多服务文件同步与备份') {
steps {
script {
// 定义服务名到端口的默认映射
def servicePortsMap = [
'yunst-biz-admin': '16060', 'yunst-biz-auth': '16061', 'yunst-biz-call-center': '16062',
'yunst-biz-gateway': '16066', 'yunst-biz-insurance': '16063', 'yunst-biz-system-manage': '16064',
'yunst-biz-user': '16065', 'yunst-biz-xxljob-admin': '16070', 'yunst-biz-resource': '16069',
'yunst-biz-stats-analy': '16071', 'yunst-biz-system-log': '16072'
]

// 将Systemd模板文件复制到Jenkins工作空间，便于传输
sh "mkdir -p ${WORKSPACE}/systemd-templates-local"
sh "cp -f ${env.SYSTEMD_DIR}/cxyh-service@.service ${WORKSPACE}/systemd-templates-local/"

for (def ddc_name : params.SERVICE_NAMES.tokenize(',')) {
echo "\n\033[34m === 正在处理服务: ${ddc_name} === \033[0m"
def CURRENT_SERVICE_REMOTE_DIR = "${env.REMOTE_BASE_DIR}/${ddc_name}"

// 远程创建服务目录并备份旧Jar包
echo "\033[32m ******正在准备远程目录并备份服务 ${ddc_name} 的当前版本****** \033[0m"
sshPublisher(
publishers: [
sshPublisherDesc(
configName: "${params.TARGET_NODE}", 
//  verbose: true, // 开启详细日志
transfers: [
sshTransfer(
sourceFiles: "",
removePrefix: "",
remoteDirectory: "",
usePty: true,
execCommand: """
if [ -f ${CURRENT_SERVICE_REMOTE_DIR}/${ddc_name}.jar ]; then
sudo /bin/cp -f ${CURRENT_SERVICE_REMOTE_DIR}/${ddc_name}.jar ${CURRENT_SERVICE_REMOTE_DIR}/${ddc_name}.jar.bak && \
echo "✅ 服务 ${ddc_name} 旧版本已备份" || { echo "❌ 服务 ${ddc_name} 旧版本备份失败！"; exit 1; }
else
echo "ℹ️ 服务 ${ddc_name} 暂无旧版本可备份，跳过备份"
fi
"""
)
]
)
]
)

if (!params.ROLLBACK) {
echo "\033[32m ******正在同步服务 ${ddc_name} 的新Jar包****** \033[0m"
def jar_file_path = "${env.JAR_BUILD_DIR_ON_AGENT}/${ddc_name}.jar"
if (!fileExists(jar_file_path)) {
error("❌ Jar文件不存在: ${jar_file_path}，请检查构建阶段是否成功生成。")
}

// 上传Jar包到远程临时目录，并通过execCommand移动到最终位置
sshPublisher(
publishers: [
sshPublisherDesc(
configName: "${params.TARGET_NODE}",
// verbose: true,
transfers: [
sshTransfer(
sourceFiles: jar_file_path,
removePrefix: "${env.JAR_BUILD_DIR_ON_AGENT}",
remoteDirectory: "${CURRENT_SERVICE_REMOTE_DIR}", 
usePty: true,
execCommand: ""
)
]
)
]
)
}
}
}
}
}

stage('部署') {
steps {
script {
// 定义服务名到端口的默认映射
def servicePortsMap = [
'yunst-biz-admin': '16060', 'yunst-biz-auth': '16061', 'yunst-biz-call-center': '16062',
'yunst-biz-gateway': '16066', 'yunst-biz-insurance': '16063', 'yunst-biz-system-manage': '16064',
'yunst-biz-user': '16065', 'yunst-biz-xxljob-admin': '16070', 'yunst-biz-resource': '16069',
'yunst-biz-stats-analy': '16071', 'yunst-biz-system-log': '16072'
]

for (def ddc_name : params.SERVICE_NAMES.tokenize(',')) {
echo "\n\033[34m === 正在部署服务: ${ddc_name} === \033[0m"
def CURRENT_SERVICE_REMOTE_DIR = "${env.REMOTE_BASE_DIR}/${ddc_name}"

if (params.ROLLBACK) {
echo "\033[32m ******正在回滚服务 ${ddc_name} ****** \033[0m"
sshPublisher(
publishers: [
sshPublisherDesc(
configName: "${params.TARGET_NODE}",
execCommand: """
if [ -f ${CURRENT_SERVICE_REMOTE_DIR}/${ddc_name}.jar.bak ]; then
sudo /bin/cp -f ${CURRENT_SERVICE_REMOTE_DIR}/${ddc_name}.jar.bak ${CURRENT_SERVICE_REMOTE_DIR}/${ddc_name}.jar && echo "✅ 服务 ${ddc_name} 已回滚到备份版本" || { echo "❌ 服务 ${ddc_name} 回滚失败！"; exit 1; }
else
echo "❌ 回滚失败: 服务 ${ddc_name} 无备份版本可回滚"
exit 1
fi
sudo systemctl restart cxyh-service@${ddc_name} && echo "✅ 服务 ${ddc_name} 已重启" || { echo "❌ 服务 ${ddc_name} 重启失败！"; exit 1; }
"""
)
]
)
} else {
def finalPort = params.SERVICE_PORT ?: servicePortsMap[ddc_name]

if (params.SERVICE_PORT && !params.SERVICE_PORT.matches('\\d+')) {
error("自定义端口必须是数字: ${params.SERVICE_PORT}")
}

echo "服务名称: ${ddc_name}"
echo "使用端口: ${finalPort}"

def systemd_template_path_in_workspace = "${WORKSPACE}/systemd-templates-local/cxyh-service@.service"
if (!fileExists(systemd_template_path_in_workspace)) {
error("服务配置文件 cxyh-service@.service 不存在于 ${systemd_template_path_in_workspace}")
}

echo "\033[32m ******正在同步Systemd服务文件到远程并配置****** \033[0m"
// 上传Systemd模板文件到远程临时目录，并移动到/etc/systemd/system/
sshPublisher(
publishers: [
sshPublisherDesc(
configName: "${params.TARGET_NODE}",
// verbose: true,
transfers: [
sshTransfer(
sourceFiles: "systemd-templates-local/cxyh-service@.service",
removePrefix: "systemd-templates-local",
remoteDirectory: "${env.REMOTE_BASE_DIR}", 
usePty: true,
execCommand: """
sudo mv ${env.REMOTE_BASE_DIR}/cxyh-service@.service /etc/systemd/system/cxyh-service@.service
sudo chown root:root /etc/systemd/system/cxyh-service@.service 
sudo chmod 644 /etc/systemd/system/cxyh-service@.service
# 创建/更新服务配置文件
cat <<EOF | sudo tee ${CURRENT_SERVICE_REMOTE_DIR}/service.conf
SPRING_OPTS="--spring.profiles.active=${params.NACOS_SIGN} --server.port=${finalPort}"
JAVA_OPTS="${params.JAVA_OPTS} -XX:+UseParNewGC -XX:+UseConcMarkSweepGC -XX:CMSInitiatingOccupancyFraction=92 -XX:+UseCMSCompactAtFullCollection -XX:CMSFullGCsBeforeCompaction=0 -XX:+CMSParallelInitialMarkEnabled -XX:+CMSScavengeBeforeRemark -XX:+DisableExplicitGC -XX:+PrintGCDateStamps -XX:+PrintGCDetails -Xloggc:${CURRENT_SERVICE_REMOTE_DIR}/logs/gc-%t.log -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=${CURRENT_SERVICE_REMOTE_DIR}/logs/oom -Dfile.encoding=UTF-8"
EOF 
"""
)
]
)
]
)
echo "✅ Systemd服务文件已上传并配置完成"

echo "\033[32m ******正在配置并启动服务 ${ddc_name} ****** \033[0m"
sshPublisher(
publishers: [
sshPublisherDesc(
configName: "${params.TARGET_NODE}",
verbose: true,
transfers: [
sshTransfer(
usePty: true,
execCommand: """
sudo systemctl daemon-reload 
sudo systemctl enable cxyh-service@${ddc_name} 
sudo systemctl restart cxyh-service@${ddc_name} 
sudo systemctl status cxyh-service@${ddc_name} | grep -E 'Active|State' 
"""
)
]
)
]
)
}
echo "\033[34m === 服务 ${ddc_name} 部署/回滚完成 === \033[0m"
}
}
}
}
}

post {
always {
script {
currentBuild.description = """
Services: ${params.SERVICE_NAMES}
Target Node: ${params.TARGET_NODE}
Rollback: ${params.ROLLBACK ? '是' : '否'}
""".stripIndent().trim()
}
}

failure {
emailext body: """部署失败:
Build: ${env.JOB_NAME} #${env.BUILD_NUMBER}
Service(s): ${params.SERVICE_NAMES}
Node: ${params.TARGET_NODE}
Console: ${env.BUILD_URL}console
""", subject: '🚨 Jenkins告警: 服务部署失败'
}
success {
emailext body: """部署成功:
Build: ${env.JOB_NAME} #${env.BUILD_NUMBER}
Service(s): ${params.SERVICE_NAMES}
Node: ${params.TARGET_NODE}
Console: ${env.BUILD_URL}console
""", subject: '✅ Jenkins通知: 服务部署成功'
}
}
}`
```
### 2.服务器上查看状态

```
`[root@cxyh ~]# systemctl list-units --all | grep -i cxyh-service

cxyh-service@yunst-biz-admin.service                                      loaded  active  running  cxyh Service (yunst-biz-admin)

cxyh-service@yunst-biz-auth.service                                      loaded  active  running  cxyh Service (yunst-biz-auth)

cxyh-service@yunst-biz-call-center.service                                   loaded  active  running  cxyh Service (yunst-biz-call-center)

cxyh-service@yunst-biz-gateway.service                                     loaded  active  running  cxyh Service (yunst-biz-gateway)

cxyh-service@yunst-biz-insurance.service                                    loaded  active  running  cxyh Service (yunst-biz-insurance)

cxyh-service@yunst-biz-resource.service                                    loaded  active  running  cxyh Service (yunst-biz-resource)

cxyh-service@yunst-biz-stats-analy.service                                   loaded  active  running  cxyh Service (yunst-biz-stats-analy)

cxyh-service@yunst-biz-system-log.service                                   loaded  active  running  cxyh Service (yunst-biz-system-log)

cxyh-service@yunst-biz-system-manage.service                                  loaded  active  running  cxyh Service (yunst-biz-system-manage)

cxyh-service@yunst-biz-user.service                                      loaded  active  running  cxyh Service (yunst-biz-user)

cxyh-service@yunst-biz-xxljob-admin.service                                  loaded  active  running  cxyh Service (yunst-biz-xxljob-admin)`
```

