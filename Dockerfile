ARG BUILDPLATFORM
ARG TARGETPLATFORM
ARG TARGETARCH

# 前端用 bun 构建：仓库里提交的是 bun.lock，用 npm 装会忽略它，两次构建装出的依赖版本可能不同
FROM --platform=$BUILDPLATFORM oven/bun:1-alpine AS web-build

WORKDIR /app/web

COPY web/package.json web/bun.lock ./
RUN bun install --frozen-lockfile

COPY VERSION /app/VERSION
COPY CHANGELOG.md /app/CHANGELOG.md
COPY web ./
RUN NEXT_PUBLIC_APP_VERSION="$(cat /app/VERSION)" bun run build


FROM --platform=$TARGETPLATFORM python:3.13-slim AS app

ARG TARGETPLATFORM
ARG TARGETARCH

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_LINK_MODE=copy

WORKDIR /app

# 安装系统依赖
# - git: Git 存储后端需要
# - openssl: 备份加密需要
# - gosu: 入口脚本用它把 root 降权成 app 用户
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    openssl \
    gosu \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir uv

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

COPY main.py ./
COPY config.json ./
COPY VERSION ./
COPY api ./api
COPY services ./services
COPY utils ./utils
COPY scripts ./scripts
COPY docker-entrypoint.sh ./
COPY --from=web-build /app/web/out ./web_dist

RUN chmod +x /app/docker-entrypoint.sh \
    && useradd --create-home --uid 1000 app \
    && mkdir -p /app/data \
    && chown -R app:app /app

# 非 root 运行；80 是特权端口，所以容器内监听 8080（宿主机映射端口不变）
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD python3 -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=4).status == 200 else 1)"

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["/app/.venv/bin/uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080", "--access-log"]
