# WSL

> 来源: Trilium Notes 导出 | 路径: root/WSL


WSL




## WSL


## 一、帮助和状态

```
`wsl --help           # 查看 WSL 所有可用命令说明
wsl --version         # 查看 WSL 版本与内核版本
wsl --status          # 查看当前默认版本、内核状态
wsl --list           # 列出已安装的发行版
wsl --list --online      # 查看可在线安装的发行版列表
wsl --list --verbose      # 查看发行版及其 WSL 版本(1或2)和运行状态
wsl -l -v           # 上面命令的简写形式`
```
## 二、安装与卸载

```
`wsl --install         # 安装 WSL 及默认 Ubuntu 发行版
wsl --install -d Ubuntu-24.04 # 安装指定发行版 Ubuntu 24.04
wsl --uninstall        # 卸载整个 WSL（较少使用）
wsl --unregister Ubuntu-24.04 # 删除指定发行版（会清空所有数据）`
```
## 三、启动与进入linux

```
`wsl              # 进入默认 Linux 发行版
wsl -d Ubuntu-24.04      # 进入指定发行版
wsl -u root          # 使用 root 用户进入默认发行版
wsl -d Ubuntu-24.04 -u root  # 指定发行版并使用 root 用户`
```
## 四、运行单条命令

```
`wsl ls -la           # 在默认发行版执行 ls -la 命令
wsl -d Ubuntu-24.04 -- uname -a # 在指定发行版执行 uname -a`
```
## 五、停止与关闭

```
`wsl --shutdown         # 关闭所有正在运行的 WSL 实例
wsl --terminate Ubuntu-24.04  # 关闭指定发行版`
```
## 六、版本设置

```
`wsl --set-default Ubuntu-24.04     # 设置默认发行版
wsl --set-version Ubuntu-24.04 2    # 将发行版切换为 WSL2
wsl --set-default-version 2      # 设置未来安装默认使用 WSL2`
```
## 七、更新回滚

```
`wsl --update          # 更新 WSL 内核
wsl --update --rollback    # 回滚到上一版本内核`
```
## 八、迁移备份

```
`wsl --export Ubuntu-24.04 D:\backup\ubuntu.tar     # 导出发行版为 tar 备份文件
wsl --import Ubuntu-24.04 D:\WSL\Ubuntu D:\backup\ubuntu.tar --version 2 # 从备份导入到指定目录`
```
## 九、挂在物理磁盘

```
`wsl --mount \\.\PHYSICALDRIVE1       # 挂载整块物理磁盘
wsl --mount \\.\PHYSICALDRIVE1 --partition 1 # 挂载指定分区
wsl --unmount \\.\PHYSICALDRIVE1       # 卸载磁盘`
```

