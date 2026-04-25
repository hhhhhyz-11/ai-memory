# Oracle 建表操作指南

> 适用环境：Oracle 11g/12c on CentOS 7
> 更新时间：2026-04-25

---

## 一、操作流程

### 1.1 修改 SQL 文件权限

```bash
# 查看文件权限
ll *.sql

# 修改所有者为 oracle
chown -R oracle ora_space*.sql

# 验证修改结果
ll *.sql
```

**输出示例：**
```
-rw-r--r-- 1 oracle root 279375992 4月 24 21:59 ora_space01_V0.01.sql
-rw-r--r-- 1 oracle root   688498 4月 24 22:00 ora_space_layout_dtl_V0.01.sql
-rw-r--r-- 1 oracle root 1764774 4月 24 21:59 ora_space_seg_dtl_V0.01.sql
```

### 1.2 创建表空间

```bash
su - oracle
sqlplus / as sysdba
```

```sql
CREATE TABLESPACE space01
  DATAFILE '/u01/app/oracle/oradata/orcl/space01.dbf'
  SIZE 1G AUTOEXTEND ON;
```

### 1.3 创建用户并授权

```sql
CREATE USER space01 IDENTIFIED BY space01 DEFAULT TABLESPACE space01;
GRANT CONNECT, RESOURCE TO space01;
GRANT DBA TO space01;
EXIT;
```

### 1.4 执行建表脚本（sysdba 方式）

```bash
sqlplus / as sysdba <<EOF
@/home/oracle/ora_space01_V0.01.sql
EOF
```

### 1.5 导入数据脚本

```bash
sqlplus space01/space01 @ora_space_layout_dtl_V0.01.sql
sqlplus space01/space01 @ora_space_seg_dtl_V0.01.sql
```

### 1.6 验证结果

```bash
sqlplus space01/space01
```

```sql
-- 查看所有表
SELECT table_name FROM user_tables ORDER BY table_name;

-- 查看表数据量
SELECT COUNT(*) FROM space_layout_dtl;
SELECT COUNT(*) FROM space_seg_dtl;
```

**表清单：**
| 表名 | 数据量 |
|------|--------|
| SPACE_BASE | - |
| SPACE_CODESHARE | - |
| SPACE_HEADER | - |
| SPACE_LAYOUT_DTL | 5000 |
| SPACE_SEGMENT | - |
| SPACE_SEGMENT_DETAIL | - |
| SPACE_SEG_DTL | 10000 |

---

## 二、运维排查命令

### 2.1 监听器管理

```bash
# 查看监听器状态
lsnrctl services
lsnrctl status

# 停止监听器
lsnrctl stop

# 启动监听器
lsnrctl start
```

### 2.2 TNS 进程检查

```bash
ps -ef | grep tns
```

### 2.3 主机名和 hosts 文件

```bash
hostname -f
cat /etc/hosts
vim /etc/hosts
```

### 2.4 数据文件路径查询

```sql
SELECT name FROM v$datafile;
```

---

## 三、踩坑经验

| 问题 | 原因 | 解决 |
|------|------|------|
| 表空间创建失败 | 路径写成 `ORCL`（大写），实际是 `orcl`（小写） | 修正为小写路径 |
| 用户无权限连接 | Oracle 用户不存在或密码错误 | 创建用户并 grant DBA |
| 监听器异常 | 可能被修改了 hosts 文件 | 检查 `/etc/hosts` |
| 建表脚本 279MB | 用 sysdba 执行会建在 sys schema 下 | 确认最终用户是否匹配 |

---

## 四、关键路径速查

| 项目 | 路径 |
|------|------|
| 数据文件目录 | `/u01/app/oracle/oradata/orcl/` |
| 监听器端口 | 1521 |
| Oracle 连接方式 | `sqlplus / as sysdba`（本地无需密码） |
| space01 账号密码 | `space01 / space01` |

---

*文档如有疑问联系运维人员*
