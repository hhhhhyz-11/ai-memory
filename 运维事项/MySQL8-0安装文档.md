# MySQL8.0安装文档

> 来源: Trilium Notes 导出 | 路径: root/部署文档/MySQL8.0安装文档




MySQL8.0安装文档




## MySQL8.0安装文档


**官网下载地址：**

[https://downloads.mysql.com/archives/community/](https://downloads.mysql.com/archives/community/)



**安装步骤**


访问官网下载地址，下载RPM Bundle离线安装包。**说明：先通过：rpm --eval '%{rhel}' 命令，查看服务器是el7还是el8系统，再来确定OS Version是选择Red Hat Enterprise Linux 8 / Oracle Linux 7 (x86, 64-bit)还是Red Hat Enterprise Linux 8 / Oracle Linux 8 (x86, 64-bit)**


















安装前，检查依赖，如果没有就用 yum install 安装













`rpm -qa|grep` `libaio`

`rpm -qa|grep` `net-tools`

`rpm -qa|grep` `numactl`

`rpm -qa|grep` `perl`

`# 安装前，需要删除mysql-libs旧的依赖`

`yum remove mysql-libs`
















创建文件夹













`mkdir` `-p /home/mysql`

`mkdir` `-p /home/mysql/rpm`

`mkdir` `-p /home/mysql/logs`

`mkdir` `-p /home/mysql/binlog`

`# 上传mysql-community-server-8.0.39-1.el7.x86_64.rpm等安装rpm文件到/home/mysql/rpm目录`
















安装mysql(必须按照顺序执行!)













`cd` `/home/mysql/rpm`

 
`# 删除系统默认安装的mariadb模块`

`# 查询已安装的mariadb依赖，如果有安装，要执行下面的命令移除mariadb依赖`

`rpm -qa | grep` `mariadb`

`# 由于mariadb和MySQL不兼容，所以要移除mariadb依赖`

`rpm -e --nodeps mariadb`

`rpm -e --nodeps mariadb-server`

`rpm -e --nodeps mariadb-libs`

`rpm -e --nodeps mariadb-common`

`rpm -e --nodeps mariadb...其他依赖`

 
`# 执行如下安装步骤，按顺序执行！！安装过程如果报错缺少依赖，则按要求用yum方式安装依赖即可。`

`rpm -ivh mysql-community-common-8.0.39-1.el7.x86_64.rpm`

`rpm -ivh mysql-community-client-plugins-8.0.39-1.el7.x86_64.rpm`

`rpm -ivh mysql-community-libs-8.0.39-1.el7.x86_64.rpm`

`rpm -ivh mysql-community-client-8.0.39-1.el7.x86_64.rpm`

`rpm -ivh mysql-community-icu-data-files-8.0.39-1.el7.x86_64.rpm`

`rpm -ivh mysql-community-server-8.0.39-1.el7.x86_64.rpm`

`rpm -ivh mysql-community-libs-compat-8.0.39-1.el7.x86_64.rpm`

 
`# 添加用户和组并分配权限`

`groupadd mysql`

`useradd` `-r -g mysql mysql`

`chown` `mysql:mysql -R /home/mysql`
















修改配置文件/etc/my.cnf，指定最小化配置（非常关键！！）













`vi` `/etc/my.cnf`

`# 替换my.cnf为如下配置：`

 
`[mysqld]`

`# GENERAL`

`datadir=/home/mysql/data`

`socket=/home/mysql/mysql.sock`

`pid-file=/home/mysql/mysql.pid`

`user=mysql`

`port=3306`

`# INNODB`

`# 缓冲池大小，默认是128M`

`innodb_buffer_pool_size=1024M`

`# redo文件大小`

`innodb_redo_log_capacity=512MB`

`# 刷盘方式`

`innodb_flush_method=o_direct`

`# 错误日志`

`log-error=/home/mysql/logs/mysql-error.log`

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

`sort_buffer_size=4M`

`# 连表查询缓冲区`

`join_buffer_size=8M`

`# 创建新表时将使用的默认存储引擎`

`default-storage-engine=INNODB`

`# 关闭大小写敏感`

`lower_case_table_names=1`

`# 开启binlog日志,指定binlog日志存放目录（此目录要求也是属于mysql用户和组才行），设置binlog日志文件以mysql-binlog开头,并且指定binlog日志存储位置,binlog日志不要和mysql数据放在同一个目录！`

`log_bin=/home/mysql/binlog/mysql-binlog`

`# 启用binlog转储`

`log_slave_updates=1`

`# relaylog命名`

`relay-log=relay-log`

`# 开启GTID`

`gtid_mode=on`

`enforce-gtid-consistency=1`

`# 设置日志格式，默认值ROW`

`# binlog_format=ROW`

`# 更新记录的binlog事件日志前后镜像记录了所有字段值，默认值FULL`

`binlog_row_image=FULL`

`# 设置binlog保留日志时间90天`

`binlog_expire_logs_seconds=7776000`

`# 设置binlog日志文件大小`

`max_binlog_size=100m`

`# 设置缓存，默认32KB`

`binlog_cache_size=4m`

`# 设置日志时间为系统时间`

`log_timestamps=SYSTEM`

`# 设置不需要复制的数据库`

`# binlog-ignore-db=mysql`

`# binlog-ignore-db=infomation_schema`

`# binlog-ignore-db=performance_schema`

`# 唯一服务id,用来和其他主从mysql服务器区分名称`

`server_id=1`

`# sql_mode配置`

`sql_mode=STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION`

`[client]`

`socket=/home/mysql/mysql.sock`

`port=3306`
















初始化mysql

 













`# 先查看MySQL版本`

`mysql --version`

 
`# 为了保证数据库目录与文件的所有者为 mysql 登录用户，如果你是以root身份运行mysql服务，需要执行下面的命令初始化(我们确实是root用户登录的linux服务器，所以需要执行以下命令):`

`mysqld --defaults-file=/etc/my.cnf --datadir=/home/mysql/data/` 
`--user=mysql --initialize`

`# 说明: -initialize 选项默认以“安全”模式来初始化，则会为 root 用户生成一个密码并将 该密码标记为过期，登录后你需要设置个新的密码。生成的 临时密码 会往日志中记录一份`

 
`# 查看密码：`

`cat` `/home/mysql/logs/mysql-error.log | grep` 
`password`

 
`# 启动MySQL，查看状态`

`systemctl start mysqld`

`systemctl status mysqld`

`# 如果状态不是running，尝试重启mysql服务`

`systemctl restart mysqld`

 
`# 启动如果报错：mysqld: File '/home/mysql/binlog/mysql-binlog.index' not found (OS errno 13 - Permission denied)`

`是因为服务器开启了selinux，临时关闭：setenforce 0，永久关闭则是修改/etc/selinux/config文件中设置SELINUX=disabled并重启服务器。`

 
`#  查看MySQL服务是否自启动（默认是enabled）`

`systemctl list-unit-files | grep` 
`mysqld.service`
















修改mysql密码和设置远程登录













`# 因为初始化密码默认是过期的，所以查看数据库会报错。因此需要修改密码:`

`mysql -uroot -p`

`# 输入临时密码`

`# 修改密码`

`ALTER USER 'root'@'localhost'` `IDENTIFIED WITH mysql_native_password BY 'Yst@163.com';`

 
`# 修改访问权限，只允许172.16网段开头的ip访问数据库`

`RENAME USER 'root'@'localhost'` `TO 'root'@'172.16.%';`

`-- Host修改完成后记得执行flush privileges使配置立即生效!`

`flush privileges;`

`exit;`

 
`# 测试本地连接，指定mysql ip连接，因为上面已经修改了host，不指定默认使用localhost连接会报错：ERROR 1045 (28000): Access denied for user 'root'@'localhost' (using password: YES)`

`mysql -uroot -h 172.16.0.14 -p`

`# 输入新密码`

 
`# 使用navicat连接，成功则表示MySQL安装成功！`

