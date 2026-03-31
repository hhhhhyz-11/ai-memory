# MinIO安装文档

> 来源: Trilium Notes 导出 | 路径: root/部署文档/MinIO安装文档




MinIO安装文档




## MinIO安装文档


**官网下载地址：**

[https://dl.min.io/server/minio/release/linux-amd64/archive/](https://dl.min.io/server/minio/release/linux-amd64/archive/)



**安装步骤**


通过wget方式下载rmp包并安装













`cd` `/opt`

`wget https://dl.min.io/server/minio/release/linux-amd64/archive/minio-20240922003343.0.0-1.x86_64.rpm -O minio.rpm`

`# 安装minio`

`rpm -ivh minio.rmp`

 
`# 安装成功，会生成如下文件（可以用命令查看：find / -name "minio*"）：`

`/usr/lib/systemd/system/minio.service  系统服务文件`

`/etc/default/minio/`  `minio环境变量配置文件(如果没有自行创建即可）`

`/usr/local/bin/minio`  `minio二进制可执行文件`
















注意点













`/usr/lib/systemd/system/minio.service文件中，一定要将TimeoutSec改为TimeoutStopSec。千万注意。`

 
`vi` `/usr/lib/systemd/system/minio.service`

`# 将TimeoutSec=infinity修改为TimeoutStopSec=infinity`

`TimeoutStopSec=infinity`

 
`# 保存并退出`

`:wq`
















创建minio用户和minio数据目录，并赋值用户权限













`groupadd -r minio-user`

`useradd` `-M -r -g minio-user minio-user`

`mkdir` `-p /home/minio`

`chown` `minio-user:minio-user /home/minio`
















修改minio环境变量配置文件













`vi` `/etc/default/minio`

`# 添加如下配置`

 
`# 指定账号密码`

`MINIO_ROOT_USER=minio`

`MINIO_ROOT_PASSWORD=Yst@163.com`

`# 指定数据目录`

`MINIO_VOLUMES="/home/minio"`

`# 指定控制台地址等其他配置`

`MINIO_OPTS="--console-address :9001"`
















启动minio服务













`# 启动服务`

`systemctl start minio.service`

`# 查看日志`

`systemctl status minio.service -l`

`journalctl -f -u minio.service`

 
`# 访问控制台`

`http://localhost:9001`

