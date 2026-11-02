# 基础镜像明确指定 bookworm（Debian 12 stable，更稳定）
FROM python:3.10-slim-bookworm

WORKDIR /app

# 阿里云源 + 最小化安装 + 清理
RUN sed -i 's|http://deb.debian.org|http://mirrors.aliyun.com|g' /etc/apt/sources.list.d/debian.sources && \
    sed -i 's|http://security.debian.org|http://mirrors.aliyun.com|g' /etc/apt/sources.list.d/debian.sources && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc \
        libpq-dev \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && rm -rf /var/cache/apt/archives/*

# 复制依赖文件（缓存优化）
COPY pyproject.toml README.md alembic.ini ./
COPY alembic ./alembic

# pip 加速 + 清理缓存
RUN pip install --no-cache-dir --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple && \
    pip install --no-cache-dir -e . -i https://pypi.tuna.tsinghua.edu.cn/simple && \
    pip cache purge

# 复制剩余代码
COPY ./app ./app
COPY ./scripts ./scripts
COPY ./secret ./secret
COPY ./static ./static

ENV PYTHONPATH=/app

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
