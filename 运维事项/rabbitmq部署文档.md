# rabbitmq部署文档

> 来源: Trilium Notes 导出 | 路径: root/部署文档/rabbitmq部署文档


rabbitmq部署文档




## rabbitmq部署文档


rabbitmq官网下载地址：[https://github.com/rabbitmq/rabbitmq-server/releases/tag/v4.1.1](https://github.com/rabbitmq/rabbitmq-server/releases/tag/v4.1.1)


erlang官网源码下载地址/rabbitmq依赖rpm下载：  [https://www.erlang.org/downloads#nav-27](https://www.erlang.org/downloads#nav-27) 
   [https://github.com/rabbitmq/erlang-rpm/releases/tag/v27.3.4.1](https://github.com/rabbitmq/erlang-rpm/releases/tag/v27.3.4.1)


rabbitmq推荐erlang下载版本参考地址：[https://www.rabbitmq.com/docs/which-erlang](https://www.rabbitmq.com/docs/which-erlang)


## 一.介绍：

1.rabbitmq是用erlang编写，所以需要erlang环境才能正常安装rabbitmq

2.根据rabbitmq版本不同，下载的erlang也不同。查看《erlang下载版本参考地址》

## 二.部署：

1.这里以Linux安装rabbitmq-server-4.1.1-1.el8.noarch.rpm版本为例。




2.可以下载erlang26.2-27.*版本，这里以otp_src_27.3.4.tar.gz为例

 




 

3.安装rabbitmq之前需要安装erlang，二erlang为二进制安装包，需要源码编译。将包上传到/opt











`(1).部署erlang方式一`

`tar`  `-xf   otp_src_27.3.4.tar.gz    #解压`

`yum  -y  install`  
`gcc  make` `autoconf`

`./configure`

`make`  `&& make`  
`install`

`rpm  -ivh   rabbitmq-server-4.1.1-1.el8.noarch.rpm    --nodeps    #使用rpm安装rabbitmq由于erlang是源码编译安装的，rpm安装rabbitmq会报错缺少erl依赖。`

`(2).部署erlang方式二`

`rpm   -ivh  --nosignature  erlang-27.3.4.1-1.el8.x86_64.rpm   #rpm安装`











4.安装rabbitmq，如果使用二进制安装的erlang再安装rabbitmq会报错缺少erlang依赖，但是系统已经安装了erlang，所以需要跳过检查依赖











`rpm   -ivh  --nodeps   rabbitmq-server-4.1.1-1.el8.noarch.rpm      #二进制安装的erlang，跳过依赖即可，rpm安装的erlang，可以直接安装`











5.安装完可以启动，也可以访问，但是无法登录需要在命令行创建新账号。











`#管理命令`

`systemctl start    rabbitmq-server   # 启动服务`

`systemctl enable`   `rabbitmq-server   # 设置开机自启`

`systemctl status   rabbitmq-server   # 检查状态`

`systemctl restart  rabbitmq-server  # 重启服务`

 
`rabbitmqctl add_user admin yourpassword                 # 创建用户为admin，密码为yourpassword（账号密码可以自定义）`

`rabbitmqctl set_user_tags admin administrator           # 赋予admin账号为admininstrator管理员权限`

`rabbitmqctl set_permissions -p / admin ".*"` 
`".*"` `".*"`   `# 赋予所有权限`

`rabbitmq-plugins enable` `rabbitmq_management             # 启用 Web 管理插件`

 
`#配置以上配置重启rabbitmq即可生效，访问15672端口`

`#配置防火墙规则，systemctl  start  firewalld   #开启防火墙`

`#防火墙使用命令`

`firewall-cmd     --list-all          #查看防火墙所以规则`

 
`#配置端口的白名单模板`

`firewall-cmd --permanent --add-rich-rule="rule family="ipv4" source address="10.194.173.201" port protocol="tcp" port="8848" accept"`       
`#开放8848端口并且添加10.194.173.201为白名单，白名单ip自定义`

`firewall-cmd --permanent --remove-rich-rule="rule family="ipv4" source address="10.194.173.201" port protocol="tcp" port="8848" accept"`    
`#删除10.194.173.201白名单资格`

`firewall-cmd     --reload            #刷新防火墙规则`











## 三.配置rabbitmq：

1.登陆后配置队列，首先点击admin-->Virtual  Hosts-->在name输入队列名称→点击add 
virtual  host即可。




## 四.普通集群部署方式:

1.安装上面的部署方式部署好两个或以上单节点的rabbitmq

2.停止应用和配置应用：











`#rabbitmq管理命令`

`rabbitmqctl stop_app    停止应用`

`rabbitmqctl reset       清除命令`

`rabbitmqctl start_app   启动应用`

 
`scp /var/lib/rabbitmq/.erlang.cookie 192.168.0.10:/var/lib/rabbitmq       #rabbitmqctl集群节点的.erlang.cookie必须保持一致,修改cookie文件，要重启服务器，reboot.`











3.集群需要开启5672/15672/25672这三个端口：











`#防火墙使用命令`

`firewall-cmd     --list-all          #查看防火墙所以规则`

 
`#配置端口的白名单模板`

`firewall-cmd --permanent --add-rich-rule="rule family="ipv4" source address="10.194.173.201" port protocol="tcp" port="8848" accept"`       
`#开放8848端口并且添加10.194.173.201为白名单，白名单ip自定义`

`firewall-cmd --permanent --remove-rich-rule="rule family="ipv4" source address="10.194.173.201" port protocol="tcp" port="8848" accept"`    
`#删除10.194.173.201白名单资格`

`firewall-cmd     --reload            #刷新防火墙规则`











4.配置每个节点的hosts文件,ip对应的rabbitmq1最好是主机名，并且可以自定义：











`vim   /etc/hosts`

`192.168.0.10`  `rabbitmq1`

`192.168.0.20`  `rabbitmq2`

`192.168.0.30`  `rabbitmq3`











5.加入集群：











`rabbitmqctl stop_app                             #停止rabbitmq`

`rabbitmqctl join_cluster  rabbitmq1              #加入集群,在rabbitmq2和rabbitmq3执行`

`rabbitmqctl start_app                            #启动rabbitmq`

`rabbitmqctl cluster_status`











6.搭建集群结构之后，之前创建的交换机、队列、用户都属于单一结构，在新的集群环境中是 不能用的，所以在新的集群中**重新手动添加用户**即可（任意节点添加，所有节点共享）











`rabbitmqctl add_user admin  yourpassword                               # 创建用户为admin，密码为yourpassword（账号密码可以自定义）`

`rabbitmqctl set_user_tags admin  administrator                            # 赋予admin账号为admininstrator管理员权限`

`rabbitmqctl set_permissions -p "/"` 
`admin  ".*"` `".*"` `".*"`                              
`# 赋予所有权限`

`#注意：当节点脱离集群还原成单一结构后，交换机，队列和用户等数据 都会重新回来，此时，集群搭建完毕，但是默认采用的模式“普通模式”，可靠性不高`











## 五.配置镜像集群两种方式:

1、将所有队列设置为镜像队列，即队列会被复制到各个节点，各个节点状态一致,命令行配置。











`语法：set_policy {name} {pattern} {definition}`

`        1、name：策略名，可自定义`

`        2、pattern：队列的匹配模式（正则表达式）`

`                "^"` 
`可以使用正则表达式，比如"^queue_"` `表示对队列名称以“queue_”开头的所有 队列进行镜像，而"^"表示匹配所有的队列`

`        3、definition：镜像定义，包括三个部分ha-mode, ha-params, ha-sync-mode`

`                ha-mode：（High Available，高可用）模式，指明镜像队列的模式，有效值为 all/exactly/nodes，当前策略模式为 all，即复制到所有节点，包含新增节点`

`                            (1)all：表示在集群中所有的节点上进行镜像`

`                            (2)exactly：表示在指定个数的节点上进行镜像，节点的个数由ha-params指定`

`                            (3)nodes：表示在指定的节点上进行镜像，节点名称通过ha-params指定}`

`                       ha-params：ha-mode模式需要用到的参数`

`            ha-sync-mode：进行队列中消息的同步方式，有效值为automatic和manual`

 
`rabbitmqctl set_policy xall  "^"` 
`'{"ha-mode":"all"}'`  `#命令行执行`











2.web页面配置




3通过nginx或者haproxy负载，再加上keepalived可以实现高可用。

