# 基于Squid代理服务器实现外网代理

> 来源: Trilium Notes 导出 | 路径: root/基于Squid代理服务器实现外网代理




基于Squid代理服务器实现外网代理




## 基于Squid代理服务器实现外网代理


**一、Squid 是什么？**


`Squid`：是一个高性能的代理缓存服务器，Squid 支持 FTP、gopher、HTTPS
和 HTTP协议。和一般的代理缓存软件不同，Squid用一个单独的、非模块化的、I/O驱动的进程来处理所有的客户端请求，作为应用层的代理服务软件，Squid
主要提供缓存加速、应用层过滤控制的功能。

 

**二、为什么要用 Squid？**


Squid是最初的内容分发和缓存工作之后产生的项目之一。它已经成长为包括额外的功能，例如强大的访问控制，授权，日志记录，内容分发/复制，透明代理，流量管理和整形等等。具有许多新旧的解决方法，可以处理不完整和不正确的HTTP实现。

 

**三、安装 Squid**





Centos方式




yum -y install squid







Unbuntu方式




apt -y install squid







krylin方式




yum -y install / dnf -y install




安装后执行 squid -v 如果提示：squid: symbol lookup error: squid: undefined symbol: _ZN7libecap4NameC1ERKNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEEE





尝试升级libecap：yum update -y libecap / dnf update -y libecap









 

**四、基本使用**





查看squid版本














`[root@k8s-node9 ~]# squid -v`

`Squid Cache: Version 4.9`

`Service Name: squid`

 
`This binary uses OpenSSL 1.1.1f  31 Mar 2020. For legal restrictions on distribution see https://www.openssl.org/source/license.html`

 
`configure options:  '--build=x86_64-koji-linux-gnu'` 
`'--host=x86_64-koji-linux-gnu'` `'--program-prefix='` 
`'--prefix=/usr'` `'--exec-prefix=/usr'` 
`'--bindir=/usr/bin'` `'--sbindir=/usr/sbin'` 
`'--sysconfdir=/etc'` `'--datadir=/usr/share'` 
`'--includedir=/usr/include'` `'--libdir=/usr/lib64'` 
`'--libexecdir=/usr/libexec'` `'--sharedstatedir=/var/lib'` 
`'--mandir=/usr/share/man'` `'--infodir=/usr/share/info'` 
`'--exec_prefix=/usr'` `'--libexecdir=/usr/lib64/squid'` 
`'--localstatedir=/var'` `'--datadir=/usr/share/squid'` 
`'--sysconfdir=/etc/squid'` `'--with-logdir=/var/log/squid'` 
`'--with-pidfile=/var/run/squid.pid'` `'--disable-dependency-tracking'` 
`'--enable-eui'` `'--enable-follow-x-forwarded-for'` 
`'--enable-auth'` `'--enable-auth-basic=DB,fake,getpwnam,LDAP,NCSA,PAM,POP3,RADIUS,SASL,SMB,SMB_LM'` 
`'--enable-auth-ntlm=SMB_LM,fake'` `'--enable-auth-digest=file,LDAP'` 
`'--enable-auth-negotiate=kerberos'` `'--enable-external-acl-helpers=LDAP_group,time_quota,session,unix_group,wbinfo_group,kerberos_ldap_group'` 
`'--enable-storeid-rewrite-helpers=file'` `'--enable-cache-digests'` 
`'--enable-cachemgr-hostname=localhost'` `'--enable-delay-pools'` 
`'--enable-epoll'` `'--enable-icap-client'` 
`'--enable-ident-lookups'` `'--enable-linux-netfilter'` 
`'--enable-removal-policies=heap,lru'` `'--enable-snmp'` 
`'--enable-ssl'` `'--enable-ssl-crtd'` 
`'--enable-storeio=aufs,diskd,ufs,rock'` `'--enable-diskio'` 
`'--enable-wccpv2'` `'--disable-esi'` 
`'--enable-ecap'` `'--with-aio'` 
`'--with-default-user=squid'` `'--with-dl'` 
`'--with-openssl'` `'--with-pthreads'` 
`'--disable-arch-native'` `'--with-pic'` 
`'--disable-security-cert-validators'` `'--with-tdb'` 
`'build_alias=x86_64-koji-linux-gnu'` `'host_alias=x86_64-koji-linux-gnu'` 
`'CFLAGS=-O2 -g -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2
-Wp,-D_GLIBCXX_ASSERTIONS -fexceptions -fstack-protector-strong -grecord-gcc-switches
-specs=/usr/lib/rpm/kylin/kylin-hardened-cc1 -m64 -mtune=generic -fasynchronous-unwind-tables
-fstack-clash-protection -fPIC'` `'LDFLAGS=-Wl,-z,relro   -Wl,-z,now -specs=/usr/lib/rpm/kylin/kylin-hardened-ld -pie -Wl,-z,relro -Wl,-z,now -Wl,--warn-shared-textrel'` 
`'CXXFLAGS=-O2 -g -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2
-Wp,-D_GLIBCXX_ASSERTIONS -fexceptions -fstack-protector-strong -grecord-gcc-switches
-specs=/usr/lib/rpm/kylin/kylin-hardened-cc1 -m64 -mtune=generic -fasynchronous-unwind-tables
-fstack-clash-protection -fPIC -std=c++17'` `'PKG_CONFIG_PATH=:/usr/lib64/pkgconfig:/usr/share/pkgconfig'`

















 systemctl命令














`sudo` `systemctl start squid     # 启动Squid`

`sudo` `systemctl enable` 
`squid    # 设置开机自启`

`sudo` `systemctl status squid    # 检查运行状态`


















 

**五、基本配置**





日志文件




/var/log/squid














`[root@localhost squid]# ls -l /var/log/squid/`

`总用量 36`

`-rw-r----- 1 squid squid 12367 9月  11 14:02 access.log  # 请求日志`

`-rw-r----- 1 squid squid 17877 9月  11 16:13 cache.log   # 缓存和错误日志，缓存事件和重载配置等动作会记录到此日志`

















 配置文件




/etc/squid/squid.conf














`[root@localhost squid]# cat /etc/squid/squid.conf`

`#`

`# Recommended minimum configuration:`

`#`

 
`# 允许访问的内网网段`

`acl localnet src 10.194.0.0/16`

`acl localnet src 10.244.0.0/16`

 
`# 允许访问的端口`

`acl SSL_ports port 443`

`acl Safe_ports port 80          # http`

`acl Safe_ports port 443         # https`

`# 有些外网请求是其他端口的，记得在这里放行`

`# acl Safe_ports port 8888         # 其他特殊外网请求端口`

`# 允许CONNECT方法（用于HTTPS）`

`acl CONNECT method CONNECT`

 
`#`

`# Recommended minimum Access Permission configuration:`

`#`

`# Deny requests to certain unsafe ports`

`# 拒绝所有不包含在Safe_ports的端口`

`http_access deny !Safe_ports`

 
`# Deny CONNECT to other than secure SSL ports`

`# 拒绝对非SSL端口使用CONNECT方法`

`http_access deny CONNECT !SSL_ports`

 
`# Only allow cachemgr access from localhost`

`# 允许来自localhost的请求访问缓存管理器`

`http_access allow localhost manager`

`# 拒绝所有其他来源的请求访问缓存管理器`

`http_access deny manager`

 
`# from where browsing should be allowed`

`# 允许自定义的内网网段和localhost访问`

`http_access allow localnet`

`http_access allow localhost`

 
`# And finally deny all other access to this proxy`

`# 最后拒绝所有其他访问`

`http_access deny all`

 
`# Squid normally listens to port 3128`

`# 监听代理端口，默认端口是3128，这里自定义为8080，记得放行防火墙8080端口。`

`http_port 8080`

 
`# Leave coredumps in the first cache dir`

`# 指定Squid进程崩溃时生成核心转储文件（coredump）的存储目录。`

`coredump_dir /var/spool/squid`

 
`#`

`# Add any of your own refresh_pattern entries above these.`

`#`

`# 定义Squid如何根据URL模式决定缓存内容的更新频率，控制缓存过期时间`

`refresh_pattern ^ftp:           1440    20%     10080`

`refresh_pattern -i (/cgi-bin/|\?) 0     0%      0`

`refresh_pattern .               0       20%     4320`

















日志轮转




Squid 默认会处理日志轮转，可以通过如下配置文件修改：/etc/logrotate.d/squid














`[root@localhost squid]# cat /etc/logrotate.d/squid`

`/var/log/squid/*.log {`

`    weekly`

`    rotate 5`

`    compress`

`    notifempty`

`    missingok`

`    nocreate`

`    sharedscripts`

`    postrotate`

`      # Asks squid to reopen its logs. (logfile_rotate 0 is set in squid.conf)`

`      # errors redirected to make it silent if squid is not running`

`      /usr/sbin/squid` 
`-k rotate 2>/dev/null`

`      # Wait a little to allow Squid to catch up before the logs is compressed`

`      sleep` 
`1`

`    endscript`

`}`


















 

**六、匹配规则说明（重要！）**





http_access 规则工作方式：














`在 Squid 中，http_access 规则的工作方式是：`

`1.顺序敏感：从配置文件的第一条 http_access 规则开始检查`

`2.首次匹配：找到第一个匹配的规则后立即执行（允许或拒绝）`

`3.后续忽略：不再检查后面的规则`

`4.默认拒绝：如果没有任何规则匹配，默认拒绝请求`

 
`错误顺序：`

`http_access allow all          # 第一条：允许所有人 → 立即放行！`

`http_access deny !Safe_ports   # 这条永远不会被执行！`

`http_access deny CONNECT !SSL_ports`

 
`正确顺序：`

`http_access deny !Safe_ports        # 先拒绝不安全的`

`http_access deny CONNECT !SSL_ports # 再拒绝不安全的CONNECT`

`http_access allow localnet          # 然后允许内网`

`http_access deny all                # 最后拒绝所有其他`


















 

**七、运维操作**





检查配置文件语法




squid -k parse














`[root@localhost squid]# squid -k parse`

`2025/09/11` `17:10:46| Startup: Initializing Authentication Schemes ...`

`2025/09/11` `17:10:46| Startup: Initialized Authentication Scheme 'basic'`

`2025/09/11` `17:10:46| Startup: Initialized Authentication Scheme 'digest'`

`2025/09/11` `17:10:46| Startup: Initialized Authentication Scheme 'negotiate'`

`2025/09/11` `17:10:46| Startup: Initialized Authentication Scheme 'ntlm'`

`2025/09/11` `17:10:46| Startup: Initialized Authentication.`

`2025/09/11` `17:10:46| Processing Configuration File: /etc/squid/squid.conf (depth 0)`

`2025/09/11` `17:10:46| Processing: acl localnet src 192.168.0.0/16`       
`# RFC1918 possible internal network`

`2025/09/11` `17:10:46| Processing: acl SSL_ports port 443`

`2025/09/11` `17:10:46| Processing: acl Safe_ports port 80         # http`

`2025/09/11` `17:10:46| Processing: acl Safe_ports port 443                # https`

`2025/09/11` `17:10:46| Processing: acl CONNECT method CONNECT`

`2025/09/11` `17:10:46| Processing: http_access deny !Safe_ports`

`2025/09/11` `17:10:46| Processing: http_access deny CONNECT !SSL_ports`

`2025/09/11` `17:10:46| Processing: http_access allow localhost manager`

`2025/09/11` `17:10:46| Processing: http_access deny manager`

`2025/09/11` `17:10:46| Processing: http_access allow localnet`

`2025/09/11` `17:10:46| Processing: http_access allow localhost`

`2025/09/11` `17:10:46| Processing: http_access deny all`

`2025/09/11` `17:10:46| Processing: http_port 8080`

`2025/09/11` `17:10:46| Processing: coredump_dir /var/spool/squid`

`2025/09/11` `17:10:46| Processing: refresh_pattern ^ftp:          1440    20%     10080`

`2025/09/11` `17:10:46| Processing: refresh_pattern -i (/cgi-bin/|\?) 0    0%      0`

`2025/09/11` `17:10:46| Processing: refresh_pattern .              0       20%     4320`

`2025/09/11` `17:10:46| Initializing https proxy context`

 
`可以看到，他会检查/etc/squid/squid.conf配置文件，并且列出他读取的配置规则。`

















重载配置（不中断服务）




方式一：systemctl reload squid














`# 重载前查看squid进程信息`

`[root@localhost squid]# ps -ef|grep squid`

`root      44760      1  0 11:52 ?        00:00:00 /usr/sbin/squid` 
`-f /etc/squid/squid.conf`

`squid     44762  44760  0 11:52 ?        00:00:02 (squid-1) -f /etc/squid/squid.conf`

`squid     45693  44762  0 16:13 ?        00:00:00 (logfile-daemon) /var/log/squid/access.log`

`root      45836   2149  0 17:12 pts/1`   
`00:00:00 grep` `--color=auto squid`

 
`# 执行重载`

`[root@localhost squid]# systemctl reload squid`

 
`# 重载后查看squid进程信息`

`[root@localhost squid]# ps -ef|grep squid`

`root      44760      1  0 11:52 ?        00:00:00 /usr/sbin/squid` 
`-f /etc/squid/squid.conf`

`squid     44762  44760  0 11:52 ?        00:00:02 (squid-1) -f /etc/squid/squid.conf`

`squid     45847  44762  0 17:12 ?        00:00:00 (logfile-daemon) /var/log/squid/access.log`

`root      45849   2149  0 17:12 pts/1`   
`00:00:00 grep` `--color=auto squid`

 
`可以看到，reload后进程ID会变更。`














方式二：squid -k reconfigure














`[root@localhost ~]# squid -k reconfigure`

`[root@localhost ~]# tail -fn30 /var/log/squid/cache.log`

`2025/09/11` `17:13:38 kid1| Adding domain localdomain from /etc/resolv.conf`

`2025/09/11` `17:13:38 kid1| Adding nameserver 192.168.205.2 from /etc/resolv.conf`

`2025/09/11` `17:13:38 kid1| HTCP Disabled.`

`2025/09/11` `17:13:38 kid1| Finished loading MIME types and icons.`

`2025/09/11` `17:13:38 kid1| Accepting HTTP Socket connections at local=[::]:8080 remote=[::] FD 11 flags=9`

`2025/09/11` `17:14:11| Set Current Directory to /var/spool/squid`

`2025/09/11` `17:14:11 kid1| Reconfiguring Squid Cache (version 3.5.20)...`

`2025/09/11` `17:14:11 kid1| Closing HTTP port [::]:8080`

`2025/09/11` `17:14:11 kid1| Logfile: closing log daemon:/var/log/squid/access.log`

`2025/09/11` `17:14:11 kid1| Logfile Daemon: closing log daemon:/var/log/squid/access.log`

`2025/09/11` `17:14:11 kid1| Startup: Initializing Authentication Schemes ...`

`2025/09/11` `17:14:11 kid1| Startup: Initialized Authentication Scheme 'basic'`

`2025/09/11` `17:14:11 kid1| Startup: Initialized Authentication Scheme 'digest'`

`2025/09/11` `17:14:11 kid1| Startup: Initialized Authentication Scheme 'negotiate'`

`2025/09/11` `17:14:11 kid1| Startup: Initialized Authentication Scheme 'ntlm'`

`2025/09/11` `17:14:11 kid1| Startup: Initialized Authentication.`

`2025/09/11` `17:14:11 kid1| Processing Configuration File: /etc/squid/squid.conf (depth 0)`

`2025/09/11` `17:14:11 kid1| Initializing https proxy context`

`2025/09/11` `17:14:11 kid1| Logfile: opening log daemon:/var/log/squid/access.log`

`2025/09/11` `17:14:11 kid1| Logfile Daemon: opening log /var/log/squid/access.log`

`2025/09/11` `17:14:11 kid1| Squid plugin modules loaded: 0`

`2025/09/11` `17:14:11 kid1| Adaptation support is off.`

`2025/09/11` `17:14:11 kid1| Store logging disabled`

`2025/09/11` `17:14:11 kid1| DNS Socket created at [::], FD 9`

`2025/09/11` `17:14:11 kid1| DNS Socket created at 0.0.0.0, FD 10`

`2025/09/11` `17:14:11 kid1| Adding domain localdomain from /etc/resolv.conf`

`2025/09/11` `17:14:11 kid1| Adding nameserver 192.168.205.2 from /etc/resolv.conf`

`2025/09/11` `17:14:11 kid1| HTCP Disabled.`

`2025/09/11` `17:14:11 kid1| Finished loading MIME types and icons.`

`2025/09/11` `17:14:11 kid1| Accepting HTTP Socket connections at local=[::]:8080 remote=[::] FD 11 flags=9`

 
`从日志可以看到，squid重新读取了配置文件，重新监听了8080端口。`


















 

**八、Java网络代理配置**





> 说明：这里以政务网10.194.172.102作为代理服务器安装squid，并监听8080代理端口，以政务网10.194.172.103作为业务服务器，部署springboot服务。演示业务服务器通过代理服务器的8080端口转发外网请求。





 JVM启动参数指定网络代理














`# http.proxyHost、http.proxyPort，代理http请求转发到10.194.172.102:8080代理服务器；`

`# https.proxyHost、https.proxyPort，代理https请求转发到10.194.172.102:8080代理服务器；`

`# http.nonProxyHosts='10.*|192.*|localhost|'，忽略10.*、192.*、localhost请求不转发到代理服务器。`

`# 2025-09-16代理政邮通zyt-payment服务新增总结：注意，如果部署jvm所在的节点有多个内网ip，那么要把这几个内网ip都加入到nonProxyHosts中。在政邮通的nacos配置的是19开头的政务内网ip，但是payment只过滤了10和192开头的网段，导致payment请求xxljob也经过了162转发。同理，xxljob调度注册的执行器时，也是走政务内网ip，由于xxljob不需要外网访问，解决方案是xxljob不需要指定代理转发。`

`# 注意，java后面写-D参数配置，不要在-jar之后去写-D参数配置。`

`java -Dhttp.proxyHost=10.194.172.102` 
`-Dhttp.proxyPort=8080` `-Dhttps.proxyHost=10.194.172.102` 
`-Dhttps.proxyPort=8080` `-Dhttp.nonProxyHosts='10.*|192.*|localhost|'` 
`-Dfile.encodingutf8 -Djava.security.egd file:/dev/./urandom -Ddruid.mysql.usepingMethod
false` `${STANDAR PARANS} -jar jarName.jar ${NON_STANDAR_PARAMS}`

















启动项目，进入JVM容器，验证配置是否生效














`# jps获取当前jvm进程号`

`root@gzzyt-resource-79d4966455-bmrn4:/# jps -ml`

`8 gzzyt-resource.jar --server.port=8080 --spring.profiles.active=prod`

`155 sun.tools.jps.Jps -ml`

 
`# jinfo -flags ${进程号}，查看jvm启动参数`

`root@gzzyt-resource-79d4966455-bmrn4:/# jinfo -flags 8`

`Attaching to process ID 8, please wait...`

`Debugger attached successfully.`

`Server compiler detected.`

`JVM version is 25.342-b07`

`Non-default VM flags: -XX:CICompilerCount=2 -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=null -XX:InitialHeapSize=1073741824 -XX:MaxHeapSize=1073741824 -XX:MaxNewSize=357892096 -XX:MinHeapDeltaBytes=196608 -XX:NewSize=357892096 -XX:OldSize=715849728 -XX:+PrintGC -XX:+PrintGCDateStamps -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+UseCompressedClassPointers -XX:+UseCompressedOops`

`Command line:  -Dhttp.proxyHost=10.194.172.102 -Dhttp.proxyPort=8080 -Dhttps.proxyHost=10.194.172.102 -Dhttps.proxyPort=8080 -Dhttp.nonProxyHosts=10.*|192.* -Dfile.encoding=utf8 -Djava.security.egd=file:/dev/./urandom` 
`-Ddruid.mysql.usePingMethod=false` `-Xms1024m -Xmx1024m -XX:+PrintGCDateStamps -XX:+PrintGCDetails -Xloggc:/home/data/tmp/gc-%t.log -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/home/data/tmp/dump_gzzyt-resource_55.hprof`

 
`可以看到，jvm成功开启了网络代理`

















验证squid是否能够正常网络转发




验证方式一：Java业务逻辑调用外网接口，在102代理服务器开启tcpdump，确认网络流量进入102并成功转发














`# 102代理服务器开启tcpdump实时监听8080端口流量`

`[root@k8s-node9 ~]# tcpdump -i any -n 'port 8080'`

`dropped privs to tcpdump`

`tcpdump: verbose output suppressed, use -v` 
`or -vv for` `full protocol decode`

`listening on any, link-type` `LINUX_SLL (Linux cooked v1), capture size 262144 bytes`

`17:41:53.845004 IP 10.194.172.103.24851 > 10.194.172.102.tproxy: Flags [S], seq` 
`942460404, win 64800, options [mss 1440,sackOK,TS val 3431990935 ecr 0,nop,wscale
7], length 0`

`17:41:53.845174 IP 10.194.172.102.tproxy > 10.194.172.103.24851: Flags [S.], seq` 
`552056007, ack 942460405, win 64240, options [mss 1460,nop,nop,sackOK,nop,wscale
7], length 0`

`17:41:53.845563 IP 10.194.172.103.24851 > 10.194.172.102.tproxy: Flags [.], ack 1, win 507, length 0`

`17:41:53.845923 IP 10.194.172.103.24851 > 10.194.172.102.tproxy: Flags [P.], seq` 
`1:190, ack 1, win 507, length 189`

`17:41:53.845971 IP 10.194.172.102.tproxy > 10.194.172.103.24851: Flags [.], ack 190, win 501, length 0`

`17:41:53.878412 IP 10.194.172.102.tproxy > 10.194.172.103.24851: Flags [P.], seq` 
`1:40, ack 190, win 501, length 39`

`17:41:53.878691 IP 10.194.172.103.24851 > 10.194.172.102.tproxy: Flags [.], ack 40, win 507, length 0`

`17:41:53.890992 IP 10.194.172.103.24851 > 10.194.172.102.tproxy: Flags [P.], seq` 
`190:480, ack 40, win 507, length 290`

`17:41:53.906668 IP 10.194.172.102.tproxy > 10.194.172.103.24851: Flags [P.], seq` 
`40:1464, ack 480, win 501, length 1424`

`17:41:53.906780 IP 10.194.172.102.tproxy > 10.194.172.103.24851: Flags [P.], seq` 
`1464:3240, ack 480, win 501, length 1776`

`17:41:53.908029 IP 10.194.172.103.24851 > 10.194.172.102.tproxy: Flags [.], ack 3240, win 489, length 0`

`17:41:53.921033 IP 10.194.172.103.24851 > 10.194.172.102.tproxy: Flags [P.], seq` 
`480:555, ack 3240, win 501, length 75`

`17:41:53.925176 IP 10.194.172.103.24851 > 10.194.172.102.tproxy: Flags [P.], seq` 
`555:561, ack 3240, win 501, length 6`

`17:41:53.925398 IP 10.194.172.102.tproxy > 10.194.172.103.24851: Flags [.], ack 561, win 501, length 0`

`17:41:53.925634 IP 10.194.172.103.24851 > 10.194.172.102.tproxy: Flags [P.], seq` 
`561:606, ack 3240, win 501, length 45`

`17:41:53.930179 IP 10.194.172.102.tproxy > 10.194.172.103.24851: Flags [P.], seq` 
`3240:3291, ack 606, win 501, length 51`

`17:41:53.934307 IP 10.194.172.103.24851 > 10.194.172.102.tproxy: Flags [P.], seq` 
`606:994, ack 3291, win 501, length 388`

`17:41:53.941037 IP 10.194.172.102.tproxy > 10.194.172.103.24851: Flags [P.], seq` 
`3291:3534, ack 994, win 501, length 243`

`17:41:53.982691 IP 10.194.172.103.24851 > 10.194.172.102.tproxy: Flags [.], ack 3534, win 501, length 0`

`17:41:54.344344 IP 10.194.172.103.24851 > 10.194.172.102.tproxy: Flags [P.], seq` 
`994:1382, ack 3534, win 501, length 388`

`17:41:54.349960 IP 10.194.172.102.tproxy > 10.194.172.103.24851: Flags [P.], seq` 
`3534:3777, ack 1382, win 501, length 243`

`17:41:54.350239 IP 10.194.172.103.24851 > 10.194.172.102.tproxy: Flags [.], ack 3777, win 501, length 0`

 
`可以看到，102成功完成TCP三次握手和双向数据传输`

















验证方式二：在10.194.172.103业务服务器发起curl调用，在102代理服务器查看squid请求日志，确认网络流量进入102并成功转发














`# 103业务服务器发起curl请求`

`[root@k8s-node8 ~]# curl -v --proxy `
[`http://10.194.172.102:8080`
](http://10.194.172.102:8080/)` `[`https://ocr.tencentcloudapi.com/`](https://ocr.tencentcloudapi.com/)

`*   Trying 10.194.172.102:8080...`

`* Connected to 10.194.172.102 (10.194.172.102) port 8080 (#0)`

`* allocate connect buffer!`

`* Establish HTTP proxy tunnel to ocr.tencentcloudapi.com:443`

`> CONNECT ocr.tencentcloudapi.com:443 HTTP/1.1`

`> Host: ocr.tencentcloudapi.com:443`

`> User-Agent: curl/7.71.1`

`> Proxy-Connection: Keep-Alive`

`>`

` GET / HTTP/1.1`

`> Host: ocr.tencentcloudapi.com`

`> User-Agent: curl/7.71.1`

`> Accept: */*`

`>`

`* Mark bundle as not supporting multiuse`

`< HTTP/1.1 200 OK`

`< Date: Thu, 11 Sep 2025 09:48:34 GMT`

`< Content-Type: application/json`

`< Content-Length: 170`

`< Connection: keep-alive`

`<`

`* Connection #0 to host 10.194.172.102 left intact`

`{"Response":{"Error":{"Code":"MissingParameter","Message":"The request is missing a required parameter `Timestamp`."},"RequestId":"9f124037-49ed-4fa9-94e5-5bd3095f817d"}}`

` ` 
`# 102代理服务器监听squid请求日志`

`[root@k8s-node9 squid]# tail -fn1 /var/log/squid/access.log`

`1757583967.329     89 10.194.172.103 TCP_TUNNEL/200` 
`8617 CONNECT ocr.tencentcloudapi.com:443 - HIER_DIRECT/106.53.137.165
-`

 
`可以看到，102成功完成代理并响应结果到103.`

