# rsync 命令完全指南

> 来源: Trilium Notes 导出 | 路径: root/rsync 命令完全指南




rsync 命令完全指南




## rsync 命令完全指南


## 基本语法


 

```
`rsync [选项] 源路径 目标路径`
```


 



## 常用选项

### 基本选项




`-a, --archive`: 归档模式，等同于 
`-rlptgoD
`（递归+保留权限+时间+组+所有者+设备文件）




`-v, --verbose`: 详细输出模式




`-z, --compress`: 传输时压缩




`-r, --recursive`: 递归复制目录




`-t, --times`: 保留修改时间




`-l, --links`: 复制符号链接为符号链接




`-p, --perms`: 保留权限




`-g, --group`: 保留属组




`-o, --owner`: 保留属主




`-D`: 保留设备文件和特殊文件





### 进度和删除




`--progress`: 显示传输进度




`-P`: 等同于 
`--partial --progress
`（部分传输+进度）




`--delete`: 删除目标中源没有的文件




`--delete-before`: 在传输前删除




`--delete-during`: 在传输过程中删除




`--delete-after`: 在传输后删除





### 网络传输




`-e`: 指定远程shell




`--port`: 指定SSH端口




`--rsh=ssh`: 使用SSH作为远程shell





## 实用命令示例

### 1. 本地同步


 

```
`# 同步目录（归档模式+详细输出）
rsync -av /source/directory/ /destination/directory/

# 同步目录并删除目标中多余文件
rsync -av --delete /source/ /destination/

# 同步并显示进度
rsync -avP /source/ /destination/`
```


 



### 2. 远程同步


 

```
`# 本地到远程
rsync -avzP /local/path/ user@remote.host:/remote/path/

# 远程到本地
rsync -avzP user@remote.host:/remote/path/ /local/path/

# 使用指定SSH端口
rsync -avzP -e "ssh -p 2222" /local/ user@host:/remote/

# 通过SSH同步
rsync -avzP --rsh=ssh /local/ user@host:/remote/`
```


 



### 3. 排除文件/目录


 

```
`# 排除单个文件
rsync -av --exclude='*.log' /source/ /destination/

# 排除多个模式
rsync -av --exclude={'*.tmp','*.bak'} /source/ /destination/

# 从文件读取排除列表
rsync -av --exclude-from='exclude-list.txt' /source/ /destination/

# 排除目录
rsync -av --exclude='cache/' /source/ /destination/`
```


 



### 4. 限速传输


 

```
`# 限制带宽为 1MB/s
rsync -avz --bwlimit=1024 /source/ user@host:/destination/

# 限制带宽为 500KB/s
rsync -avz --bwlimit=500 /source/ /destination/`
```


 



### 5. 部分传输和恢复


 

```
`# 启用部分传输（支持断点续传）
rsync -avP /source/largefile /destination/

# 指定部分文件目录
rsync -avP --partial-dir=.rsync-partial /source/ /destination/`
```


 



### 6. 权限控制


 

```
`# 保留所有属性
rsync -avAX /source/ /destination/

# 不保留权限（普通用户使用时常用）
rsync -rlvt /source/ /destination/

# 保留ACL和扩展属性
rsync -avX /source/ /destination/`
```


 



### 7. 比较和测试


 

```
`# 只显示差异，不实际传输
rsync -avn /source/ /destination/

# 详细显示要进行的操作
rsync -av --dry-run /source/ /destination/

# 使用校验和比较文件（更准确但更慢）
rsync -avc /source/ /destination/`
```


 



### 8. 定时备份脚本示例


 

```
`#!/bin/bash
# 每日备份脚本
SOURCE="/home/user/data/"
DEST="/backup/daily/"
LOGFILE="/var/log/rsync-backup.log"

rsync -avz --delete --progress \
--exclude='*.tmp' \
--exclude='cache/' \
"$SOURCE" "$DEST" >> "$LOGFILE" 2>&1`
```


 



### 9. 高级用法


 

```
`# 硬链接备份（节省空间）
rsync -av --link-dest=/previous/backup /source/ /new/backup/

# 最大文件大小限制
rsync -av --max-size='100M' /source/ /destination/

# 最小文件大小限制
rsync -av --min-size='1M' /source/ /destination/

# 只同步特定类型的文件
rsync -av --include='*.txt' --include='*.md' --exclude='*' /source/ /destination/

# 删除源文件（移动文件）
rsync -av --remove-source-files /source/ /destination/`
```


 



## 常用组合

### 备份网站


 

```
`rsync -avzP --delete \
--exclude='cache/*' \
--exclude='tmp/*' \
user@webserver:/var/www/html/ \
/backup/website-$(date +%Y%m%d)/`
```


 



### 同步照片库


 

```
`rsync -av --progress \
--exclude='*.thumb' \
--exclude='Thumbs.db' \
/Photos/ \
user@nas:/shared/Photos/`
```


 



### 远程服务器备份


 

```
`rsync -avzPe "ssh -p 2222" \
--bwlimit=5000 \
--delete \
/important/data/ \
backup@server.example.com:/backups/`
```

