# Vagrant 从入门到超神：快速构建开发环境

> 来源：[CSDN - 保姆级教程：Vagrant 从入门到超神玩法](https://blog.csdn.net/m0_50546016/article/details/119176009)

---

## 一、初识 Vagrant

**Vagrant** 是一款用 Ruby 语言开发的虚拟机管理工具，它可以让你通过命令行快速创建和配置虚拟机，无需手动点击安装。

**核心优势：**
- 2 行命令即可创建虚拟机
- 统一开发环境，团队协作更高效
- 轻松打包和分享开发环境

**前置要求：**
- [Vagrant](https://www.vagrantup.com/downloads)
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads)

---

## 二、快速开始

### 2.1 一键安装各种操作系统

```bash
# 安装 Windows 10
vagrant init galppoc/windows10
vagrant up

# 安装 macOS
vagrant init jhcook/macos-sierra
vagrant up

# 安装 CentOS
vagrant init generic/centos7
vagrant up

# 安装 Ubuntu
vagrant init generic/ubuntu2010
vagrant up

# 安装 Fedora
vagrant init generic/fedora32
vagrant up

# 安装 Oracle Linux
vagrant init generic/oracle7
vagrant up
```

### 2.2 启用命令行自动补全

```bash
vagrant autocomplete install --bash --zsh
```

重启终端后，输入部分命令按 Tab 键即可自动补全。

---

## 三、基础命令

### 3.1 Vagrant 基础

```bash
vagrant --help          # 查看帮助
vagrant --version       # 查看版本
vagrant global-status   # 查看所有已安装的虚拟机
```

### 3.2 Box 管理

```bash
vagrant box list                    # 查看已添加的 box
vagrant box add /path/to/box --name=centos7   # 添加本地 box
vagrant box remove centos7          # 移除 box
```

### 3.3 虚拟机操作

```bash
vagrant init luciferliu/oracle11g   # 初始化虚拟机（生成 Vagrantfile）
vagrant validate                    # 校验 Vagrantfile 语法
vagrant up                          # 启动虚拟机
vagrant ssh                         # SSH 连接虚拟机（默认用户/密码：vagrant/vagrant）
vagrant status                      # 查看虚拟机状态
vagrant reload                      # 重载虚拟机（修改 Vagrantfile 后使用）
vagrant halt                        # 关闭虚拟机
vagrant package                     # 打包虚拟机（可分享给他人）
vagrant destroy                     # 删除虚拟机（⚠️ 会删除所有文件）
```

### 3.4 插件管理

```bash
vagrant plugin list                 # 查看已安装插件
vagrant plugin install <plugin>     # 安装插件
vagrant plugin uninstall <plugin>    # 卸载插件
vagrant plugin repair               # 修复插件
vagrant plugin update                # 更新插件
```

---

## 四、推荐插件

### 4.1 常用插件

```bash
vagrant plugin install vagrant-parallels   # Parallels Desktop 虚拟机支持
vagrant plugin install vagrant-proxyconf    # 设置虚拟机代理
vagrant plugin install vagrant-share        # 分享虚拟机环境给朋友
vagrant plugin install vagrant-mutate        # 转换 box 格式（virtualbox → KVM）
vagrant plugin install vagrant-reload        # 支持重新加载配置
```

### 4.2 插件资源

> 插件列表：https://vagrant-lists.github.io/#plugins

---

## 五、进阶技巧

### 5.1 Vagrantfile 定制

初始化后生成的 `Vagrantfile` 是核心配置文件，可以自定义：
- 内存和 CPU
- 网络配置（端口转发 / 私有网络）
- 共享文件夹
- provisioning（自动安装软件）

### 5.2 解决插件安装慢

（原文未详细展开，可通过代理或国内镜像解决）

---

## 六、卸载 Vagrant

### Windows
```cmd
# 通过控制面板卸载，或使用 Chocolatey
choco uninstall vagrant
```

### Linux
```bash
sudo rm -rf /opt/vagrant
sudo rm -f /usr/local/bin/vagrant
```

### macOS
```bash
sudo rm -rf /Applications/Vagrant
sudo rm -rf /opt/vagrant
rm -rf ~/.vagrant.d
```

---

## 七、总结

Vagrant 是开发者的神器，能够：
- ✅ 快速创建一致的开发环境
- ✅ 轻松在团队中共享环境配置
- ✅ 一键销毁/重建环境，告别"在我机器上能运行"
- ✅ 支持多种操作系统和虚拟化平台
