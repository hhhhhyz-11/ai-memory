# elastic、kibana docker部署步骤

> 来源: Trilium Notes 导出 | 路径: root/部署文档/elastic、kibana docker部署步骤


elastic、kibana docker部署步骤




## elastic、kibana docker部署步骤


### **1.创建数据目录和日志目录**











`mkdir -p ~/elasticsearch/{data,logs}`

`mkdir -p ~/kibana/{data,logs}`











### **2.修改目录权限**











`chown -R 1000:1000` `~/elasticsearch`

`chown -R 1000:1000` `~/kibana`

`chmod 755` `elasticsearch/`

`chmod 755` `kibana`











### **3.部署Elasticsearch**











`docker run -d \`

`--name elasticsearch \`

`--network elastic \`

`-p 9200:9200` `\`

`-p 9300:9300` `\`

`-e "discovery.type=single-node"` `\`

`-e "ES_JAVA_OPTS=-Xms512m -Xmx512m"` 
`\`

`-e "ELASTIC_PASSWORD=Yunst@2025es.com"` 
`\`

`-e "xpack.security.enabled=true"` 
`\    #开启密码登录认证`

`-v /home/elasticsearch/data:/usr/share/elasticsearch/data \`

`-v /home/elasticsearch/logs:/usr/share/elasticsearch/logs \`

`docker.elastic.co/elasticsearch/elasticsearch:7.17.9`











### **4.部署kibana**











`docker run -d \`

`  --name kibana \`

`  --network elastic \`

`  -p 5601:5601` `\`

`  -v /etc/localtime:/etc/localtime:ro \`

`  -v /etc/timezone:/etc/timezone:ro \`

`  -v ~/kibana/data:/usr/share/kibana/data \`

`  -v ~/kibana/logs:/usr/share/kibana/logs \`

`  -e "ELASTICSEARCH_HOSTS=`[`http://elasticsearch:9200`](http://elasticsearch:9200/)
`"` `\ `

`  -e "ELASTICSEARCH_USERNAME=elastic"` 
`\`

`  -e "ELASTICSEARCH_PASSWORD=Yunst@2025es.com"` 
`\`

`  docker.elastic.co/kibana/kibana:7.17.9`











### **5.elasticsearch验证**

浏览器输入：[http://ip:9200/](http://ip:9200/)，如以下显示即正常








### **6.kibana验证**

浏览器输入 http://ip:5601/,如以下显示即正常

