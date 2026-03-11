# SonarQube 批量导出 CSV 完整方案

> 将 SonarQube 导出的 Protobuf 数据批量转为 CSV，突破 10000 条限制

## 一、背景

SonarQube 页面或 API 导出报告时，**超过 10000 条会报错**。

**解决方案：**
1. SonarQube 导出 **Protobuf 格式**（原始数据，无限制）
2. 用 Java 工具转成 **CSV**（Excel 格式）

---

## 二、架构

```
SonarQube(导出) → Jenkins(Pipeline) → Shell脚本(转换) → Nginx(下载)
     .zip                                    .csv              http://...8088
```

---

## 三、前置条件

### 1. 打包 Java 工具

```bash
# 拉取代码
git clone http://192.168.0.18:8080/ddc/tools/test-tool.git

# 打包
cd test-tool
mvn clean package -DskipTests

# 复制 jar
cp target/test-tools-0.0.1-SNAPSHOT.jar /home/ansible/sonarqubetocsv/
```

### 2. 下载依赖

```bash
cd /home/ansible/sonarqubetocsv/
curl -L -o commons-csv.jar https://repo1.maven.org/maven2/org/apache/commons/commons-csv/1.10.0/commons-csv-1.10.0.jar
```

### 3. 创建目录

```bash
mkdir -p /home/ansible/sonarqubetocsv/{csv,pbfiles}
```

---

## 四、完整配置

### 1. 执行脚本

**路径：** `/home/ansible/sonarqubetocsv/sonar_export.sh`

```bash
#!/bin/bash

PROJECT_INPUT=$1
if [ -z "$PROJECT_INPUT" ]; then
    echo "用法: ./sonar_export.sh 项目名"
    exit 1
fi

SOURCE_DIR="/home/Sonarqube/data/governance/project_dumps/export"
WORK_DIR="/home/ansible/sonarqubetocsv"
PB_DIR="$WORK_DIR/pbfiles"
CSV_DIR="$WORK_DIR/csv"
TIMESTAMP=$(date +%Y%m%d%H%M)

mkdir -p $CSV_DIR
rm -rf $PB_DIR
mkdir -p $PB_DIR

ZIP_FILE="$SOURCE_DIR/${PROJECT_INPUT}.zip"
if [ ! -f "$ZIP_FILE" ]; then
    echo "错误: $ZIP_FILE 不存在，请先在 SonarQube 导出"
    exit 1
fi

TEMP_DIR="$WORK_DIR/temp_${PROJECT_INPUT}"
rm -rf $TEMP_DIR
mkdir -p $TEMP_DIR
unzip -q "$ZIP_FILE" -d $TEMP_DIR
rm -f $ZIP_FILE

mv $TEMP_DIR/*.pb $PB_DIR/ 2>/dev/null

export JAVA_HOME=/home/jdk1.8.0_291
export PATH=$JAVA_HOME/bin:$PATH

cd $WORK_DIR
java -cp "test-tools-0.0.1-SNAPSHOT.jar:commons-csv.jar" \
    com.example.test.tools.utils.other.protobuf.SonarPbToCsvConverter \
    $PB_DIR "$CSV_DIR/${PROJECT_INPUT}_${TIMESTAMP}.csv"

rm -rf $TEMP_DIR
echo "完成: $CSV_DIR/${PROJECT_INPUT}_${TIMESTAMP}.csv"
```

### 2. Jenkins Pipeline

```groovy
pipeline {
    agent { label 'test-47-node' }
    
    parameters {
        choice(
            name: 'PROJECT', 
            choices: ['bike-server-uat', 'bike-server-master'], 
            description: '选择项目'
        )
    }
    
    stages {
        stage('执行转换') {
            steps {
                sh "/home/ansible/sonarqubetocsv/sonar_export.sh ${params.PROJECT}"
            }
        }
    }
    
    post {
        success {
            echo "文件下载入口: http://192.168.0.47:8088/"
        }
    }
}
```

### 3. Nginx 配置（带密码）

```bash
# 创建密码
htpasswd -bc /etc/nginx/.passwd admin 你的密码

# 配置
cat > /etc/nginx/conf.d/sonarqube-csv.conf << 'EOF'
server {
    listen 8088;
    server_name _;
    
    location / {
        root /home/ansible/sonarqubetocsv/csv;
        autoindex on;
        charset utf-8;
        
        auth_basic "请输入密码";
        auth_basic_user_file /etc/nginx/.passwd;
        
        allow 192.168.0.0/24;
        deny all;
    }
}
EOF

systemctl restart nginx
```

---

## 五、操作步骤

| 步骤 | 操作 | 说明 |
|------|------|------|
| 1 | SonarQube 导出 | 项目 → 导出 → Protobuf → 下载 |
| 2 | Jenkins 构建 | Sonar_To_Csv → 选择项目 → 构建 |
| 3 | 下载 | 访问 http://192.168.0.47:8088/ |

---

## 六、命令解释

| 命令 | 说明 |
|------|------|
| `unzip -q` | 解压 zip |
| `java -cp` | 运行 Java 程序 |
| `htpasswd -bc` | 创建密码文件 |
| `systemctl restart nginx` | 重启 Nginx |

---

## 七、常见问题

**Q: zip 文件用完去哪了？**
> A: 自动删除了，下次需要重新导出

**Q: 密码忘了怎么办？**
> A: 重新执行 `htpasswd -bc /etc/nginx/.passwd admin 新密码`

**Q: 下载页面空白？**
> A: 检查 Nginx：`systemctl status nginx`
