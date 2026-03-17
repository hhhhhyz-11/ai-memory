# GitLab 11.1.4 → 12.0.12 升级文档

> 日期：2026-03-17
> 目标：从 GitLab 11.1.4 升级到 12.0.12
> 环境：Docker 部署

---

## 📋 升级概述

本次升级完成了以下步骤：
- **Step 0**: 从官方 11.1.4 恢复备份（原环境是 11.1.4）
- **Step 1**: 11.1.4 → 11.11.8
- **Step 2**: 11.11.8 → 12.0.12

---

## ⚠️ 重要前提

1. **恢复到相同版本再升级**，不能跨版本恢复备份
2. 语言环境 `en_US.UTF-8` 必须匹配，否则 PostgreSQL 启动失败
3. 每次升级前都要进行增量备份

---

## 一、备份阶段

### 1.1 物理备份

```bash
# 复制配置、数据、日志目录
cp -r /usr/local/gitlab/etc /home/bakeup/gitlab/etc
cp -r /usr/local/gitlab/data /home/bakeup/gitlab/data
cp -r /usr/local/gitlab/log /home/bakeup/gitlab/log

# 打包备份
tar -czvf gitlab_backup_11.1.4.tar.gz /home/bakeup/gitlab/
```

### 1.2 容器内备份

```bash
# 在原 GitLab 容器内执行
docker exec -it <原容器名> gitlab-rake gitlab:backup:create
```

---

## 二、升级步骤

### Step 0: 启动官方 11.1.4 并恢复备份

```bash
# 1. 启动官方 11.1.4 容器
docker run --detach \
 --publish 8080:80 --publish 4443:443 --publish 2222:22 \
 --name gitlab_11.1.4 \
 --restart always \
 --volume /home/gitlab/data/data:/var/opt/gitlab \
 --volume /home/gitlab/log:/var/log/gitlab \
 --volume /home/gitlab/etc:/etc/gitlab \
 gitlab/gitlab-ce:11.1.4-ce.0

# 2. 等待启动完成（约5-10分钟）
docker exec -it gitlab_11.1.4 gitlab-ctl status

# 3. 修改 external_url（如果需要）
docker exec -it gitlab_11.1.4 sed -i 's/192.168.0.18/192.168.0.43/g' /etc/gitlab/gitlab.rb
docker exec -it gitlab_11.1.4 gitlab-ctl reconfigure

# 4. 恢复备份（在容器内执行）
docker exec -it gitlab_11.1.4 gitlab-rake gitlab:backup:restore BACKUP=1773719061_2026_03_17_11.1.4
```

---

### Step 1: 11.1.4 → 11.11.8

```bash
# 1. 备份当前版本
docker exec -it gitlab_11.1.4 gitlab-rake gitlab:backup:create

# 2. 停止并删除旧容器
docker stop gitlab_11.1.4
docker rm gitlab_11.1.4

# 3. 拉取 11.11.8
docker pull gitlab/gitlab-ce:11.11.8-ce.0

# 4. 启动 11.11.8
docker run --detach \
 --publish 8080:80 --publish 4443:443 --publish 2222:22 \
 --name gitlab_11.11.8 \
 --restart always \
 --volume /home/gitlab/data/data:/var/opt/gitlab \
 --volume /home/gitlab/log:/var/log/gitlab \
 --volume /home/gitlab/etc:/etc/gitlab \
 gitlab/gitlab-ce:11.11.8-ce.0

# 5. 等待启动后检查
docker exec -it gitlab_11.11.8 gitlab-ctl status
docker exec -it gitlab_11.11.8 gitlab-rake gitlab:check
```

---

### Step 2: 11.11.8 → 12.0.12

```bash
# 1. 备份当前版本
docker exec -it gitlab_11.11.8 gitlab-rake gitlab:backup:create

# 2. 停止并删除旧容器
docker stop gitlab_11.11.8
docker rm gitlab_11.11.8

# 3. 拉取 12.0.12
docker pull gitlab/gitlab-ce:12.0.12-ce.0

# 4. 启动 12.0.12
docker run --detach \
 --publish 8080:80 --publish 4443:443 --publish 2222:22 \
 --name gitlab_12.0.12 \
 --restart always \
 --volume /home/gitlab/data/data:/var/opt/gitlab \
 --volume /home/gitlab/log:/var/log/gitlab \
 --volume /home/gitlab/etc:/etc/gitlab \
 gitlab/gitlab-ce:12.0.12-ce.0

# 5. 等待启动后检查
docker exec -it gitlab_12.0.12 gitlab-ctl status
docker exec -it gitlab_12.0.12 gitlab-rake gitlab:check
```

---

## 三、踩坑记录与解决方案

### 🐛 问题 1: 语言环境不匹配

**现象:** PostgreSQL 无法启动，报错 `could not connect to server`

**原因:** 原 GitLab 使用 `en_US.UTF-8` 创建的数据库，新版本语言环境不一致

**解决:** 先用官方原版本（11.1.4）恢复备份，再逐级升级

---

### 🐛 问题 2: 克隆地址变成容器 ID

**现象:** Git 克隆地址变成 `git@7bd63ee2fcc6:xxx/xxx.git`（容器ID），而不是 IP

**原因:** 配置文件中的 IP 是旧地址 `192.168.0.18`

**解决:**
```bash
# 修改配置文件中的 IP
sed -i "s/192.168.0.18/192.168.0.43/g" /home/gitlab/etc/gitlab.rb

# 重新配置
docker exec -it gitlab_12.0.12 gitlab-ctl reconfigure
```

---

### 🐛 问题 3: Unicorn 端口冲突

**现象:** Unicorn 启动失败，报错 `Address already in use - bind(2) for 127.0.0.1:8080`

**原因:** nginx 和 unicorn 都想用 8080 端口冲突

**解决:** 在 `gitlab.rb` 中修改 unicorn 端口
```ruby
unicorn['port'] = 8081
```

然后执行 `gitlab-ctl reconfigure`

---

### 🐛 问题 4: CI/CD 页面 500 错误（11.11.8）

**现象:** 访问项目 CI/CD 页面报错 500

**原因:** 旧版本的 `gitlab-secrets.json` 导致 CI/CD 变量加密失败

**解决（方法1 - Rails Console）:**
```bash
docker exec -it gitlab_11.11.8 gitlab-rails console

Project.find_each do |project|
  project.variables.destroy_all
end
exit

docker exec -it gitlab_11.11.8 gitlab-ctl restart
```

---

### 🐛 问题 5: CI/CD 页面 500 错误 aes256_gcm_decrypt（12.0.12）

**现象:** CI/CD 页面报错 `aes256_gcm_decrypt`

**原因:** 加密密钥不兼容

**解决（方法2 - 数据库彻底清除）:**
```sql
-- 1. 登录数据库
docker exec -it gitlab_12.0.12 gitlab-rails dbconsole --database main

-- 2. 删除变量
DELETE FROM ci_group_variables;
DELETE FROM ci_variables;

-- 3. 清除 tokens
UPDATE projects SET runners_token = null, runners_token_encrypted = null;
UPDATE namespaces SET runners_token = null, runners_token_encrypted = null;
UPDATE application_settings SET runners_registration_token_encrypted = null;
UPDATE application_settings SET encrypted_ci_jwt_signing_key = null;
UPDATE ci_runners SET token = null, token_encrypted = null;
```

---

## 四、配置文件关键修改

在 `/home/gitlab/etc/gitlab.rb` 中：

```ruby
# 修改 IP 地址
external_url 'http://192.168.0.43'
gitlab_rails['gitlab_ssh_host'] = '192.168.0.43'
gitlab_rails['gitlab_shell_ssh_port'] = 2222

# 解决端口冲突（12.0.12+）
unicorn['port'] = 8081
```

---

## 五、常用命令

```bash
# 检查 GitLab 状态
docker exec -it gitlab_12.0.12 gitlab-ctl status

# 检查 GitLab 健康
docker exec -it gitlab_12.0.12 gitlab-rake gitlab:check

# 查看版本
docker exec -it gitlab_12.0.12 gitlab-rake gitlab:version

# 清理缓存
docker exec -it gitlab_12.0.12 gitlab-rake cache:clear

# 重启 GitLab
docker exec -it gitlab_12.0.12 gitlab-ctl restart

# 重新配置
docker exec -it gitlab_12.0.12 gitlab-ctl reconfigure
```

---

## 六、注意事项

1. **每版本升级后验证 2 小时以上**再继续下一版本
2. 每次升级前都要执行 `gitlab-rake gitlab:backup:create` 增量备份
3. 准备好回滚方案：删除容器后用旧镜像重新启动
4. CI/CD 变量被清除后需要重新在 Web 界面设置
5. 记录每次升级后的 `gitlab:env:info` 输出便于排查问题

---

## 七、后续升级路径

```
11.1.4 → 11.11.8 → 12.0.12 → 12.1.17 → 12.10.14 → 13.0.14 → 13.1.11 
→ 13.8.8 → 13.12.15 → 14.0.12 → 14.3.6 → 14.9.5 → 14.10.5 
→ 15.0.5 → 15.4.6 → 15.11.13 → 16.1.8
```

---

*文档更新时间: 2026-03-17*
