#!/bin/bash
# Drawbridge 一键启动（macOS）
# 用法：双击本文件，或在终端执行 ./start-mac.command
# 它会自己检查 Docker 有没有装、有没有启动，缺什么补什么。

# 双击运行时工作目录是用户主目录，必须先切回脚本所在目录
cd "$(dirname "$0")" || exit 1

KEY_NAME="CHATGPT2API_AUTH_KEY"
BAD_KEYS="chatgpt2api drawbridge changeme password admin"
REBUILD="$1"

say()  { printf '%s\n' "$*"; }
ok()   { printf '  \033[32m✅ %s\033[0m\n' "$*"; }
warn() { printf '  \033[33m⚠️  %s\033[0m\n' "$*"; }
die()  { printf '\n\033[31m❌ %s\033[0m\n\n' "$*"; printf '按回车键关闭窗口...'; read -r _; exit 1; }

say ""
say "================================================"
say "        Drawbridge 一键启动（macOS）"
say "================================================"
say ""

# ---------- 1. 检查 Docker 是否安装 ----------
say "[1/5] 检查 Docker..."
if ! command -v docker >/dev/null 2>&1; then
  warn "没有检测到 Docker，尝试自动安装"
  if command -v brew >/dev/null 2>&1; then
    say "  用 Homebrew 安装 Docker Desktop（需要输入你的开机密码，安装包较大，请耐心等）..."
    brew install --cask docker || die "Docker 安装失败。可手动到 https://www.docker.com/products/docker-desktop/ 下载安装。"
    ok "Docker Desktop 安装完成"
  else
    say ""
    say "  你的电脑没有 Homebrew，无法自动安装。请二选一："
    say "    方式 A：打开 https://www.docker.com/products/docker-desktop/ 下载 .dmg，拖进「应用程序」"
    say "    方式 B：先装 Homebrew（https://brew.sh），再重新双击本文件"
    say ""
    open "https://www.docker.com/products/docker-desktop/" >/dev/null 2>&1
    die "请先安装 Docker Desktop，装好后重新双击本文件。"
  fi
else
  ok "Docker 已安装（$(docker --version | cut -d, -f1)）"
fi

# ---------- 2. 检查 Docker 是否在运行 ----------
say ""
say "[2/5] 检查 Docker 是否已启动..."
if ! docker info >/dev/null 2>&1; then
  warn "Docker 没在运行，正在帮你启动 Docker Desktop..."
  open -a Docker >/dev/null 2>&1 || open -a "Docker Desktop" >/dev/null 2>&1

  say "  等待 Docker 就绪（首次启动可能要 1-2 分钟）..."
  ready=0
  for _ in $(seq 1 90); do
    if docker info >/dev/null 2>&1; then ready=1; break; fi
    printf '.'
    sleep 2
  done
  say ""
  [ "$ready" = "1" ] || die "等了 3 分钟 Docker 还没就绪。请手动打开「启动台 → Docker」，等托盘图标不再转动后重新双击本文件。"
  ok "Docker 已就绪"
else
  ok "Docker 正在运行"
fi

# ---------- 3. 准备认证密钥 ----------
say ""
say "[3/5] 检查认证密钥..."
need_key=1
if [ -f .env ]; then
  current=$(grep -E "^${KEY_NAME}=" .env | tail -1 | cut -d= -f2- | tr -d '\r')
  if [ -n "$current" ]; then
    bad=0
    for b in $BAD_KEYS; do [ "$current" = "$b" ] && bad=1; done
    if [ "$bad" = "0" ]; then
      need_key=0
      ok "已有密钥，跳过（想换就删掉 .env 再运行本文件）"
    else
      warn ".env 里还是公开的默认密钥，将重新生成"
    fi
  else
    warn ".env 里没有密钥，将补上"
  fi
fi

if [ "$need_key" = "1" ]; then
  [ -f .env ] || cp .env.example .env
  # 去掉可能存在的旧定义，再用 LF 换行写入，避免 Windows 的 CRLF 把 \r 带进密钥
  grep -v "^${KEY_NAME}=" .env > .env.tmp 2>/dev/null || true
  mv .env.tmp .env
  newkey=$(openssl rand -hex 24)
  printf '%s=%s\n' "$KEY_NAME" "$newkey" >> .env
  ok "已生成随机密钥并写入 .env"
fi

# ---------- 4. 启动服务 ----------
say ""
say "[4/5] 启动服务..."
if docker image inspect drawbridge:local >/dev/null 2>&1 && [ "$REBUILD" != "--rebuild" ]; then
  docker compose up -d 2>&1 | tail -3
else
  say "  首次运行要构建镜像，约 3-8 分钟，中途别关窗口..."
  docker compose up -d --build 2>&1 | tail -5
fi
[ "${PIPESTATUS[0]}" = "0" ] || die "启动失败。常见原因：3000 端口被占用。用 docker compose logs 看详情。"

# ---------- 5. 等待就绪 ----------
say ""
say "[5/5] 等待服务就绪..."
healthy=0
for _ in $(seq 1 60); do
  status=$(docker inspect --format '{{.State.Health.Status}}' drawbridge 2>/dev/null || echo "")
  if [ "$status" = "healthy" ]; then healthy=1; break; fi
  printf '.'
  sleep 2
done
say ""

login_key=$(grep -E "^${KEY_NAME}=" .env | tail -1 | cut -d= -f2- | tr -d '\r')

if [ "$healthy" = "1" ]; then
  ok "服务已就绪"
else
  warn "服务起来了但健康检查还没通过，可以稍等片刻或在面板里看状态"
fi

say ""
say "================================================"
say "  🎉 启动完成"
say "================================================"
say ""
say "  打开面板：   http://localhost:3000"
say ""
say "  登录密钥：   $login_key"
say ""
say "  下一步：进面板 →「号池管理」→「导入」→ OAuth 登录，"
say "         把 GPT 账号导进去才能生成图片。"
say ""
say "  停止服务：   docker compose down"
say "  查看日志：   docker compose logs -f"
say ""
say "按回车键关闭窗口..."
read -r _
