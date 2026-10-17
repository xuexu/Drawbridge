# Drawbridge 一键启动（Windows / PowerShell）
# 一般不用直接跑这个文件，双击仓库根目录的 start-windows.bat 即可。
# 它会自己检查 Docker 有没有装、有没有启动，缺什么补什么。
param([switch]$Rebuild)

$KeyName = "CHATGPT2API_AUTH_KEY"
$BadKeys = @("chatgpt2api", "drawbridge", "changeme", "password", "admin")

function Say  ($m) { Write-Host $m }
function Ok   ($m) { Write-Host "  ✅ $m" -ForegroundColor Green }
function Warn ($m) { Write-Host "  ⚠️  $m" -ForegroundColor Yellow }
function Die  ($m) {
    Write-Host ""
    Write-Host "❌ $m" -ForegroundColor Red
    Write-Host ""
    Read-Host "按回车键关闭窗口"
    exit 1
}

# 双击运行时工作目录可能是 system32，必须先切回脚本所在目录
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if ($RepoRoot -and (Test-Path (Join-Path $RepoRoot "docker-compose.yml"))) {
    Set-Location $RepoRoot
} elseif (-not (Test-Path ".\docker-compose.yml")) {
    Die "没找到 docker-compose.yml。请确认你是在 Drawbridge 项目目录里运行本脚本。"
}

Say ""
Say "================================================"
Say "        Drawbridge 一键启动（Windows）"
Say "================================================"
Say ""

# ---------- 1. 检查 Docker 是否安装 ----------
Say "[1/5] 检查 Docker..."
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Warn "没有检测到 Docker，尝试自动安装"
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Say "  用 winget 安装 Docker Desktop（会弹 UAC 授权框，请点「是」）..."
        winget install --id Docker.DockerDesktop -e --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) {
            Die "winget 安装失败。请手动到 https://www.docker.com/products/docker-desktop/ 下载安装。"
        }
        Ok "Docker Desktop 安装完成"
        Say ""
        Warn "首次安装后通常需要【注销一次 Windows 或重启】Docker 才能正常工作。"
        Say "  如果接下来启动失败，请重启电脑后重新双击 start-windows.bat。"
        Say ""
    } else {
        Say ""
        Say "  你的系统没有 winget（需要 Windows 10 1809 以上），无法自动安装。请："
        Say "    打开 https://www.docker.com/products/docker-desktop/ 下载安装"
        Say "    安装时保持勾选「Use WSL 2 instead of Hyper-V」"
        Start-Process "https://www.docker.com/products/docker-desktop/"
        Die "装好 Docker Desktop 后，重新双击 start-windows.bat。"
    }
} else {
    Ok "Docker 已安装（$(docker --version)）"
}

# ---------- 2. 检查 Docker 是否在运行 ----------
Say ""
Say "[2/5] 检查 Docker 是否已启动..."
docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Warn "Docker 没在运行，正在帮你启动 Docker Desktop..."
    $exe = @(
        "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
        "$env:LOCALAPPDATA\Docker\Docker Desktop.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($exe) {
        Start-Process $exe
    } else {
        Die "找不到 Docker Desktop 程序。请从开始菜单手动打开它，等它就绪后重新运行。"
    }

    Say "  等待 Docker 就绪（首次启动可能要 1-2 分钟）..."
    $ready = $false
    foreach ($i in 1..90) {
        docker info *> $null
        if ($LASTEXITCODE -eq 0) { $ready = $true; break }
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 2
    }
    Say ""
    if (-not $ready) {
        Die "等了 3 分钟 Docker 还没就绪。请手动打开 Docker Desktop，等托盘图标不再转动后重新运行。"
    }
    Ok "Docker 已就绪"
} else {
    Ok "Docker 正在运行"
}

# ---------- 3. 准备认证密钥 ----------
Say ""
Say "[3/5] 检查认证密钥..."
$envPath = Join-Path (Get-Location) ".env"
$needKey = $true

if (Test-Path $envPath) {
    $line = Get-Content $envPath | Where-Object { $_ -match "^$KeyName=" } | Select-Object -Last 1
    if ($line) {
        $current = ($line -replace "^$KeyName=", "").Trim()
        if ($current -and ($BadKeys -notcontains $current)) {
            $needKey = $false
            Ok "已有密钥，跳过（想换就删掉 .env 再运行本文件）"
        } elseif ($current) {
            Warn ".env 里还是公开的默认密钥，将重新生成"
        } else {
            Warn ".env 里没有密钥，将补上"
        }
    } else {
        Warn ".env 里没有密钥，将补上"
    }
}

if ($needKey) {
    if (Test-Path $envPath) {
        $lines = @(Get-Content $envPath | Where-Object { $_ -notmatch "^$KeyName=" })
    } else {
        $lines = @(Get-Content (Join-Path (Get-Location) ".env.example"))
    }
    # 用 .NET 加密随机数，Windows 上没有 openssl
    $bytes = New-Object byte[] 24
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $newKey = -join ($bytes | ForEach-Object { $_.ToString("x2") })
    $lines += "$KeyName=$newKey"
    # 显式用 LF 写入：Add-Content 会写 CRLF，可能把 \r 带进密钥导致登录失败
    [System.IO.File]::WriteAllText($envPath, ($lines -join "`n") + "`n")
    Ok "已生成随机密钥并写入 .env"
}

# ---------- 4. 启动服务 ----------
Say ""
Say "[4/5] 启动服务..."
docker image inspect drawbridge:local *> $null
$hasImage = ($LASTEXITCODE -eq 0)

if ($hasImage -and -not $Rebuild) {
    docker compose up -d
} else {
    Say "  首次运行要构建镜像，约 3-8 分钟，中途别关窗口..."
    docker compose up -d --build
}
if ($LASTEXITCODE -ne 0) {
    Die "启动失败。常见原因：3000 端口被占用。用 docker compose logs 看详情。"
}

# ---------- 5. 等待就绪 ----------
Say ""
Say "[5/5] 等待服务就绪..."
$healthy = $false
foreach ($i in 1..60) {
    $status = docker inspect --format "{{.State.Health.Status}}" drawbridge 2>$null
    if ($status -eq "healthy") { $healthy = $true; break }
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 2
}
Say ""

$loginKey = ((Get-Content $envPath | Where-Object { $_ -match "^$KeyName=" } | Select-Object -Last 1) -replace "^$KeyName=", "").Trim()

if ($healthy) { Ok "服务已就绪" } else { Warn "服务起来了但健康检查还没通过，可以稍等片刻或在面板里看状态" }

Say ""
Say "================================================"
Say "  🎉 启动完成"
Say "================================================"
Say ""
Say "  打开面板：   http://localhost:3000"
Say ""
Say "  登录密钥：   $loginKey"
Say ""
Say "  下一步：进面板 →「号池管理」→「导入」→ OAuth 登录，"
Say "         把 GPT 账号导进去才能生成图片。"
Say ""
Say "  停止服务：   docker compose down"
Say "  查看日志：   docker compose logs -f"
Say ""
Read-Host "按回车键关闭窗口"
