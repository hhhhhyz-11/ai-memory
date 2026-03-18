# Nginx proxy_pass 尾部斜杠问题

> 解决测试域名转发到生产时返回 404 的问题

## 问题描述

- 测试域名：`oa.changjiafs.com`
- 目标生产：`oa.gdyunst.com`
- 配置 `proxy_pass https://oa.gdyunst.com/oaweb/`
- 现象：访问返回 404

## 原因分析

`proxy_pass` 尾部斜杠的行为：

| 配置 | 行为 |
|------|------|
| `proxy_pass https://example.com/` | 替换 location 匹配的路径 |
| `proxy_pass https://example.com` | 保留原始请求路径 |

### 示例

```nginx
location /auth/ {
    proxy_pass https://oa.gdyunst.com/oaweb/;
}
```

请求 `/auth/oactual` 会被转发为 `https://oa.gdyunst.com/oaweb/auth/oactual`（错误）

```nginx
location /auth/ {
    proxy_pass https://oa.gdyunst.com;
}
```

请求 `/auth/oactual` 会被转发为 `https://oa.gdyunst.com/auth/oactual`（正确）

## 解决

去掉 `proxy_pass` 后的斜杠和路径：

```nginx
location / {
    proxy_pass https://oa.gdyunst.com;
}
```

## 配置层级

实际生产环境通常有多层转发：

```
测试机 → 生产机 → 第二层转发 → 后端 10.110.81.137:8088
```

每层都要注意 `proxy_pass` 的配置。
