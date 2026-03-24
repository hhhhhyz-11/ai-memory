# -----------------------------------------------------------
# 第一阶段：构建阶段 (Builder Stage) - 用于安装所有 Python 依赖
# -----------------------------------------------------------
FROM python:3.12-slim-bookworm AS builder

# 设置工作目录
WORKDIR /app

# 使用阿里云 PyPI 镜像
RUN pip install --no-cache-dir --upgrade pip wheel --disable-pip-version-check \
 -i https://mirrors.aliyun.com/pypi/simple/

# 复制 requirements.txt
COPY requirements.txt .

# 安装 Python 依赖
RUN pip install --no-cache-dir -r requirements.txt \
 -t /install \
 -i https://mirrors.aliyun.com/pypi/simple/

# -----------------------------------------------------------
# 第二阶段：最终镜像阶段
# -----------------------------------------------------------
FROM python:3.12-slim-bookworm

# 设置工作目录
WORKDIR /app

# 定义时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo '$TZ' > /etc/timezone

# 从 builder 阶段复制依赖
COPY --from=builder /install /usr/local/lib/python3.12/site-packages/

# 复制应用程序代码
COPY . .

# 暴露应用端口
EXPOSE 5002

# 不设置启动命令，由运行时指定
