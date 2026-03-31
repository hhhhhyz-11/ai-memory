# nginx部署文档

> 来源: Trilium Notes 导出 | 路径: root/部署文档/nginx部署文档


nginx部署文档




## nginx部署文档


nginx官网下载地址：[https://nginx.org/en/download.html](https://nginx.org/en/download.html)


## 一 .介绍：

1.nginx功能强大，可以应用很多地方，如web部署，负载均衡，网关入口。

## 二.部署nginx

1.将从官网下载的安装包上传至服务器。




2.安装源码编译工具：











`yum  -y   install  gcc make libpcre3 libpcre3-dev wget openssl libssl-dev net-tools pcre-devel zlib-devel openssl-devel     #源码安装主要需要安装gcc和make，其他工具都是网络工具`











3.解压以及部署











`tar  -xf   nginx-1.28.0.tar.gz`

`cd   nginx-1.28.0/`

`./configure  --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib64/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/mnt/data/gzddc/nginx/logs/error.log --http-log-path=/mnt/data/gzddc/logs/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --add-module=/etc/nginx/headers-more-nginx-module --user=nginx --group=nginx --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --with-cc-opt='-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -m64 -mtune=generic -fPIC'` 
`--with-ld-opt='-Wl,-z,relro -Wl,-z,now -pie'`

 
`#里面指定了一些东西在make   install安装之前需要创建目录`

`mkdir  -p  /mnt/data/gzddc/nginx/logs/                #日志存放路径（可以自定义路径）`

`mkdir  -p  /mnt/data/gzddc/logs/`

`mkdir  -p  /var/cache/nginx/client_temp`

`mkdir  -p  /etc/nginx/headers-more-nginx-module       #删除 HTTP 头（目录可以自定义路径）`

 
`make  &&   make   install`

 
`#跑完即可部署完`











4.nginx配置


**nginx主配置**










`[root@zww-102` `~]# cat  /etc/nginx/nginx.conf`

`user root;`

`worker_processes  4;`

`worker_rlimit_nofile 65535;`

`worker_cpu_affinity auto;`

 
`events {`

`    worker_connections  10240;`

`}`

 
`http {`

`    include       mime.types;`

`    include       /etc/nginx/blocksip.conf;                                 #nginx黑白名单配置`

`    # 加载子配置文件`

`    include       /etc/nginx/conf.d/*.conf;                                 #nginx子配置`

`    default_type  application/octet-stream;`

`    server_tokens   off;`

`    add_header Referrer-Policy value;`

`    add_header X-Permitted-Cross-Domain-Policies value;`

`    add_header X-Content-Type-Options nosniff;`

`    add_header X-Download-Options value;`

`    add_header X-Permitted-Cross-Domain-Policies value;`

`    add_header X-Frame-Options DENY;`

`    add_header X-XSS-Protection "1; mode=block";`

`    add_header Strict-Transport-Security "max-age=16070400"` 
`always;`

`    real_ip_header X-Forwarded-For;`

`    set_real_ip_from 10.194.173.55;`

`    real_ip_recursive on;`

`    more_clear_headers "Server";`

 
`    #限流白名单ip_white.conf`

`        geo $whiteiplist  {`

`        default` 
`1;`

`                include  /etc/nginx/ip_white.conf;`

`    }`

`        map $whiteiplist $limit {`

`                1` 
`$binary_remote_addr;`

`                0` 
`"";`

`    }`

`        #限流-配置`

`        #定义限制请求数的手机接口相关共享内存区域`

`        limit_req_zone $binary_remote_addr zone=mylimit:20m rate=1r/s;`

 
`        # 用于443` 
`api 20:00` `高峰期限速`

`        limit_req_zone $binary_remote_addr zone=limit_api_ip:20m rate=500r/s;`

`        limit_req_zone $limit zone=limit_req_by_ip:20m rate=50r/s;`

`        limit_conn_zone $limit zone=limit_conn_by_ip:20m;`

 
`        log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '`

`                      '$status $body_bytes_sent "$http_referer" '`

`                      '"$http_user_agent" "$http_x_forwarded_for" $request_time $upstream_response_time $request_uri';`

`    ` 
`    #access_log /mnt/data/gzddc/nginx/logs/access-$logdate.log;`

`    #利用linux脚本lognginx.sh和定时任务切割日志`

`    access_log /mnt/data/gzddc/nginx/logs/access.log main;`

`    #error_log /mnt/data/gzddc/nginx/logs/error.log;`

`    open_file_cache max=10240` 
`inactive=30s;`

 
`    # 传输的是数据小于client_body_buffer_size，直接在内存中存储`

`    # 如果大于client_body_buffer_size小于client_max_body_size，则在temp文件夹中进行临时存储`

`    client_max_body_size   20m;`

`    client_body_buffer_size 1m;`

`    ` 
`    # 如果请求头+请求行的大小没有超过2k，放行请求`

`    client_header_buffer_size 4k;`

 
`    # 开启高效文件传输模式`

`    sendfile            on;`

 
`    # 必须在sendfile开启模式才有效，防止网路阻塞，积极的减少网络报文段的数量（将响应头和正文的开始部分一起发送，而不一个接一个的发送）`

`    tcp_nopush          on;`

`    tcp_nodelay         on;`

 
`    # 保持会话超时时间，用于前端保持会话的超时时间，超过keepalive_timeout的设置，前端会断开会话保持`

`    keepalive_timeout  60s;`

`    # 请求体读超时时间，超时是指两个连续操作之间的时间段，而不是整个请求主体的传输`

`    client_body_timeout 20s;`

`    # nginx发送数据的响应时间，超过这个数则会关闭连接`

`    send_timeout    30s;`

`    gzip on;`

`    # 允许请求头带下划线`

`    underscores_in_headers on;`

 
`    #proxy_temp_path C:/gzddc/nginx-1.20.1/temp;`

 
`    proxy_cache_path /var/cache levels=1:2` 
`keys_zone=my_cache:20m inactive=10m max_size=3g use_temp_path=off;`

`    # 定义缓存的文件类型`

`    proxy_cache_key "$scheme$request_method$host$request_uri";`

`    # 定义缓存的状态码`

`    proxy_cache_valid 200` 
`10m;`

`    # 定义缓存的状态码`

`    proxy_cache_valid 404` 
`1m;`

`    # 定义缓存的状态码`

`    proxy_cache_valid any 1m;`

`    ` 
`    #配置websocket所需配置`

`    map $http_upgrade $connection_upgrade {`

`        default` 
`upgrade;`

`         ''` 
`close;`

`    }`

 
`    # 后端接口服务负载`

`    #upstream gateway_servers {`

`        #server 10.194.173.199:9999;`

`        #server 10.194.173.199:9998;`

`        #server 10.194.173.27:9999;`

`        #server 10.194.173.199:9997;`

`        #server 10.194.173.27:9998;`

`    #}`

 
`    # 80端口服务，用于内部服务调用`

`    ` 
 
`        # 11406端口映射`

`        server {`

`                listen      11406;`

`        server_name 10.194.172.102;`

`                charset     utf-8;`

 
`        #nginx监控端口，只对本机开放`

`        location /nginx_status {`

`            stub_status;`

`            access_log off;`

`            allow 127.0.0.1;`

`            allow 10.194.173.229;`

`            deny all;`

`        }`

 
`    }`

 
`  ` 
`}`












**nginx子配置**










`[root@zww-102` `~]# cat  /etc/nginx/conf.d/site.conf`

`    # 443端口映射`

`        server {`

`                #listen      443;`

`                listen 443` 
`;`

`                server_name 10.194.172.102;`

`                # 证书`

`                #ssl_certificate         /etc/nginx/cert/xf.gzyzems.com_bundle.pem;`

`                #ssl_certificate_key     /etc/nginx/cert/xf.gzyzems.com.key;`

`                #ssl_session_timeout 5m;`

`                #请按照以下协议配置`

`                #ssl_protocols TLSv1.2` 
`TLSv1.3;`

`                #请按照以下套件配置，配置加密套件，写法遵循 openssl 标准。`

`                #ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4:!IDEA:!DES:!3DES;`

`                #ssl_prefer_server_ciphers on;`

`                charset     utf-8;`

 
`                # 错误页面`

`                error_page 404` 
`/404.html;`

`                error_page 403` 
`/403.html;`

`                # 载入安全头部配置`

`                include /etc/nginx/limit_conf/add_header.conf;`

 
`                # 限制访问的接口`

`                #拦截-配置`

`                include /etc/nginx/limit_conf/limit_keyword.conf;`

 
`                location /MP_verify_YntqAHKLmkKBXbJh.txt {`

`                    root /var/www/gzh/;`

`                }`

`                location /MP_verify_SDbZ1Z9XM3lA5G2p.txt {`

`                    root /var/www/gzh/;`

`                }`

`                location / {`

`                        charset utf-8;`

`                        root /var/www/web;`

`                        index index.html;`

`                }`

`                ` 
`                #location /.well-known/pki-validation {`

`                #alias  /var/www/html/.well-known/acme-challenge;  # 确保这是您放置挑战文件的正确路径`

`                #autoindex on;`

`                #access_log off;`

`                #}`

`        #ssl证书`

`        #location /.well-known/pki-validation/ {`

`        #    alias /var/www/sslca/;`

`        #}`

 
`    # 设置404错误页面`

`    location /404.html {`

`        alias /var/www/error_html/404.html;`

`        internal; # 防止外部直接访问404页面`

`    }`

`    # 设置403错误页面`

`    location /403.html {`

`        alias /var/www/error_html/403.html;`

`        internal; # 防止外部直接访问403页面`

`    }`

`}`











5.nginx管理命令











`nginx                        #启动命令`

`nginx  -s  stop              #停止命令`

`nginx  -t                    #校验配置文件`

`nginx  -s  reload            #重新加载配置文件`











6.system管理，vim   /usr/lib/systemd/system/nginx.service











`[Unit]`

`Description=The NGINX HTTP and reverse proxy server`

`After=syslog.target network-online.target remote-fs.target nss-lookup.target`

`Wants=network-online.target`

 
`[Service]`

`Type=forking`

`PIDFile=/var/run/nginx.pid`

`ExecStartPre=/usr/sbin/nginx` `-t`

`ExecStart=/usr/sbin/nginx`

`ExecReload=/usr/sbin/nginx` `-s reload`

`ExecStop=/bin/kill` `-s QUIT $MAINPID`

`PrivateTmp=true`

`Restart=on-failure`

`RestartSec=5s`

 
`[Install]`

`WantedBy=multi-user.target`











7.system管理命令











`systemctl   start   nginx.service   启动nginx`

`systemctl   stop   nginx.service   停止nginx`

`systemctl   reload  nginx.service   加载nginx配置`

`systemctl   restart nginx.service   重启nginx`

`systemctl   enable` 
`nginx.service   开机自启`

