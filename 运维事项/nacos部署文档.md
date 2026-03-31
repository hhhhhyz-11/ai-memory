# nacos部署文档

> 来源: Trilium Notes 导出 | 路径: root/部署文档/nacos部署文档


nacos部署文档




## nacos部署文档


nacos官网下载地址：[Nacos Server 下载 | Nacos 官网](https://nacos.io/download/nacos-server/)


oracle版jdk官网下载地址：[Java 存档下载 — Java SE 8 | Oracle 中国](https://www.oracle.com/cn/java/technologies/javase/javase8-archive-downloads.html)


## 一.介绍：

1.nacos最新版本3.0.1需要jdk17或以上版本，这里以nacos2.4.3为例,nacos2.4.3需要jdk8版本

2.nacos引用的jdk默认是oracle版本，为了避免不必要的风险，不使用系统自带的openjdk，去官网下载oracle版本的jdk

## 2.部署步骤：

(1)通过网站下载包nacos-server-2.4.3.zip








(2)上传到服务器并且使用unzip解压就可以用








(3).配置防火墙或者关闭防火墙命令(以firewalld为例)











`#防火墙程序管理命令`

`systemctl    status    firewalld     #查看防火墙状态。`

`systemctl    start     firewalld     #启动防火墙。`

`systemctl    stop      firewalld     #关闭防火墙。`

`systemctl   enable   firewalld     #开机自启`

`systemctl   disable  firewalld     #移除开机自启`

`#防火墙使用命令`

`firewall-cmd     --list-all          #查看防火墙所以规则`

 
`#配置端口的白名单模板`

`firewall-cmd --permanent --add-rich-rule="rule family="ipv4" source address="10.194.173.201" port protocol="tcp" port="8848" accept"`       
`#开放8848端口并且添加10.194.173.201为白名单，白名单ip自定义。`

`firewall-cmd --permanent --remove-rich-rule="rule family="ipv4" source address="10.194.173.201" port protocol="tcp" port="8848" accept"`   
`#删除10.194.173.201白名单资格`

`firewall-cmd     --reload            #刷新防火墙规则`

 
`#需要注意，单节点开放8848端口即可，集群需要开放7848/8848/9848端口。`











 

 

(4)为了数据持久化，需要使用到mysql数据库来存储数据，需要创建数据库以及连接账号

 


**创建nacos数据库以及连接账号**










`#创建nacos使用的数据库`

`CREATE` `DATABASE` 
`nacos`

`CHARACTER` `SET` 
`utf8mb4`

`COLLATE` `utf8mb4_general_ci；`

 
`#创建nacos连接数据库账号密码（需注意mysql8.0以上创建账号需要mysql_native_password）`

`CREATE` `USER` 
`'nacos_admin'@'%'` `IDENTIFIED WITH` 
`mysql_native_password BY` `'你的强密码';    #创建账号`

`GRANT` `ALL` 
`PRIVILEGES` `ON` `nacos.* TO` 
`'nacos_admin'@'%';                                  
#设置账号权限，只对nacos库有所以权限`

`FLUSH PRIVILEGES;                                                                       #刷新权限`











(5).导入nacos数据库初始化文件


呈现代码宏出错: 参数'com.atlassian.confluence.ext.code.render.InvalidValueException'的值无效

mysql  -uroot  -hlocalhost  -p  nacos <  ncaos /conf/mysql-schema.sql    #初始化文件在解压后的ncaos/conf目录下，命令中nacos是（3）创建的mysql库，执行该命令后输入密码。

(6).集群需要多配置一步，每个单节点都要配置，单节点无需配置此文件











`vim  nacos/conf/cluster.conf            #配置nacos集群时，每个单节点都要配置，单节点使用无需配置`

 
`# ip:port`

`200.8.9.16:8848`

`200.8.9.17:8848`

`200.8.9.18:8848`











 

(7).修改配置文件，该配置单节点集群节点都可以使用。集群需要所有节点连接同一个数据库


**nacos配置文件application.properties**










`#`

`# Copyright 1999-2021` `Alibaba Group Holding Ltd.`

`#`

`# Licensed under the Apache License, Version 2.0` 
`(the "License");`

`# you may not use` `this` 
`file except in` `compliance with` 
`the License.`

`# You may obtain a copy of the License at`

`#`

`#      http://www.apache.org/licenses/LICENSE-2.0`

`#`

`# Unless required by applicable law or agreed to in` 
`writing, software`

`# distributed under the License is` 
`distributed on an "AS IS"` `BASIS,`

`# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.`

`# See the License for` `the specific language governing permissions and`

`# limitations under the License.`

`#`

 
`#*************** Spring Boot Related Configurations ***************#`

`### Default web context path:`

`server.servlet.contextPath=/nacos                                              #配置访问路径:http://localhost:8848/nacos`

`### Include message field`

`server.error.include-message=ALWAYS`

`### Default web server port:`

`server.port=8848`                                                              
`#配置端口`

 
`#*************** Network Related Configurations ***************#`

`### If prefer hostname over ip for` 
`Nacos server addresses in` `cluster.conf:`

`# nacos.inetutils.prefer-hostname-over-ip=false`

 
`### Specify local server's IP:`

`# nacos.inetutils.ip-address=`

 
 
`#*************** Config Module Related Configurations ***************#`

`### If use` `MySQL as` 
`datasource:`

`### Deprecated configuration property, it is` 
`recommended to use` ``spring.sql.init.platform` replaced.`

`# spring.datasource.platform=mysql`

`spring.sql.init.platform=mysql                                                                                                                                                   #指定数据类型`

 
`### Count of DB:`

`db.num=1`                                                                                                                                                                        
`#开启数据库模式`

 
`### Connect URL of DB:`

`db.url=jdbc:mysql://10.194.172.102:3306/nacos?characterEncoding=utf8&connectTimeout=1000&socketTimeout=3000&autoReconnect=true&useUnicode=true&useSSL=false&serverTimezone=UTC   #数据库连接方式`

`db.user=nacos_admin                                                                                                                                                              #数据库连接账号`

`db.password=Nacos.yunst.2025.com                                                                                                                                                 #数据库连接密码`

` ` 
`### Connection pool configuration: hikariCP`

`db.pool.config.connectionTimeout=30000`

`db.pool.config.validationTimeout=10000`

`db.pool.config.maximumPoolSize=20`

`db.pool.config.minimumIdle=2`

 
`### the maximum retry times for` `push`

`nacos.config.push.maxRetryTime=50`

 
`#*************** Naming Module Related Configurations ***************#`

`### If enable data warmup. If set` 
`to false, the server would accept request without local data preparation:`

`# nacos.naming.data.warmup=true`

 
`### If enable the instance auto expiration, kind like of health check of instance:`

`# nacos.naming.expireInstance=true`

 
`### will be removed and replaced by `nacos.naming.clean` properties`

`nacos.naming.empty-service.auto-clean=true`

`nacos.naming.empty-service.clean.initial-delay-ms=50000`

`nacos.naming.empty-service.clean.period-time-ms=30000`

 
`### Add in` `2.0.0`

`### The interval to clean empty service, unit: milliseconds.`

`# nacos.naming.clean.empty-service.interval=60000`

 
`### The expired time to clean empty service, unit: milliseconds.`

`# nacos.naming.clean.empty-service.expired-time=60000`

 
`### The interval to clean expired metadata, unit: milliseconds.`

`# nacos.naming.clean.expired-metadata.interval=5000`

 
`### The expired time to clean metadata, unit: milliseconds.`

`# nacos.naming.clean.expired-metadata.expired-time=60000`

 
`### The delay time before push task to execute from service changed, unit: milliseconds.`

`# nacos.naming.push.pushTaskDelay=500`

 
`### The timeout for` `push task execute, unit: milliseconds.`

`# nacos.naming.push.pushTaskTimeout=5000`

 
`### The delay time for` `retrying failed push task, unit: milliseconds.`

`# nacos.naming.push.pushTaskRetryDelay=1000`

 
`### Since 2.0.3`

`### The expired time for` `inactive client, unit: milliseconds.`

`# nacos.naming.client.expired.time=180000`

 
`#*************** CMDB Module Related Configurations ***************#`

`### The interval to dump external CMDB in` 
`seconds:`

`# nacos.cmdb.dumpTaskInterval=3600`

 
`### The interval of polling data change event in` 
`seconds:`

`# nacos.cmdb.eventTaskInterval=10`

 
`### The interval of loading labels in` 
`seconds:`

`# nacos.cmdb.labelTaskInterval=300`

 
`### If turn on data loading task:`

`# nacos.cmdb.loadDataAtStart=false`

 
 
`#*************** Metrics Related Configurations ***************#`

`### Metrics for` `prometheus`

`#management.endpoints.web.exposure.include=*`

 
`### Metrics for` `elastic search`

`management.metrics.export.elastic.enabled=false`

`#management.metrics.export.elastic.host=http://localhost:9200`

 
`### Metrics for` `influx`

`management.metrics.export.influx.enabled=false`

`#management.metrics.export.influx.db=springboot`

`#management.metrics.export.influx.uri=http://localhost:8086`

`#management.metrics.export.influx.auto-create-db=true`

`#management.metrics.export.influx.consistency=one`

`#management.metrics.export.influx.compressed=true`

 
`#*************** Access Log Related Configurations ***************#`

`### If turn on the access log:`

`server.tomcat.accesslog.enabled=true`

 
`### The access log pattern:`

`server.tomcat.accesslog.pattern=%h %l %u %t "%r"` 
`%s %b %D %{User-Agent}i %{Request-Source}i`

 
`### The directory of access log:`

`server.tomcat.basedir=file:.`

 
`#*************** Access Control Related Configurations ***************#`

`### If enable spring security, this` 
`option is` `deprecated in` `1.2.0:`

`#spring.security.enabled=false`

 
`### The ignore urls of auth, is` `deprecated in` 
`1.2.0:`

`nacos.security.ignore.urls=/,/error,/**/*.css,/**/*.js,/**/*.html,/**/*.map,/**/*.svg,/**/*.png,/**/*.ico,/console-ui/public/**,/v1/auth/**,/v1/console/health/**,/actuator/**,/v1/console/server/**`

 
`### The auth system to use, currently only 'nacos'` 
`and 'ldap'` `is` `supported:`

`nacos.core.auth.system.type=nacos                                                                                                                  #开启登录验证`

 
`### If turn on auth system:`

`nacos.core.auth.enabled=true`                                                                                                                      
`#开启登录验证`

`nacos.core.auth.default.token.secret.key=U0RBR3dhZGE4YTh3OTQ5NzU3YXc1dzAwMTI0MTI5NTlzYWRqZmF3aTcxMzEyKiY=`

`### worked when nacos.core.auth.system.type=ldap，{0} is` 
`Placeholder,replace login username`

`#nacos.core.auth.system.type=ldap`

`#nacos.core.auth.ldap.url=ldap://localhost:389`

`#nacos.core.auth.ldap.basedc=dc=example,dc=org`

`#nacos.core.auth.ldap.userDn=cn=admin,${nacos.core.auth.ldap.basedc}`

`#nacos.core.auth.ldap.password=admin`

`#nacos.core.auth.ldap.userdn=cn={0},dc=example,dc=org`

`#nacos.core.auth.ldap.filter.prefix=uid`

`#nacos.core.auth.ldap.case.sensitive=true`

`#nacos.core.auth.ldap.ignore.partial.result.exception=false`

`#nacos.core.auth.plugin.nacos.token.algorithm=HS256`

 
`### worked when nacos.core.auth.system.type=nacos`

`### The token expiration in` `seconds:`

`nacos.core.auth.plugin.nacos.token.cache.enable=false`

`nacos.core.auth.plugin.nacos.token.expire.seconds=18000`

`### The default` `token (Base64 String):`

`nacos.core.auth.plugin.nacos.token.secret.key=U0RBR3dhZGE4YTh3OTQ5NzU3YXc1dzAwMTI0MTI5NTlzYWRqZmF3aTcxMzEyKiY=                         #开启登录验证`

 
`### Turn on/off caching of auth information. By turning on this` 
`switch, the update of auth information would have a 15` `seconds delay.`

`nacos.core.auth.caching.enabled=true`

 
`### Since 1.4.1, Turn on/off white auth for` 
`user-agent: nacos-server, only for` `upgrade from old version.`

`nacos.core.auth.enable.userAgentAuthWhite=false`

 
`### Since 1.4.1, worked when nacos.core.auth.enabled=true` 
`and nacos.core.auth.enable.userAgentAuthWhite=false.`

`### The two properties is` `the white list for` 
`auth and used by identity the request from other server.`

`nacos.core.auth.server.identity.key=yunstNacos`

`nacos.core.auth.server.identity.value=Nacos@Yst2024.com`

 
`#*************** Istio Related Configurations ***************#`

`### If turn on the MCP server:`

`nacos.istio.mcp.server.enabled=false`

 
`#*************** Core Related Configurations ***************#`

 
`### set` `the WorkerID manually`

`# nacos.core.snowflake.worker-id=`

 
`### Member-MetaData`

`# nacos.core.member.meta.site=`

`# nacos.core.member.meta.adweight=`

`# nacos.core.member.meta.weight=`

 
`### MemberLookup`

`### Addressing pattern category, If set, the priority is` 
`highest`

`# nacos.core.member.lookup.type=[file,address-server]`

`## Set the cluster list with` `a configuration file or command-line argument`

`# nacos.member.list=192.168.16.101:8847?raft_port=8807,192.168.16.101?raft_port=8808,192.168.16.101:8849?raft_port=8809`

`## for` `AddressServerMemberLookup`

`# Maximum number of retries to query the address server upon initialization`

`# nacos.core.address-server.retry=5`

`## Server domain name address of [address-server] mode`

`# address.server.domain=jmenv.tbsite.net`

`## Server port of [address-server] mode`

`# address.server.port=8080`

`## Request address of [address-server] mode`

`# address.server.url=/nacos/serverlist`

 
`#*************** JRaft Related Configurations ***************#`

 
`### Sets the Raft cluster election timeout, default` 
`value is` `5` `second`

`# nacos.core.protocol.raft.data.election_timeout_ms=5000`

`### Sets the amount of time the Raft snapshot will execute periodically, default` 
`is` `30` `minute`

`# nacos.core.protocol.raft.data.snapshot_interval_secs=30`

`### raft internal` `worker threads`

`# nacos.core.protocol.raft.data.core_thread_num=8`

`### Number` `of threads required for` 
`raft business request processing`

`# nacos.core.protocol.raft.data.cli_service_thread_num=4`

`### raft linear read strategy. Safe linear reads are used by default, that is, the Leader tenure is` 
`confirmed by heartbeat`

`# nacos.core.protocol.raft.data.read_index_type=ReadOnlySafe`

`### rpc request timeout, default` 
`5` `seconds`

`# nacos.core.protocol.raft.data.rpc_request_timeout_ms=5000`

 
`#*************** Distro Related Configurations ***************#`

 
`### Distro data sync delay time, when sync task delayed, task will be merged for` 
`same data key. Default 1` `second.`

`# nacos.core.protocol.distro.data.sync.delayMs=1000`

 
`### Distro data sync timeout for` 
`one sync data, default` `3` `seconds.`

`# nacos.core.protocol.distro.data.sync.timeoutMs=3000`

 
`### Distro data sync retry delay time when sync data failed or timeout, same behavior with` 
`delayMs, default` `3` `seconds.`

`# nacos.core.protocol.distro.data.sync.retryDelayMs=3000`

 
`### Distro data verify interval time, verify synced data whether expired for` 
`a interval. Default 5` `seconds.`

`# nacos.core.protocol.distro.data.verify.intervalMs=5000`

 
`### Distro data verify timeout for` 
`one verify, default` `3` `seconds.`

`# nacos.core.protocol.distro.data.verify.timeoutMs=3000`

 
`### Distro data load retry delay when load snapshot data failed, default` 
`30` `seconds.`

`# nacos.core.protocol.distro.data.load.retryDelayMs=30000`

 
`### enable to support prometheus service discovery`

`#nacos.prometheus.metrics.enabled=true`

 
`### Since 2.3`

`#*************** Grpc Configurations ***************#`

 
`## sdk grpc(between nacos server and client) configuration`

`## Sets the maximum message size allowed to be received on the server.`

`#nacos.remote.server.grpc.sdk.max-inbound-message-size=10485760`

 
`## Sets the time(milliseconds) without read activity before sending a keepalive ping. The typical default` 
`is` `two hours.`

`#nacos.remote.server.grpc.sdk.keep-alive-time=7200000`

 
`## Sets a time(milliseconds) waiting for` 
`read activity after sending a keepalive ping. Defaults to 20`
`seconds.`

`#nacos.remote.server.grpc.sdk.keep-alive-timeout=20000`

 
 
`## Sets a time(milliseconds) that specify the most aggressive keep-alive time clients are permitted to configure. The typical default` 
`is` `5` `minutes`

`#nacos.remote.server.grpc.sdk.permit-keep-alive-time=300000`

 
`## cluster grpc(inside the nacos server) configuration`

`#nacos.remote.server.grpc.cluster.max-inbound-message-size=10485760`

 
`## Sets the time(milliseconds) without read activity before sending a keepalive ping. The typical default` 
`is` `two hours.`

`#nacos.remote.server.grpc.cluster.keep-alive-time=7200000`

 
`## Sets a time(milliseconds) waiting for` 
`read activity after sending a keepalive ping. Defaults to 20`
`seconds.`

`#nacos.remote.server.grpc.cluster.keep-alive-timeout=20000`

 
`## Sets a time(milliseconds) that specify the most aggressive keep-alive time clients are permitted to configure. The typical default` 
`is` `5` `minutes`

`#nacos.remote.server.grpc.cluster.permit-keep-alive-time=300000`











(8).系统的环境为openjdk，nacos使用的话会出现无法解密登录nacos的账号密码，所以需要多安装一个Oraclejdk，官网下载tar解压就可以直接使用，需要修改nacos的启动脚本,修改后保存











`vim   nacos/bin/startup.sh                       #打开启动脚本`

 
`export JAVA_HOME="/home/jdk1.8.0_202/"`          
`#默认配置是export JAVA_HOME ，需要在后面添加指定的java安装包/home/jdk1.8.0_202/`











(9).启动nacos











`nacos/bin/startup.sh -m standalone       #需要注意的是，nacos脚本启动默认是集群启动方式，单节点需要添加参数-m standalone`

`nacos/bin/startup.sh                     #脚本默认集群启动`











## 三.使用nacos

(1).启动后访问[http://ip:8848/nacos](http://ip:8848/nacos)，第一次访问会初始化账号密码，自定义即可

(2).登录界面后查看可以自定义修改密码，如果是集群得查看每个节点是否UP




(3).配置命名空间：命名空间名不能为空，描述不能为空，id可以自定义，如果id为空会自动生成，命名空间是给程序连接nacos使用的，所有必须配置。

