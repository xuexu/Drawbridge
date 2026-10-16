#!/bin/sh
set -e

# data 目录是 bind mount 进来的，宿主机上可能是 root 属主（Docker 自动创建时就是）。
# 先把它交给非 root 的 app 用户，再降权启动，避免应用以 root 写宿主机文件。
if [ "$(id -u)" = "0" ]; then
  mkdir -p /app/data
  chown -R app:app /app/data
  exec gosu app "$@"
fi

exec "$@"
