# jenkins配置java项目流水线

> 来源: Trilium Notes 导出 | 路径: root/Jenkins流水线/jenkins配置java项目流水线




jenkins配置java项目流水线




## jenkins配置java项目流水线


## 一、 前置配置

1、 jenkins Publish over SSH已配置部署节点

[jenkins控制台 => Dashboard](http://192.168.0.180:8868/) 
=> [Manage Jenkins](http://192.168.0.180:8868/manage/) => System => Publish over SSH









2、 服务器已配置mvn打包编译需要的JDK环境


对应流水线配置


JAVA_HOME = "/home/jdk1.8.0_291"

pipeline示例










`environment {`

`  SERVICE_NAME = "zjd"`

`  REMOTE_DIR = "/home/project/zjd-server"`

`  JAVA_HOME = "/home/jdk1.8.0_291"`

`  GIT_URL = "`[`http://192.168.0.18:8080/tlr/zyt/zyt-easypost-server.git`](http://192.168.0.18:8080/tlr/zyt/zyt-easypost-server.git)
`"`

`  LOG_PATH = "/tmp/zjd.log"`

`}`











## 二、 创建jenkins项目

### **1、 创建一个pipeline风格的项目**








2、 根据项目修改pipeline流水线


**java发版流水线**
`pipeline {

agent any



parameters {

string(

name: 'branches',

defaultValue: 'uat',

description: 'uat - 测试分支'

)

choice(

name: 'ENV',

choices: ['uat', 'govuat', 'secuat'],

description: 'uat：数据同步测试环境\ngovuat：政务网数据同步测试环境\nsecuat：公安网数据同步测试环境'

)

string(

name: 'SERVICE_PORT',

defaultValue: '8082',

description: '服务监听端口（留空则使用配置文件的默认值）'

)

string(

name: 'HTTP_PORT',

defaultValue: '8083',

description: '服务监听端口（留空则使用配置文件的默认值）'

)

string(

name: 'JAVA_OPTS_XMS',

defaultValue: '-Xms256m',

description: '设置JVM参数'

)

string(

name: 'JAVA_OPTS_XMX',

defaultValue: '-Xmx512m',

description: '设置JVM参数'

)

booleanParam(

name: 'ROLLBACK',

defaultValue: false,

description: '是否回滚到上一个版本'

)

choice(

name: 'TARGET_NODE',

choices: ['192.168.0.180','192.168.0.44'],

description: '选择目标节点'

)

}



environment {

SERVICE_NAME = "zjd"

REMOTE_DIR = "/home/project/zjd-server"

JAVA_HOME = "/home/jdk1.8.0_291"

GIT_URL = "http://192.168.0.18:8080/tlr/zyt/zyt-easypost-server.git"

LOG_PATH = "/tmp/zjd.log"

}



stages {

stage("拉取代码"){

when { expression { !params.ROLLBACK } } 

steps {

echo "\033[32m ******开始检出项目代码****** \033[0m"

checkout scmGit(

branches: [[name: "${params.branches}"]],

extensions: [authorInChangelog()],

userRemoteConfigs: [[

credentialsId: 'gitlab',

url: "${git_url}"

]]

)

echo "\033[32m ******checkOut ok****** \033[0m"

}

}



stage('编译JAR包') {  

when { expression { !params.ROLLBACK } } 

steps {

// 进行jar包maven构建流程

sh """

JAVA_HOME=${env.JAVA_HOME} mvn -T 5 clean install -Dmaven.test.skip=true -U -P ${params.branches}

"""

echo '\033[32m ******buildJar ok****** \033[0m'

}

}



stage('备份当前版本') {

when { expression { !params.ROLLBACK } }

steps {

script {

sshPublisher(

publishers: [

sshPublisherDesc(

configName: "${params.TARGET_NODE}",

transfers: [

sshTransfer(

remoteDirectory: "${env.REMOTE_DIR}",

execCommand: """

pwd && ls

jar_name=\$(ls *.jar | grep -v 'original-' | head -1 | xargs basename)

[ -z "\$jar_name" ] || cp "\$jar_name" "\${jar_name}.bak"

"""

)

]

)

]

)

}

}

}



stage('部署服务') {

steps {

script {

if (params.ROLLBACK) {

sshPublisher(

publishers: [

sshPublisherDesc(

configName: "${params.TARGET_NODE}",

transfers: [

sshTransfer(

remoteDirectory: "${env.REMOTE_DIR}",

execCommand: """

pwd && ls

jar_name=\$(ls *.jar | grep -v 'original-' | head -1 | xargs basename)

cp \${jar_name}.bak \${jar_name} 

systemctl restart ${env.SERVICE_NAME}

"""

)

]

)

]

)

} else {

// 使用def声明变量

def buildJarName = sh(

script: '''

ls target/*.jar | grep -v "original-" | head -1 | xargs -I{} basename {}

''',

returnStdout: true

).trim()

echo " 获取的JAR名称: ${buildJarName}"

echo "JAR名称: ${buildJarName}"

echo "服务名称: ${env.SERVICE_NAME}"

echo "使用端口: ${params.SERVICE_PORT}"

sshPublisher(

publishers: [

sshPublisherDesc(

configName: "${params.TARGET_NODE}",

verbose: true, // 开启详细日志

transfers: [

sshTransfer(

sourceFiles: "target/${buildJarName}",

removePrefix: "target",

remoteDirectory: "${env.REMOTE_DIR}",

execCommand: """

# 创建systemd服务配置文件

cat > ${env.LOG_PATH} 2>&1'

StandardOutput=journal

StandardError=journal



[Install]

WantedBy=multi-user.target

EOF

# 拷贝服务文件

if [ -f "${env.REMOTE_DIR}/${SERVICE_NAME}.service" ]; then

sudo /bin/cp ${env.REMOTE_DIR}/${SERVICE_NAME}.service /etc/systemd/system/${SERVICE_NAME}.service

echo " 服务文件已拷贝到 /etc/systemd/system/${SERVICE_NAME}.service"

else

echo " 服务文件不存在"

exit 1

fi

systemctl daemon-reload

systemctl enable ${SERVICE_NAME}.service

systemctl restart ${SERVICE_NAME}.service

"""

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



post {

always {

script {

currentBuild.description = """

SERVICE: ${env.SERVICE_NAME}

SERVICE_Port: ${env.SERVICE_PORT}

HTTP_Port: ${env.HTTP_PORT}

Rollback: ${params.ROLLBACK}

""".stripIndent().trim()

}

}



failure {

emailext body: """部署失败:

Build: ${env.JOB_NAME} #${env.BUILD_NUMBER}

Service: ${env.SERVICE_NAME}

Console: ${env.BUILD_URL}console

""", subject: ' 部署失败告警'

}

}

}`



 全局环境变量修改











`environment {`

`   # 服务工作路径`

`   REMOTE_DIR = "/home/project/zjd-server/"`

`   # 服务名（systemd服务名）`

`   SERVICE_NAME = "zjd"`

`   # JDK工作路径`

`   JAVA_HOME = "/home/jdk1.8.0_291"`

`   # GIT仓库地址`

`   GIT_URL = "`[`http://192.168.0.18:8080/tlr/zyt/zyt-easypost-server.git`](http://192.168.0.18:8080/tlr/zyt/zyt-easypost-server.git)
`"`

`   #日志路径`

`  LOG_PATH = "/tmp/zjd.log"`

` }`














参数化选项配置（根据项目需要进行修改）















`parameters {`

`  string(`

`    name: 'branches',`

`    defaultValue: 'uat',`

`    description: 'uat - 测试分支'`

`  )`

`  choice(`

`      name: 'ENV',`

`      choices: ['uat', 'govuat', 'secuat'],`

`      description: 'uat：数据同步测试环境\ngovuat：政务网数据同步测试环境\nsecuat：公安网数据同步测试环境'`

`  )`

`  string(`

`    name: 'SERVICE_PORT',`

`    defaultValue: '8082',`

`    description: '服务监听端口（留空则使用配置文件的默认值）'`

`  )`

`  string(`

`    name: 'HTTP_PORT',`

`    defaultValue: '8083',`

`    description: '服务监听端口（留空则使用配置文件的默认值）'`

`  )`

`  string(`

`    name: 'JAVA_OPTS_XMS',`

`    defaultValue: '-Xms256m',`

`    description: '设置JVM参数'`

`  )`

`  string(`

`    name: 'JAVA_OPTS_XMX',`

`    defaultValue: '-Xmx512m',`

`    description: '设置JVM参数'`

`  )`

`  booleanParam(`

`    name: 'ROLLBACK',`

`    defaultValue: false,`

`    description: '是否回滚到上一个版本'`

`  )`

`  choice(`

`      name: 'TARGET_NODE',`

`      choices: ['192.168.0.180','192.168.0.44'],`

`      description: '选择目标节点'`

`  )`

`}`











### **3、 添加流水线**








 

### **4、 生成参数化选项**

首次添加流水线后不会出现以下的参数化选项，需要进行一次发版后才会生成









 

## 三、 服务发版

### **1、 进入对应的项目，选择参数化构建**








### **2、发版更新**

默认情况下不需要填写和修改参数化的值，只需要选择需要部署的节点，直接进行Build即可


 



选择部署节点

 







 




进行构建












### **3、版本回滚**

勾选ROLLBACK后，进行上一次版本的发版，默认只支持发版失败后单次回滚，不建议进行多次版本回滚









## 四、 服务下线

登录到部署的服务器进行下线


```
${service_name}为实际的服务名
```










`# 停止服务`

`systemctl stop ${service_name}`

 
`# 禁止开机自启`

`systemctl disable ${service_name}`

 
`# 删除配置文件`

`rm  /etc/systemd/system/${service_name}.service`

