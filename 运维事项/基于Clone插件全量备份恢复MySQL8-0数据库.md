# 基于Clone插件全量备份恢复MySQL8.0数据库

> 来源: Trilium Notes 导出 | 路径: root/数据备份/基于Clone插件全量备份恢复MySQL8.0数据库


基于Clone插件全量备份恢复MySQL8.0数据库




## 基于Clone插件全量备份恢复MySQL8.0数据库






**背景**



背景情况说明，参考上篇：[基于xtrabackup全量备份恢复MySQL5.7数据库](http://192.168.0.18:8090/pages/viewpage.action?pageId=24577164)



书接上回，本篇章，主要讲述基于MySQL8.0新特性Clone插件实现全量备份恢复新实例，并且搭建主从架构。










**情况说明**



目前，

19.129.13.179/192.168.100.50、19.129.13.180/192.168.100.60：MySQL8.0.25版本数据库


218.13.168.162/192.168.100.150：MySQL8.0.39版本数据库。


因此，应该要基于这三台服务器搭建环路复制。虽然他们版本号不一样，但是我们是通过docker启动，只需要docker镜像中的MySQL版本和主库一样即可。


服务器概况：


19.129.13.179：CentOS系统，firewalld开启，核心配置文件：/etc/my.cnf，
**坑点1：collation-server=utf8mb4_0900_ai_ci，不是用的通用的utf8mb4_general_ci，恢复时也一定要用相同的字符集。坑点2：innodb_buffer_pool_size=10G，恢复时不需要指定这么大的内存，毕竟我们只是做备库，指定1G即可。**


19.129.13.180：CentOS系统，firewalld开启，核心配置文件：/etc/my.cnf，
**坑点1：innodb_buffer_pool_size=12G，恢复时不需要指定这么大的内存，毕竟我们只是做备库，指定1G即可。坑点2：innodb_log_file_size=2G，备库要修改为相同的redo log大小，否则恢复失败。**


192.168.100.150：CentOS系统，firewalld开启，核心配置文件：/etc/my.cnf，
**坑点1：innodb_redo_log_capacity=512MB，备库要修改为相同的redo log大小，否则恢复失败。坑点2：gtid_mode=on、enforce-gtid-consistency=1，备库也必须开启gtid，否则主从搭建失败。**



说明：环形备份方案是： 179（主） → 180（从）、180（主） → 150（从）、150（主）- > 179（从）


注意：提前在160、150准备好MySQL8.0.25的docker镜像，在179准备好MySQL8.0.39的docker镜像。








**实施前必备条件**



1、MySQL版本（包括小版本）必须一致，且支持Clone Plugin。


2、主机的操作系统和位数（32位，64位）必须一致。可根据SHOW VARIABLES LIKE 'version_compile_os'; SHOW VARIABLES LIKE 'version_compile_machine';参数获取。


3、**从库必须有足够的磁盘空间存储克隆数据。所以要做好评估，特别是像佛山电动车那900多G的sys_api_log表，该清理就得清理。**


4、**字符集（character_set_server），校验集（collation_server），character_set_filesystem必须一致。查询了这三台MySQL配置，就179数据库的collation_server特别，所以，备份恢复179数据库时，要注意，恢复的从库的collation_server也要和179的一致（从库my.cnf中要配置和179一样的值）**


5、从库clone成功后，默认会自动重启，但由于我们是用docker方式管理，所以会重启失败，不过这是正常现象，只需要手动通过docker方式重启从库即可。











**重要说明！**



**下面给出了3份从库的my.cnf，备份恢复相应从库时，就用对应的my.cnf即可，不要做改动！**











**179从库my.cnf配置文件内容**










`[mysqld]`

`bind-address=0.0.0.0`

`port=3306`

`user=mysql`

`#错误日志，默认在/var/lib/mysql/mysql-error.log`

`log-error=mysql-error.log`

`#字符编码`

`character-set-server=utf8mb4`

`collation-server=utf8mb4_0900_ai_ci`

`default-time-zone='+08:00'`

`#innodb缓冲，没必要像主库一样给那么大`

`innodb_buffer_pool_size=1G`

`#最大连接数`

`max_connections=2000`

`#一次消息传输量最大值`

`max_allowed_packet=128M`

`#创建新表时将使用的默认存储引擎`

`default-storage-engine=INNODB`

`#临时表缓存`

`tmp_table_size=128M`

`max_heap_table_size=1024M`

`#读入缓冲区大小`

`read_buffer_size=1M`

`read_rnd_buffer_size=16M`

`sort_buffer_size=2M`

`max_length_for_sort_data=1024`

`#表间关联缓存`

`join_buffer_size=2M`

`bulk_insert_buffer_size=64M`

`#MyISAM索引缓冲区大小`

`key_buffer_size=1000M`

`#MyISAM重新排序缓存`

`myisam_sort_buffer_size=128M`

`#innodb读写线程`

`innodb_read_io_threads=12`

`innodb_write_io_threads=10`

`#关闭大小写敏感`

`lower_case_table_names=1`

`#开启binlog日志,设置binlog日志文件以mysql-bin开头`

`log_bin=mysql-bin`

`#binlog过期清理时间,默认值为0,表示没有自动删除`

`expire_logs_days=90`

`# 禁用DNS反向解析（解决连接慢的核心问题）`

`skip-name-resolve`

`#唯一服务id，和主库区分`

`server_id=2`

`[client]`











 






**180从库my.cnf配置文件内容**










`[mysqld]`

`#mysql基础配置`

`bind-address=0.0.0.0`

`port=3306`

`user=mysql`

`#错误日志，默认在/var/lib/mysql/mysql-error.log`

`log-error=mysql.err`

`#字符编码`

`character-set-server=utf8mb4`

`collation-server=utf8mb4_general_ci`

`default-time-zone='+08:00'`

`#缓冲区，没必要像主库一样给那么大`

`innodb_buffer_pool_size=1G`

`#重做日志大小`

`innodb_log_file_size=2G`

`#最大连接数`

`max_connections=500`

`#创建新表时将使用的默认存储引擎`

`default-storage-engine=INNODB`

`#sql-mode配置支持查询非group` `by字段`

`sql-mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION`

`#关闭大小写敏感`

`lower_case_table_names=1`

`#开启binlog日志,设置binlog日志文件以mysql-bin开头`

`log_bin=mysql-bin`

`#binlog过期清理时间,默认值为0,表示没有自动删除`

`expire_logs_days=90`

`# 禁用DNS反向解析（解决连接慢的核心问题）`

`skip-name-resolve`

`#唯一服务id，和主库区分`

`server_id=2`

`[client]`











 

 






**150从库my.cnf配置文件内容**










`[mysqld]`

`# GENERAL`

`user=mysql`

`port=3306`

`# INNODB`

`# 缓冲池大小，默认是128M`

`innodb_buffer_pool_size=1G`

`# redo文件大小`

`innodb_redo_log_capacity=512MB`

`# 错误日志，默认在/var/lib/mysql/mysql-error.log`

`log-error=mysql-error.log`

`# 字符编码`

`character-set-server=utf8mb4`

`collation-server=utf8mb4_general_ci`

`# 时区`

`default-time-zone='+08:00'`

`# 临时表大小，默认16Mb`

`tmp_table_size=32M`

`max_heap_table_size=32M`

`max_connections=500`

`open_files_limit=10000`

`# 排序缓冲区，默认值256KB，如果查询字段过多或是字段内容过大超出排序缓冲区会报错，改为2M`

`sort_buffer_size=2M`

`# 创建新表时将使用的默认存储引擎`

`default-storage-engine=INNODB`

`# 关闭大小写敏感`

`lower_case_table_names=1`

`# 开启binlog日志,指定binlog日志存放目录（此目录要求也是属于mysql用户和组才行），设置binlog日志文件以mysql-binlog开头,并且指定binlog日志存储位置,binlog日志不要和mysql数据放在同一个目录！`

`log_bin=mysql-binlog`

`# 开启GTID`

`gtid_mode=on`

`enforce-gtid-consistency=1`

`# 更新记录的binlog事件日志前后镜像记录了所有字段值，默认值FULL`

`binlog_row_image=FULL`

`# 设置binlog保留日志时间90天，单位秒`

`binlog_expire_logs_seconds=7776000`

`# 设置binlog日志文件大小`

`max_binlog_size=100m`

`# 设置缓存，默认32KB`

`binlog_cache_size=4m`

`# 设置日志时间为系统时间`

`log_timestamps=SYSTEM`

`# 禁用DNS反向解析（解决连接慢的核心问题）`

`skip-name-resolve`

`# 唯一服务id，和主库区分`

`server_id=2`

`[client]`

















**说明：本次实施步骤以预录入192.168.100.50（即179政务网服务器）服务器的MySQL8.0.25作为主库，通过clone插件全量备份复制到192.168.100.60（即180政务网服务器）服务器，并且在60服务器拉起docker方式的MySQL从库实例，最后搭建主从复制架构。**


**简写说明：**


**主库：指的就是179政务网服务器**


**从库：指的就是180政务网服务器**









**实施步骤1**










`# 从库创建新mysql相关目录，根据实际情况决定目录位置`

`mkdir -p /home/mysql-slave/conf`

`mkdir -p /home/mysql-slave/data`

 
`# 从库创建mysql配置文件`

`vim /home/mysql-slave/conf/my.cnf`

`# 粘贴上面的[179从库my.cnf配置文件内容]即可！`

`# > 备份恢复180从库时，就用[180从库my.cnf配置文件内容]，150也是同理！`

 
`# 从库启动docker实例`

`# -v /home/mysql-slave/conf:/etc/mysql/conf.d -v /home/mysql-slave/data:/var/lib/mysql ：挂载从库的配置和data目录`

`# MYSQL_ROOT_PASSWORD：设置root密码，方便我们等下进入容器实例操作。`

`# mysql:8.0.25：MySQL Clone要求源库和目标库版本要必须一致，所以对于监管平台8.0.39的Clone记得用同版本的docker镜像。`

`docker run --name mysql-slave --restart unless-stopped -v /home/mysql-slave/conf:/etc/mysql/conf.d -v /home/mysql-slave/data:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=Yst@163.com -d -i -p 3331:3306 mysql:8.0.25`

 
`# 查看日志`

`docker ps | grep mysql-slave`

`docker logs -f --tail=100 mysql-slave`

`tail -fn100 /home/mysql-slave/data/mysql-error.log`

` ` 
`# 确认端口挂载成功`

`netstat -lntp | grep 3331`

`lsof -i :3331`

` ` 
`# 登录mysql实例`

`mysql -uroot -h127.0.0.1 -P3331 -p`

`> 输入刚才设置的root密码`

 
`# 确认server_id是我们刚才设置的server_id`

`mysql> show variables like` `'server_%';`












**实施步骤2**










`# 从库的docker实例运行无问题后，接下来，正式开始通过clone复制主库数据到从库`

 
`-- 在主库上创建克隆专用账号并授权：`

`mysql> CREATE` `USER` 
`'clone_user'@'%'` `IDENTIFIED BY` 
`'Yst@163.com';`

`mysql> GRANT` `BACKUP_ADMIN, CLONE_ADMIN ON` 
`*.* TO` `'clone_user'@'%';`

 
`-- 主从节点都安装Clone插件，注意，主库&从库都要安装这个插件！`

`-- 查看已安装插件，是空的`

`mysql> SELECT` `* FROM` 
`INFORMATION_SCHEMA.`PLUGINS` WHERE` `PLUGIN_NAME = 'clone';`

`-- 安装Clone插件，别担心，重启插件不会丢的。`

`mysql> INSTALL PLUGIN clone SONAME 'mysql_clone.so';`

`-- 安装成功后再查看，多了一个clone插件`

`mysql> SELECT` `* FROM` 
`INFORMATION_SCHEMA.`PLUGINS` WHERE` `PLUGIN_NAME = 'clone';`

 
`-- 从库设置克隆源`

`# 192.168.100.50:3306，主库ip+端口，复制其他主从时记得改！`

`mysql> SET` `GLOBAL` 
`clone_valid_donor_list = '192.168.100.50:3306';`

 
`-- 从库开启压缩功能，提升性能`

`mysql> SET` `GLOBAL` 
`clone_enable_compression = ON;`

`-- 从库增大clone缓冲区，16MB，提升性能`

`mysql> SET` `GLOBAL` 
`clone_buffer_size = 16777216;`

 
`-- 从库启动克隆，这个操作根据主库data文件大小来决定耗时时间，具体时间跟服务器网络带宽、磁盘性能有关。可以监控服务器的内网流量和磁盘性能。`

`-- CLONE命令原理就是先复制物理文件到从库服务器，然后追上事务日志，最后完成事务一致性，整个过程需要一定时间，耐心等待命令执行结果。`

`mysql> CLONE INSTANCE FROM` `'clone_user'@'192.168.100.50':3306 IDENTIFIED BY` 
`'Yst@163.com';`

 
`-- 从库新起一个窗口，查看当前clone进度`

`# 全部STATE=Completed，表示克隆完成`

`SELECT` `* FROM` 
`performance_schema.clone_progress;`

`# STATE=Completed，表示克隆完成`

`SELECT` `* FROM` 
`performance_schema.clone_status;`

 
`-- 日志最后提示：3707 - Restart server failed (mysqld is not managed by supervisor process).，这个是正常的，因为新节点不是用mysql_safe，clone插件想要自动重启失败了，我们手动重启就好了。`

 
`-- 重启从库`

`docker restart mysql-slave`

 
`-- 登录从库，用主库的root密码，因为已经克隆完成了，里面都是主库的数据`

`mysql -uroot -h127.0.0.1 -P3331 -p`

`> 此时是输入主库的root密码`

 
`-- 最终确认克隆情况`

`-- STATE=Completed，表示克隆成功！`

`-- BINLOG_FILE=mysql-binlog.000239，BINLOG_POSITION=91509814，这两个记住，等下主从复制要用到。`

`mysql> SELECT` `STATE, BEGIN_TIME, END_TIME, BINLOG_FILE, BINLOG_POSITION FROM` 
`performance_schema.clone_status;`












**实施步骤3(针对179和180)**










`# 从库克隆成功后，接下来，正式开始搭建主从复制。`

 
`# 以下是179和180从库的主从复制搭建方式！150的由于开启了gtid，以实施步骤4的流程去搭建！`

 
`-- 主库创建复制账号`

`mysql> CREATE` `USER` 
`'repl'@'%'` `IDENTIFIED BY` `'Yst_repl@163.com';`

`mysql> GRANT` `REPLICATION SLAVE ON` 
`*.* TO` `'repl'@'%';`

 
`-- 从库开启复制`

`-- MASTER_HOST，MASTER_PORT，MASTER_USER，MASTER_PASSWORD，主库复制信息`

`-- MASTER_LOG_FILE='mysql-bin.000239', MASTER_LOG_POS=91509814，刚才记住的那两个信息。`

`-- GET_MASTER_PUBLIC_KEY，向主库请求公钥进行身份验证`

`mysql> CHANGE MASTER TO`

`MASTER_HOST='192.168.100.50',`

`MASTER_PORT=3306,`

`MASTER_USER='repl',`

`MASTER_PASSWORD='Yst_repl@163.com',`

`MASTER_LOG_FILE='mysql-bin.000239',`

`MASTER_LOG_POS=91509814,`

`GET_MASTER_PUBLIC_KEY=1;`

 
`-- 从库开启slave`

`mysql> START SLAVE;`

` ` 
`-- 从库查看从库状态，当Slave_IO_Running和Slave_SQL_Running都为yes表示主从复制搭建成功`

`mysql> SHOW SLAVE STATUS\G;`

` ` 
`-- 主库确认从库信息`

`mysql> SHOW SLAVE HOSTS;`












**实施步骤4(针对150)**










`# 从库克隆成功后，接下来，正式开始搭建主从复制。`

 
`# 以下是150从库的主从复制搭建方式。由于150开启了gtid，因此步骤和179及180的有所不同！`

 
`-- 主库创建复制账号`

`mysql> CREATE` `USER` 
`'repl'@'%'` `IDENTIFIED BY` `'Yst_repl@163.com';`

`mysql> GRANT` `REPLICATION SLAVE ON` 
`*.* TO` `'repl'@'%';`

 
`-- 从库开启复制`

`-- MASTER_HOST，MASTER_PORT，MASTER_USER，MASTER_PASSWORD，主库150的复制信息`

`-- MASTER_AUTO_POSITION=1，gtid方式主从，只需要指定这个配置就好了！`

`-- GET_MASTER_PUBLIC_KEY，向主库请求公钥进行身份验证`

`mysql> CHANGE MASTER TO`

`MASTER_HOST='192.168.100.150',`

`MASTER_PORT=3306,`

`MASTER_USER='repl',`

`MASTER_PASSWORD='Yst_repl@163.com',`

`MASTER_AUTO_POSITION=1,`

`GET_MASTER_PUBLIC_KEY=1;`

 
`-- 从库开启slave`

`mysql> START SLAVE;`

` ` 
`-- 从库查看从库状态，当Slave_IO_Running和Slave_SQL_Running都为yes表示主从复制搭建成功`

`mysql> SHOW SLAVE STATUS\G;`

` ` 
`-- 主库确认从库信息`

`mysql> SHOW SLAVE HOSTS;`



















**完结**


至此，基于Clone插件全量备份恢复MySQL8.0数据库完成。

