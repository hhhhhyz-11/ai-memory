# 基于xtrabackup全量备份恢复MySQL5.7数据库

> 来源: Trilium Notes 导出 | 路径: root/数据备份/基于xtrabackup全量备份恢复MySQL5.7数据库


基于xtrabackup全量备份恢复MySQL5.7数据库




## 基于xtrabackup全量备份恢复MySQL5.7数据库






**背景**



当前佛山政务网的核心数据库均采用MySQL单实例部署，该架构存在两大核心隐患：其一，系统存在单点故障，任一节点的失效都将引发服务中断，业务连续性面临严峻挑战。因此，迫切需要对MySQL搭建主从集群架构。根据会议沟通，得出方案提出的环形复制 + docker方式独立部署架构，为每一台MySQL实例配置一个独立从库实例。











**情况说明**



目前，

19.129.13.159/192.168.100.250和218.13.168.162/192.168.100.125，为ubuntu系统，搭建的都是5.7.42-0ubuntu0.18.04.1版本数据库，其余centos服务器搭建的为MySQL8.0以上版本。



说明，其余三台是MySQL8.0版本数据库，可以通过Clone插件快速实现备份恢复方式，无需xtrabackup。








**实施前必备条件**



1、所有服务器安装docker服务

2、所有服务器准备好MySQL:5.7.42镜像

3、安装xtrabackup2.4版本，可去官方网站：[https://www.percona.com/downloads](https://www.percona.com/downloads)，下载deb文件本地安装

4、qpress，2.4版本xtrabackup默认且仅能使用qpress作为压缩解压工具，因此需要安装qpress依赖，这里有坑，qpress官网没找到对应的deb安装包，这里用了另外一个方案，可以去其他Ubuntu系统中已经安装的/usr/bin/qpress可执行文件下载上传到本地服务器也可以。

5、源、目标服务器磁盘空间需足够

6、建议停服执行，虽然xtrabackup支持热备，但是降低风险等级建议减少数据库并发读写操作

7、注意端口放行，注意防火墙规则，注意防火墙规则不要影响现有生产系统，慎重操作










**重要说明！**



**下面给出了2份从库的my.cnf，备份恢复相应从库时，就用对应的my.cnf即可，不要做改动！**




** **









**159从库my.cnf配置文件内容**










`[mysqld]`

`# GENERAL`

`user=mysql`

`port=3306`

`# INNODB`

`# 缓冲池大小`

`innodb_buffer_pool_size=1G`

`# redo文件大小`

`innodb_log_file_size=48M`

`innodb_file_per_table=1`

`# 错误日志，默认在/var/lib/mysql/mysql-error.log`

`log-error=mysql-error.log`

`# 字符编码`

`character-set-server=latin1`

`collation-server=latin1_swedish_ci`

`# 其他配置`

`key_buffer_size=16M`

`max_allowed_packet=16M`

`thread_stack=192K`

`thread_cache_size=8`

`myisam-recover-options=BACKUP`

`max_connections=500`

`# 创建新表时将使用的默认存储引擎`

`default-storage-engine=INNODB`

`# 开启binlog`

`log-bin=mysql-bin`

`# 设置binlog模式`

`binlog_format=ROW`

`# 更新记录的binlog事件日志前后镜像记录了所有字段值，默认值FULL`

`binlog_row_image=FULL`

`# 设置binlog保留日志时间90天`

`expire_logs_days=90`

`# 设置binlog日志文件大小`

`max_binlog_size=100m`

`# 设置server_id，主从要求不一样！`

`server_id=2`

`# 设置日志时间为系统时间`

`log_timestamps=UTC`

`# sql_mode配置`

`sql_mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION`

`[client]`











 






**162从库my.cnf配置文件内容**










`[mysqld]`

`# GENERAL`

`user=mysql`

`port=3306`

`# INNODB`

`# 缓冲池大小，fsddc居然用默认128M稳定运行`

`innodb_buffer_pool_size=1G`

`# redo文件大小`

`innodb_log_file_size=48M`

`innodb_file_per_table=1`

`# 错误日志，默认在/var/lib/mysql/mysql-error.log`

`log-error=mysql-error.log`

`# 字符编码`

`character-set-server=utf8mb4`

`collation-server=utf8mb4_general_ci`

`# 其他配置`

`key_buffer_size=32M`

`max_allowed_packet=32M`

`thread_stack=320K`

`thread_cache_size=16`

`myisam-recover-options=BACKUP`

`max_connections=4000`

`# 禁用外部锁定机制`

`skip-external-locking`

`query_cache_limit=1M`

`query_cache_size=16M`

`# 创建新表时将使用的默认存储引擎`

`default-storage-engine=INNODB`

`# 默认使用mysql_native_password插件认证`

`default_authentication_plugin=mysql_native_password`

`# 最大允许访问包，我去，100M`

`max_allowed_packet=104857600`

`# 开启binlog`

`log-bin=mysql-bin`

`# 设置binlog模式`

`binlog_format=ROW`

`# 更新记录的binlog事件日志前后镜像记录了所有字段值，默认值FULL`

`binlog_row_image=FULL`

`# 设置binlog保留日志时间90天`

`expire_logs_days=90`

`# 设置binlog日志文件大小`

`max_binlog_size=100m`

`# 设置缓存`

`binlog_cache_size=4m`

`# 关闭大小写敏感`

`lower_case_table_names=1`

`# 设置server_id，主从要求不一样！`

`server_id=2`

`# 设置日志时间为系统时间`

`log_timestamps=UTC`

`# sql_mode配置`

`sql_mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION`

`[client]`











 








**说明：本次实施步骤以192.168.100.250服务器的MySQL5.7.42作为主库，全量备份复制到192.168.100.125服务器，并且在125服务器执行恢复拉起docker方式的MySQL从库实例，最后搭建主从复制架构。**


**简写说明：**


**主节点：指的就是159服务器**


**从节点：指的就是162服务器**




**实施步骤1**










`# 主节点创建备份用户`

`mysql> CREATE` `USER` 
`'bkpuser'@'%'` `IDENTIFIED BY` 
`'Yunst_back@163.com';`

`# 主节点授权备份用户`

`mysql> GRANT` `RELOAD, LOCK TABLES, PROCESS, REPLICATION CLIENT ON` 
`*.* TO` `'bkpuser'@'%';`

 
`# 主节点创建备份目录`

`mkdir -p /home2/xtrabackup/backups`

 
`# 从节点创建接收备份文件的目录，注意这里是在162从库服务器去创建哈！为什么选择在/mnt目录呢？因为162的4.5T磁盘是挂载在/根目录，而/home目录单独做了一个分区只有344G.`

`mkdir -p /mnt/xtrabackup/backups/full`

 
`# 备份命令参数介绍`

`# --defaults-file=/etc/mysql/mysql.conf.d/mysqld.cnf：主节点中MySQL主库的主配置文件，这里很坑，原始的MySQL实例不知道是谁搭建的，用了好多个配置文件组成的MySQL实例，非常难以管理和排查问题。`

`# --backup：全量备份的意思`

`# --parallel=5：并发压缩线程`

`# --datadir=/var/lib/mysql：主节点中MySQL主库的data目录`

`# --socket=/var/run/mysqld/mysqld.sock：主节点中MySQL主库的socket文件，用socket方式连接效率更高`

`# --user=bkpuser --password=Yunst_back@163.com：刚才创建的备份用户和密码`

`# --compress --compress-threads=8 --stream=xbstream：流式压缩备份`

`# 2>/home2/xtrabackup/backups/01_backup_full.log：输出日志`

`# | ssh -p 2222 root@192.168.100.125 "xbstream -x --parallel=5 -C /mnt/xtrabackup/backups/full"：将stream压缩文件传递到从节点的/mnt/xtrabackup/backups/full目录并执行解压，注意放行从节点的2222端口给主节点`

 
`# 在主节点执行备份命令，并将备份文件传输到远程从节点指定的目录并且提取流文件！`

`cd /home2/xtrabackup/backups`

`xtrabackup --defaults-file=/etc/mysql/mysql.conf.d/mysqld.cnf --backup --parallel=5 \`

`--datadir=/var/lib/mysql --socket=/var/run/mysqld/mysqld.sock --user=bkpuser --password=Yunst_back@163.com \`

`--compress --compress-threads=8 --stream=xbstream \`

`2>/home2/xtrabackup/backups/01_backup_full.log \`

`| ssh -p 2222 root@192.168.100.125 "xbstream -x --parallel=5 -C /mnt/xtrabackup/backups/full"`

 
`# 主节点查看备份情况，输出completed OK! 表示备份成功。`

`cat /home2/xtrabackup/backups/01_backup_full.log`












**实施步骤2**










`# 从节点切换到备份目录`

`cd /mnt/xtrabackup/backups`

 
`# 从节点解压备份目录里面的qp压缩文件`

`# --decompress：解压文件`

`# --parallel=5：表示并行度`

`# --target-dir：备份目录`

`xtrabackup --decompress --parallel=5 --target-dir=/mnt/xtrabackup/backups/full`

 
`# 查看解压情况`

`ls -l /mnt/xtrabackup/backups/full`

 
`# 解压完成，从节点删除qp压缩文件`

`find /mnt/xtrabackup/backups/full` 
`-name` `"*.qp"` `-delete`

 
`# 从节点执行准备阶段命令`

`cd /mnt/xtrabackup/backups`

`# --prepare：准备阶段，应用 redo log，回滚未提交事务`

`# --use-memory=1G：给1G内存去执行 Crash，需要注意服务器内存资源是否足够`

`xtrabackup --prepare --use-memory=1G --target-dir=/mnt/xtrabackup/backups/full > 02_prepare_full.log 2>&1`

 
`# 查看日志，最后输出completed OK! 表示准备成功。`

`cat /mnt/xtrabackup/backups/02_prepare_full.log`

 
`# 从节点创建挂载docker容器的MySQL的data目录。注意，这里的/mnt/mysql/data目录就是从节点到时用docker恢复MySQL容器时挂载的MySQL的data目录，需按服务器实际情况创建，比如后面要备份恢复到159服务器时，可以考虑放在/home2或/home3目录等磁盘空间较多的目录`

`mkdir -p /mnt/mysql/data`

 
`# 从节点执行恢复阶段命令`

`# --copy-back：恢复阶段，还原target-dir目录文件到datadir目录，说明，copy-back方式时会保留target-dir备份目录和文件，如果磁盘空间不够，可以选择move-back表示移动备份文件`

`# --parallel=5：并发线程`

`# --target-dir=/mnt/xtrabackup/backups/full：备份文件目录`

`# --datadir=/mnt/mysql/data：把备份目录文件恢复到具体的数据目录`

`xtrabackup --copy-back --parallel=5 --target-dir=/mnt/xtrabackup/backups/full --datadir=/mnt/mysql/data > 03_copy_back_full.log 2>&1`

 
`# 查看日志，最后输出completed OK! 表示恢复成功。`

`cat /mnt/xtrabackup/backups/03_copy_back_full.log`












**实施步骤3**










`# 从节点创建MySQL conf目录`

`mkdir -p /mnt/mysql/conf`

 
`# 从节点创建docker容器挂载MySQL配置文件`

`vi /mnt/mysql/conf/my.cnf`

 
`# 粘贴上面的[159从库my.cnf配置文件内容]即可！`

`# > 备份恢复162从库时，就用[162从库my.cnf配置文件内容]！`












**实施步骤4**










`# 从节点启动docker容器，挂载配置、数据目录启动容器，端口自定义，这里是定义的是3331挂载端口`

`docker run --name mysql-slave --restart unless-stopped -v /mnt/mysql/conf:/etc/mysql/conf.d -v /mnt/mysql/data:/var/lib/mysql -d -i -p 3331:3306 mysql:5.7.42`

 
`# 查看日志`

`docker ps | grep mysql`

`docker logs -f --tail=100 mysql-slave`

`tail -fn100 /mnt/mysql/data/mysql-error.log`

 
`# 确认端口挂载成功`

`netstat -lntp | grep 3331`

`lsof -i :3331`

 
`# 登录mysql实例`

`mysql -uroot -h127.0.0.1 -P3331 -p`

`> 使用源库的root用户密码登录`

`> 查看数据是否成功恢复`












**实施步骤5**










`# 在主节点创建主从复制用户`

`mysql> CREATE` `USER` 
`'mysql_slave'@'%'` `IDENTIFIED WITH` 
`mysql_native_password BY` `'Yst@163.com';`

 
`# 在主节点授予复制用户权限`

`mysql> GRANT` `REPLICATION SLAVE ON` 
`*.* TO` `'mysql_slave'@'%';`

 
`# 在从节点查看主库binlog的位点信息`

`cat /mnt/xtrabackup/backups/full/xtrabackup_binlog_info`

`# 输出类似以下格式：`

`mysql-bin.000009        154`

 
`# 在从节点新从库配置主从关系`

`-- MASTER_HOST='192.168.100.250', MASTER_PORT=3306：主节点ip和端口，记得放行端口`

`-- MASTER_USER='mysql_slave',MASTER_PASSWORD='Yst@163.com'：主节点刚才创建的复制用户`

`-- MASTER_LOG_FILE='mysql-bin.000004',MASTER_LOG_POS=154：刚才查看的主节点binlog位点信息`

`mysql> CHANGE MASTER TO` `MASTER_HOST='192.168.100.250', MASTER_PORT=3306,`

`MASTER_USER='mysql_slave',MASTER_PASSWORD='Yst@163.com',`

`MASTER_LOG_FILE='mysql-bin.000009',MASTER_LOG_POS=154;`

 
`# 在从节点开启slave`

`mysql> START SLAVE;`

 
`# 在从节点查看从库状态，当Slave_IO_Running和Slave_SQL_Running都为yes表示主从复制搭建成功`

`mysql> SHOW SLAVE STATUS\G;`

 
`# 在主节点确认从库信息`

`mysql> SHOW SLAVE HOSTS;`


















**完结**



至此，基于xtrabackup全量备份恢复MySQL5.7数据库完成。

