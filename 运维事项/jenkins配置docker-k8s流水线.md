# jenkins配置docker+k8s流水线

> 来源: Trilium Notes 导出 | 路径: root/Jenkins流水线/jenkins配置docker+k8s流水线


jenkins配置docker+k8s流水线




## jenkins配置docker+k8s流水线


### 1.流水线

`def skipRemainingStages = false
def timeout_mins = 60
def input_message
def randomToken
def skipadminUser = false

def Applier_id
def Applier_name
def Applier_mail

pipeline {
agent {
label 'test-47-node'
}

options {
ansiColor('xterm')
skipDefaultCheckout(true)
}

environment {
// 机器人名称
robot_name1 = '发版测试'
robot_name2 = '发版测试'
git_url = 'http://192.168.0.18:8080/foshandiandongzixingche/zzjjg/zzjjg-server.git'
harbor_url = '192.168.0.180:5000'
}

stages {
stage('发版初始化') {
steps("环境初始化"){
// 插件定义延迟5秒构建，防止git同时更改与拉取时，系统时间不完全一致导致的冲突
echo "\033[32m ******开始初始化构建环境****** \033[0m"
}
}

stage('测试环境跳过审批') {
when { expression { params.MODE == 'NO' }}
steps(){
script{
echo "\033[32m ******测试环境，跳过审批****** \033[0m"
echo params.MODE
skipRemainingStages = false  
}
}
}

stage("发送审批邮件"){
when { expression { params.MODE == 'YES' }}
steps{
wrap([$class: 'BuildUser']) {
script {
Applier_id = "${BUILD_USER_ID}"
Applier_name = "${BUILD_USER}"
Applier_mail = "${BUILD_USER_EMAIL}"
}
}
script{
if ("$adminUser" != ""){
adminUser = "$adminUser".split('@')[0]
//if (Applier_id == adminUser){
if (Applier_id == "自己"){
echo "\033[31m 审批人不能为自己，任务已终止。 \033[0m"
skipRemainingStages = true
currentBuild.result = 'ABORTED'
return
} 
}else{
echo "\033[31m 审批人不能为空，任务已终止。 \033[0m"
skipRemainingStages = true
currentBuild.result = 'ABORTED'
return
}

skipRemainingStages = false
echo "\033[32m ******发布生产操作需审批，接下来执行生产审批流程****** \033[0m"
randomToken = sh (script: "/bin/bash -c 'echo \$RANDOM | md5sum | cut -c 1-8'" , returnStdout: true).trim()
input_message = " $Applier_name 申请发布生产"
// echo "${randomToken}"
def targetEnvironment = ENV == 'dev' ? '开发环境' : (ENV == 'pro' ? '正式环境' : '未知环境')
def targetAdminUser = adminUser == 'yunst_yw' ? '运维组' : (adminUser == 'yunst_tlr' ? '欧总' : (adminUser == 'yunst_nn' ? '杨总' : adminUser))
dingtalk (
robot: "${robot_name1}",
type: "MARKDOWN",
title: '${targetEnvironment}有新的发版请求，请注意审批！',
text: [
"  ${targetAdminUser}想发版，请系一小时内审批！\n",

"  审批结果： 请叫${targetAdminUser}输入验证码……\n",

"  验证码： ${randomToken}",
],
)

dingtalk (
robot: "${robot_name2}",
type: "MARKDOWN",
title: '${targetEnvironment}有新的发版请求，请注意审批！',
text: [
"  ${targetAdminUser}想发版，请系一小时内审批！\n",

"  审批结果： 请叫${targetAdminUser}输入验证码……\n",

"  验证码： ${randomToken}",
],
)		
echo "\033[32m ******申请邮件已经发送，项目QA审批****** \033[0m"
}
}
}

stage("等待审批"){
when {
allOf {
expression { params.MODE == 'YES' }
expression {!skipRemainingStages} 
}
}
//   when { expression { params.MODE == 'YES' }}
//   when { expression {!skipRemainingStages}}
steps{
script{
def isAbort = false
timeout(timeout_mins){
try {
def userInput = input(
id: 'inputap', message: "$input_message", ok:"同意" , submitter:"$adminUser", parameters: [
[$class: 'StringParameterDefinition',defaultValue: "", name: 'token',description: '请输入发布的秘钥' ]
])
if (userInput == randomToken) {
skipRemainingStages = false
} else {
skipRemainingStages = true
echo "\033[31m 秘钥错误 \033[0m"
isAbort = true
}
echo "\033[31m 当前输入秘钥为： ${userInput} \033[0m"
}catch(err) {
echo "\033[31m ******任务已被审批人 $adminUser 拒绝****** \033[0m"
currentBuild.result = 'ABORTED'
isAbort = true
}
}
if (isAbort) {
throw new Exception("审核不通过")
}
}
}
}

stage("构建开始"){
when { expression {!skipRemainingStages}}
steps("构建开始") {
echo "\033[32m ******开始检出项目代码****** \033[0m"
checkout scmGit(
branches: [[name: '${branches}']], 
extensions: [authorInChangelog()], 
userRemoteConfigs: [[
credentialsId: 'gitlab', 
// url: 'http://192.168.0.18:8080/niuniu/canteenscan/canteenscan-server.git'
url: "${git_url}"
]]
)
echo "\033[32m ******checkOut ok****** \033[0m"
}
}

stage('开始打包') {
when { expression {!skipRemainingStages}}
steps {
// 进行jar包maven构建流程
sh '''
JAVA_HOME=/home/jdk17/jdk-17.0.14 /home/maven/apache-maven-3.8.1/bin/mvn -T 5 clean install -Dmaven.test.skip=true -U -P ${ENV}
'''
echo '\033[32m ******buildJar ok****** \033[0m'
}

}

stage('部署至K8s') {
when { expression {!skipRemainingStages}}
steps {
// 清除容器部署的临时目录
sh "sudo rm -rf ${WORKSPACE}/jarDir"
// 建立容器部署的临时目录,并把jar包复制到临时目录
// sh "mkdir -p ${WORKSPACE}/jarDir"
// sh 'sudo find ./ -name *.jar -type f | egrep -v \'*-common.jar|*-1.0.0.jar|*-api-*.jar|*-core.jar|*-snapshot.jar\' | xargs -i cp {} ./jarDir/'
script {
// 循环读取多选框内容，可用于多模块手选式更新，根据所选模块，进行容器镜像打包操作。
for (name in env.service_name.tokenize(',')) {
// 建立容器部署的临时目录,并把jar包复制到临时目录
sh "mkdir -p ${WORKSPACE}/jarDir/${name}"
sh "find ./ -name ${name}.jar -type f | xargs -i cp {} ./jarDir/${name}"
sh "cp /home/Template-java/Dockerfile-jar ${WORKSPACE}/jarDir/${name}/Dockerfile"
// 修改模板的nacos参数
//sh "sed -i 's/--NACOS_HOST=192.168.0.180/--NACOS_HOST=${nacos}/g' ${WORKSPACE}/jarDir/${name}/Dockerfile"
// 修改模板的数据库ip参数
sh "sed -i 's/--MYSQL_HOST=192.168.0.50/--MYSQL_HOST=${mysql}/g' ${WORKSPACE}/jarDir/${name}/Dockerfile"
// 修改模板的环境参数
sh "sed -i 's/jarENV/${ENV}/g' ${WORKSPACE}/jarDir/${name}/Dockerfile"
// 修改加入的jar包名称
sh "sed -i 's/jarName/${name}/g' ${WORKSPACE}/jarDir/${name}/Dockerfile"
// 打包容器镜像
sh "cd ${WORKSPACE}/jarDir/${name} && docker build -t ${harbor_url}/${JOB_NAME}/${JOB_NAME}-${branches}:${name}-${ENV}-${BUILD_ID} -f Dockerfile ."
// 上传至harbor仓库
sh "docker push ${harbor_url}/${JOB_NAME}/${JOB_NAME}-${branches}:${name}-${ENV}-${BUILD_ID}"
// 删除本地镜像
sh "docker rmi ${harbor_url}/${JOB_NAME}/${JOB_NAME}-${branches}:${name}-${ENV}-${BUILD_ID}"
// 删除已使用Dockerfile
sh "sudo rm -rf ${WORKSPACE}/jarDir/${name}/Dockerfile"

// 判断yaml文件是否存在
if(fileExists("/home/Template-java/${JOB_NAME}/${JOB_NAME}-${name}.yaml")){
echo "文件已存在，无需复制！"
// 已存在则直接利用正则表达式匹配字符串，替换模板yaml对应字符串名称即可
sh "sed -i 's/${branches}:${name}-${ENV}-[0-9]*/${branches}:${name}-${ENV}-${BUILD_ID}/g' /home/Template-java/${JOB_NAME}/${JOB_NAME}-${name}.yaml"
} else {
echo "文件不存在，从公共模板生成中..."
sh "mkdir -p /home/Template-java/${JOB_NAME}"
// 根据模块名，从k8s模板中生成对应yaml文件
sh "cp /home/Template-java/Template-java-zzjjg.yaml /home/Template-java/${JOB_NAME}/${JOB_NAME}-${name}.yaml"
// 修改成匹配的日志挂载目录(此更改必须在第一位)
sh "sed -i 's/rizhipath/${name}/g' /home/Template-java/${JOB_NAME}/${JOB_NAME}-${name}.yaml"
// 修改成匹配的日志挂载目录(此更改必须在第二位)
sh "sed -i 's|gzddc-server/logspath|${JOB_NAME}/${name}|g' /home/Template-java/${JOB_NAME}/${JOB_NAME}-${name}.yaml"
// 根据项目名，替换模板的命名空间
sh "sed -i 's/gzddc-server/${JOB_NAME}/g' /home/Template-java/${JOB_NAME}/${JOB_NAME}-${name}.yaml"
// 根据模块名，替换模板的app、name、image
sh "sed -i 's/gzddc-admin/${name}/g' /home/Template-java/${JOB_NAME}/${JOB_NAME}-${name}.yaml"
// 修改成匹配的代码分支名称
sh "sed -i 's/uat/${branches}/g' /home/Template-java/${JOB_NAME}/${JOB_NAME}-${name}.yaml"
// 修改成匹配的环境配置文件
sh "sed -i 's/env/${ENV}/g' /home/Template-java/${JOB_NAME}/${JOB_NAME}-${name}.yaml"
// 修改成匹配的Buid-id配置文件
sh "sed -i 's/build-id/${BUILD_ID}/g' /home/Template-java/${JOB_NAME}/${JOB_NAME}-${name}.yaml"
}

// 部署模块至k8s
sh "kubectl apply -f /home/Template-java/${JOB_NAME}/${JOB_NAME}-${name}.yaml"
echo "\033[32m ******${name}模块已部署完成...****** \033[0m"
}
}
}
}
} 
}`
### 2.Dockerfile模板

```
`FROM openjdk:17-jdk

#标准参数

#ENV STANDAR_PARAMS="-Xms256m -Xmx256m -XX:+PrintGCDateStamps -XX:+PrintGCDetails -Xloggc:gc-%t.log -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/home/wxpay/dump_%t_%p.hprof"

ENV STANDAR_PARAMS="-Xms256m -Xmx256m -XX:+UseG1GC -Xlog:gc*:file=gc-%t.log:time,uptime,level,tags -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/home/wxpay/dump_%t_%p.hprof"

#非标准参数，这里每个容器都启动8080是没问题的，因为每个容器ip是不一样，不同ip+8080端口还是唯一的。

ENV NON_STANDAR_PARAMS="--MYSQL_HOST=192.168.0.50 --server.port=8080 --spring.profiles.active=jarENV"

RUN /bin/cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && echo 'Asia/Shanghai' >/etc/timezone

COPY jarName.jar /jarName.jar

EXPOSE 8080

#启动参数

ENTRYPOINT ["/bin/sh","-c","java -Dfile.encoding=utf8 -Djava.security.egd=file:/dev/./urandom -Ddruid.mysql.usePingMethod=false ${STANDAR_PARAMS} -jar jarName.jar ${NON_STANDAR_PARAMS}"]`
```
3.k8s yaml文件

`---

apiVersion: apps/v1

kind: Deployment

metadata:

annotations: {}

labels:

app: gzddc-admin

name: gzddc-admin

namespace: gzddc-server

spec:

progressDeadlineSeconds: 600

replicas: 1

revisionHistoryLimit: 3

selector:

matchLabels:

app: gzddc-admin

strategy:

rollingUpdate:

maxSurge: 25%

maxUnavailable: 25%

type: RollingUpdate

template:

metadata:

annotations:

kubectl.kubernetes.io/restartedAt: '2023-06-02T16:50:42+08:00'

creationTimestamp: null

labels:

app: gzddc-admin

spec:

containers:

- image: '192.168.0.180:5000/gzddc-server/gzddc-server-uat:gzddc-admin-env-build-id'

readinessProbe:

failureThreshold: 3

initialDelaySeconds: 30

periodSeconds: 30

successThreshold: 1

tcpSocket:

port: 8080

timeoutSeconds: 5

livenessProbe:

failureThreshold: 10

initialDelaySeconds: 30

periodSeconds: 5

successThreshold: 1

tcpSocket:

port: 8080

timeoutSeconds: 5

imagePullPolicy: IfNotPresent

name: gzddc-admin

resources: {}

terminationMessagePath: /dev/termination-log

terminationMessagePolicy: File

volumeMounts:

- mountPath: /home/data/tmp

name: upload-tmp

- mountPath: /home/wxpay

name: payment-path

- mountPath: /logs/rizhipath

mountPropagation: None

name: logs

dnsPolicy: ClusterFirst

imagePullSecrets:

- name: yst-docker-harbor

nodeName: node2

restartPolicy: Always

schedulerName: default-scheduler

securityContext: {}

terminationGracePeriodSeconds: 30

volumes:

- emptyDir: {}

name: upload-tmp

- hostPath:

path: /home/wxpay

type: DirectoryOrCreate

name: payment-path

- hostPath:

path: /home/logs/gzddc-server/logspath

type: DirectoryOrCreate

name: logs`

