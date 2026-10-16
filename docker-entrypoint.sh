#!/bin/sh
set -e

# data 目录和 config.json 都是 bind mount 进来的，宿主机上可能是 root 属主
# （Docker 自动创建目录时就是）。先交给非 root 的 app 用户，再降权启动，
# 这样应用既能写运行数据、又能保存设置，同时不以 root 身份跑。
# chown 失败不阻断启动：只读挂载时本来也写不了，让应用自己报错更清楚。
if [ "$(id -u)" = "0" ]; then
  mkdir -p /app/data
  chown -R app:app /app/data 2>/dev/null || true
  [ -e /app/config.json ] && { chown app:app /app/config.json 2>/dev/null || true; }
  exec gosu app "$@"
fi

exec "$@"
