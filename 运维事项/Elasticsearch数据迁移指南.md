# Elasticsearch 数据迁移指南

> 本文档记录从源服务器将 Elasticsearch 数据迁移到目标服务器的全流程。

## 环境信息

| 项目 | 源服务器 | 目标服务器 |
|------|----------|------------|
| ES 版本 | 7.17.9 | 7.17.9 |
| 端口 | 9400 | 9200 |
| 数据目录 | /home/elastic_9400/data | /home/elastic_9400/data |
| 备份目录 | /home/elastic_9400/backup | /home/elastic_9400/backup |
| 插件 | IK 中文分词 | IK 中文分词 |

## 迁移方案

采用 **快照与恢复** 方案（官方支持，最安全）：

1. 源服务器创建快照 → 备份到本地目录
2. 将备份目录传输到目标服务器（rsync/scp）
3. 目标服务器从快照恢复数据

---

## 详细步骤

### 一、源服务器 - 准备工作

#### 1. 检查 ES 容器状态

```bash
docker ps | grep -E "elasticsearch|es"
```

#### 2. 停止现有容器并重新启动（添加 path.repo 配置）

```bash
# 停止并删除容器（保留数据卷）
docker stop jms_es
docker rm jms_es

# 重新启动，添加 path.repo 和备份目录
docker run -d \
  --name jms_es \
  --network elastic \
  -p 9400:9200 \
  -p 9500:9300 \
  -e "discovery.type=single-node" \
  -e "ES_JAVA_OPTS=-Xms4g -Xmx4g" \
  -e "ELASTIC_PASSWORD=Yunst@2025es.com" \
  -e "xpack.security.enabled=true" \
  -e "path.repo=/usr/share/elasticsearch/backup" \
  -v /home/elastic_9400/data:/usr/share/elasticsearch/data \
  -v /home/elastic_9400/logs:/usr/share/elasticsearch/logs \
  -v /home/elastic_9400/backup:/usr/share/elasticsearch/backup \
  docker.elastic.co/elasticsearch/elasticsearch:7.17.9
```

#### 3. 安装 IK 中文分词插件（如未安装）

方式一：从本地 zip 安装：
```bash
# 复制 zip 到容器内
docker cp /home/elasticsearch-analysis-ik-7.17.9.zip jms_es:/tmp/

# 安装插件
docker exec -it jms_es /usr/share/elasticsearch/bin/elasticsearch-plugin install --batch file:///tmp/elasticsearch-analysis-ik-7.17.9.zip

# 重启容器
docker restart jms_es
```

方式二：构建带插件的镜像（推荐）：
```bash
mkdir -p /home/elastic_9400/dockerfile
cp /home/elasticsearch-analysis-ik-7.17.9.zip /home/elastic_9400/dockerfile/

cat > /home/elastic_9400/dockerfile/Dockerfile << 'EOF'
FROM docker.elastic.co/elasticsearch/elasticsearch:7.17.9
COPY elasticsearch-analysis-ik-7.17.9.zip /tmp/
RUN /usr/share/elasticsearch/bin/elasticsearch-plugin install --batch file:///tmp/elasticsearch-analysis-ik-7.17.9.zip
EOF

docker build -t elasticsearch-ik:7.17.9 /home/elastic_9400/dockerfile/
```

#### 4. 创建备份目录并修复权限

```bash
mkdir -p /home/elastic_9400/backup
chmod -R 777 /home/elastic_9400/backup/
chown -R 1000:1000 /home/elastic_9400/backup/
```

---

### 二、源服务器 - 创建快照

#### 1. 创建快照仓库

```bash
curl -u elastic:Yunst@2025es.com -X PUT "http://localhost:9400/_snapshot/backup_repo" -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "/usr/share/elasticsearch/backup"
  }
}
'
```

#### 2. 创建快照

```bash
# 创建快照（等待完成）
curl -u elastic:Yunst@2025es.com -X PUT "http://localhost:9400/_snapshot/backup_repo/snapshot_20250325?wait_for_completion=true"
```

#### 3. 查看快照状态

```bash
curl -u elastic:Yunst@2025es.com -X GET "http://localhost:9400/_snapshot/backup_repo/_status"
```

等待 `"state": "SUCCESS"` 表示完成。

---

### 三、传输快照到目标服务器

#### 1. 确认备份文件大小

```bash
du -sh /home/elastic_9400/backup/
```

#### 2. 使用 rsync 传输

```bash
rsync -avz --progress /home/elastic_9400/backup/ root@目标服务器IP:/home/elastic_9400/backup/
```

或使用 scp：
```bash
scp -r /home/elastic_9400/backup/* root@目标服务器IP:/home/elastic_9400/backup/
```

---

### 四、目标服务器 - 恢复数据

#### 1. 创建网络和目录

```bash
docker network create elastic

mkdir -p /home/elastic_9400/{data,logs,backup}
```

#### 2. 启动 ES（带 IK 插件和 path.repo）

```bash
docker run -d \
  --name jms_es \
  --network elastic \
  -p 9200:9200 \
  -p 9300:9300 \
  -e "discovery.type=single-node" \
  -e "ES_JAVA_OPTS=-Xms4g -Xmx4g" \
  -e "ELASTIC_PASSWORD=Yunst@2025es.com" \
  -e "xpack.security.enabled=true" \
  -e "path.repo=/usr/share/elasticsearch/backup" \
  -v /home/elastic_9400/data:/usr/share/elasticsearch/data \
  -v /home/elastic_9400/logs:/usr/share/elasticsearch/logs \
  -v /home/elastic_9400/backup:/usr/share/elasticsearch/backup \
  elasticsearch-ik:7.17.9
```

等待 ES 启动完成（约 30 秒）。

#### 3. 创建快照仓库

```bash
curl -u elastic:Yunst@2025es.com -X PUT "http://localhost:9200/_snapshot/backup_repo" -H 'Content-Type: application/json' -d'
{
  "type": "fs",
  "settings": {
    "location": "/usr/share/elasticsearch/backup"
  }
}
'
```

#### 4. 查看快照

```bash
curl -u elastic:Yunst@2025es.com -X GET "http://localhost:9200/_snapshot/backup_repo/_all"
```

#### 5. 恢复数据

恢复业务数据（排除系统索引）：
```bash
curl -u elastic:Yunst@2025es.com -X POST "http://localhost:9200/_snapshot/backup_repo/snapshot_20250325/_restore" -H 'Content-Type: application/json' -d'
{
  "indices": "*,-.geoip_databases,-.security-7,-.kibana*,-.tasks,-.async-search,-.apm*,-.ds-*,-.ilm-history-*,-.logs-deprecation*",
  "ignore_unavailable": true,
  "include_global_state": false
}
'
```

等待恢复完成。查看恢复进度：
```bash
curl -u elastic:Yunst@2025es.com localhost:9200/_cluster/health?pretty
```

当 `unassigned_shards` 降为 0 时恢复完成。

---

### 五、部署 Kibana（可选）

```bash
docker run -d \
  --name kibana \
  --network elastic \
  -p 5601:5601 \
  -e "ELASTICSEARCH_HOSTS=http://jms_es:9200" \
  -e "ELASTICSEARCH_USERNAME=elastic" \
  -e "ELASTICSEARCH_PASSWORD=Yunst@2025es.com" \
  docker.elastic.co/kibana/kibana:7.17.9
```

---

### 六、验证数据一致性

#### 1. 对比索引数量

```bash
# 源 ES
curl -u elastic:Yunst@2025es.com localhost:9400/_cat/indices?v | wc -l

# 目标 ES
curl -u elastic:Yunst@2025es.com localhost:9200/_cat/indices?v | wc -l
```

#### 2. 对比核心业务索引文档数

```bash
# 源 ES
curl -u elastic:Yunst@2025es.com localhost:9400/_cat/indices?v | grep -E "tb_user_tag|tb_biz_user"

# 目标 ES
curl -u elastic:Yunst@2025es.com localhost:9200/_cat/indices?v | grep -E "tb_user_tag|tb_biz_user"
```

#### 3. 抽样验证文档内容

```bash
# 源 ES - 查一条数据
curl -u elastic:Yunst@2025es.com localhost:9400/tb_user_tag/_doc/1

# 目标 ES - 查同一条
curl -u elastic:Yunst@2025es.com localhost:9200/tb_user_tag/_doc/1
```

---

## 常见问题

### 1. path.repo 权限问题

```
location [/home/elasticsearch/backup] doesn't match any of the locations specified by path.repo because this setting is empty
```

**解决**：在启动命令中添加 `-e "path.repo=/usr/share/elasticsearch/backup"`

### 2. IK 分词插件未安装

```
analyzer [ik_max_word] has not been configured in mappings
```

**解决**：安装 IK 插件（见上文步骤一.3）

### 3. 系统索引冲突

```
cannot restore index [.geoip_databases] because an open index with same name already exists
```

**解决**：使用 exclude 方式恢复，排除系统索引（见上文步骤四.5）

---

## 耗时估算

| 阶段 | 耗时 |
|------|------|
| 创建快照（80GB） | 约 30-50 分钟 |
| rsync 传输 | 取决于网络，约 10-30 分钟 |
| 恢复数据 | 约 10-20 分钟 |
| **总计** | **约 1-2 小时** |

---

*最后更新：2026-03-25*
