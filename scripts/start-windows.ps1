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

# 从注册表重新读取 PATH。winget 刚装完 Docker 时，当前进程的 PATH 还是旧的，
# 不刷新就会一直报「找不到 docker」。
function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user    = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machine;$user"

    # 兜底：直接补上 Docker Desktop 的默认安装目录
    foreach ($p in @(
        (Join-Path $env:ProgramFiles "Docker\Docker\resources\bin"),
        (Join-Path $env:ProgramData "DockerDesktop\version-bin")
    )) {
        if ((Test-Path $p) -and ($env:Path -notlike "*$p*")) { $env:Path = "$p;$env:Path" }
    }
}

function Test-DockerCli { return [bool](Get-Command docker -ErrorAction SilentlyContinue) }

# ---------- 定位项目目录 ----------
# 用脚本自身路径判断，不要只看 Get-Location：start-windows.bat 里的 pushd
# 会把 UNC 路径映射成临时盘符，Get-Location 就看不到 \\ 开头了。
$ScriptPath = $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptPath)

Say ""
Say "================================================"
Say "        Drawbridge 一键启动（Windows）"
Say "================================================"
Say ""

# ---------- 网络路径自动搬家 ----------
# Docker 不能用 UNC 路径（\\Mac\Home\... 这类虚拟机共享目录）作为构建目录。
# 这里直接自动复制到本机硬盘，不让用户自己搬。
if ($ScriptPath -like "\\*" -or (Get-Location).Path -like "\\*") {
    $SourceDir = $RepoRoot
    $LocalCopy = Join-Path $env:USERPROFILE "Drawbridge"

    Warn "项目在网络路径上：$SourceDir"
    Say "  Docker 不能用网络路径构建，正在自动复制到本机硬盘："
    Say "    $LocalCopy"
    Say ""

    if (Test-Path (Join-Path $LocalCopy "docker-compose.yml")) {
        Ok "本机已有一份，直接用它（不覆盖，你的账号数据和密钥都在）"
    } else {
        Say "  复制中，首次会慢一点（网络路径读写本来就慢）..."
        # robocopy 是 Windows 自带的，处理 UNC 最稳；退出码 0-7 都算成功，>=8 才是失败
        robocopy $SourceDir $LocalCopy /E /NFL /NDL /NJH /NJS /NP /R:1 /W:1 | Out-Null
        if ($LASTEXITCODE -ge 8) {
            Die "自动复制失败（robocopy 退出码 $LASTEXITCODE）。请手动把项目文件夹复制到 $LocalCopy 后，到那里双击 start-windows.bat。"
        }
        Ok "已复制到本机"
    }

    Set-Location $LocalCopy
    Say ""
    Warn "以后请直接到这个本机文件夹双击 start-windows.bat，别再走网络路径"
    Say "    $LocalCopy"
    Say ""
}

if (-not (Test-Path ".\docker-compose.yml")) {
    Die "没找到 docker-compose.yml。请确认你是在 Drawbridge 项目目录里运行本脚本。"
}

# ---------- 1. 检查 Docker 是否安装 ----------
Say "[1/5] 检查 Docker..."
if (-not (Test-DockerCli)) {
    Warn "没有检测到 Docker，尝试自动安装"

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Say ""
        Say "  你的系统没有 winget（需要 Windows 10 1809 以上），无法自动安装。请："
        Say "    打开 https://www.docker.com/products/docker-desktop/ 下载安装"
        Say "    安装时保持勾选「Use WSL 2 instead of Hyper-V」"
        Start-Process "https://www.docker.com/products/docker-desktop/"
        Die "装好 Docker Desktop 后，重启电脑，再重新双击 start-windows.bat。"
    }

    Say "  用 winget 安装 Docker Desktop（会弹 UAC 授权框，请点「是」）..."
    winget install --id Docker.DockerDesktop -e --accept-source-agreements --accept-package-agreements

    Refresh-Path

    if (-not (Test-DockerCli)) {
        Say ""
        Warn "Docker 已安装，但当前窗口还找不到它。"
        Die "这是正常的：Docker Desktop 首次安装后必须【重启电脑】。请重启后重新双击 start-windows.bat，不需要再装一次。"
    }
    Ok "Docker 已安装"

    Say ""
    Warn "重要：首次安装 Docker Desktop 后，通常需要【重启电脑】它才能真正运行。"
    Say "  如果接下来启动失败，请重启后再双击一次 start-windows.bat。"
    Say ""
} else {
    Ok "Docker 已安装（$((docker --version) -join '')）"
}

# ---------- 2. 检查 Docker 是否在运行 ----------
Say ""
Say "[2/5] 检查 Docker 是否已启动..."

# 注意：不能用 $LASTEXITCODE 判断命令是否存在，命令不存在时它会保留上一次的旧值，
# 导致误报"正在运行"。
function Test-DockerEngine {
    if (-not (Test-DockerCli)) { return $false }
    docker info *> $null
    return ($LASTEXITCODE -eq 0)
}

if (-not (Test-DockerEngine)) {
    Warn "Docker 没在运行，正在帮你启动 Docker Desktop..."
    $exe = @(
        (Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe"),
        (Join-Path $env:LOCALAPPDATA "Docker\Docker Desktop.exe")
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $exe) {
        Die "找不到 Docker Desktop 程序。请从开始菜单手动打开它；如果是刚装好，请先重启电脑。"
    }

    Start-Process $exe
    Say "  等待 Docker 就绪（首次启动通常 1-2 分钟，最多等 3 分钟）..."
    Say "  这一步慢是正常的：Docker 要先启动一个虚拟机，不是卡住了。"

    $ready = $false
    $startedAt = Get-Date
    while (((Get-Date) - $startedAt).TotalSeconds -lt 180) {
        if (Test-DockerEngine) { $ready = $true; break }
        $elapsed = [int]((Get-Date) - $startedAt).TotalSeconds
        Write-Host "`r  等待中… 已 $elapsed 秒" -NoNewline
        Start-Sleep -Seconds 3
    }
    Write-Host "`r                              `r"

    if (-not $ready) {
        Die "等了 3 分钟 Docker 还没就绪。请手动打开 Docker Desktop，等托盘图标不再转动后重新双击本文件。如果是刚装完，请先重启电脑。"
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
    try {
        # 显式 UTF-8 无 BOM + LF：BOM 可能让第一行失效，CRLF 则没必要
        [System.IO.File]::WriteAllText($envPath, ($lines -join "`n") + "`n", (New-Object System.Text.UTF8Encoding($false)))
    } catch {
        Set-Content -Path $envPath -Value $lines -Encoding UTF8
    }
    Ok "已生成随机密钥并写入 .env"
}

# ---------- 4. 启动服务 ----------
Say ""
Say "[4/5] 启动服务..."
if (-not (Test-DockerCli)) {
    Die "找不到 docker 命令。请重启电脑后重新双击本文件。"
}

docker image inspect drawbridge:local *> $null
$hasImage = ($LASTEXITCODE -eq 0)

if ($hasImage -and -not $Rebuild) {
    docker compose up -d
} else {
    Say "  首次运行要构建镜像，约 3-8 分钟，中途别关窗口..."
    docker compose up -d --build
}
if ($LASTEXITCODE -ne 0) {
    Die "启动失败。常见原因：3000 端口被占用、Docker 没有真正就绪。用 docker compose logs 看详情。"
}

# ---------- 5. 等待就绪 ----------
Say ""
Say "[5/5] 等待服务就绪..."
$healthy = $false
foreach ($i in 1..40) {
    $status = ""
    try { $status = (& docker inspect --format "{{.State.Health.Status}}" drawbridge 2>$null) } catch { $status = "" }
    if ($status -eq "healthy") { $healthy = $true; break }
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 3
}
Say ""

if (-not (Test-Path $envPath)) {
    Die "启动脚本没有正确写入 .env，请检查磁盘权限后重试。"
}
$loginKey = ((Get-Content $envPath | Where-Object { $_ -match "^$KeyName=" } | Select-Object -Last 1) -replace "^$KeyName=", "").Trim()

if ($healthy) {
    Ok "服务已就绪"
} else {
    Warn "服务已启动，但健康检查还没通过。可以稍等片刻，或运行 docker compose logs -f 看日志。"
}

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
