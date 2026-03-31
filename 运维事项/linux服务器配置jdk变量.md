# linux服务器配置jdk变量

> 来源: Trilium Notes 导出 | 路径: root/linux服务器配置jdk变量


linux服务器配置jdk变量




## linux服务器配置jdk变量


从oracle官网下载jdk.tar.gz包

官网地址：https://www.oracle.com/java/technologies/javase/javase8-archive-downloads.html

## 一、解压 JDK












jdk-8u202-linux-x64.tar.gz




`tar -zxvf jdk-8u202-linux-x64.tar.gz`















解压后会得到目录：












jdk1.8.0_202










 




建议移动到 `/usr/local`：











`mv jdk1.8.0_202 /usr/local`











## 二、配置 JAVA_HOME

编辑环境变量：











`vi /etc/profile`











在 **文件最后**加入：











`export JAVA_HOME=/usr/local/jdk1.8.0_202
export PATH=$JAVA_HOME/bin:$PATH`











## 三、让配置生效

执行：











`source /etc/profile`











## 四、验证 Java











```
`java -version`
```











正常会看到类似：











```
`java version "1.8.0_202"
Java(TM) SE Runtime Environment
Java HotSpot(TM) 64-Bit Server VM`
```

