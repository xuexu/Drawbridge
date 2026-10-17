# 在自己电脑上跑起来（Windows / Mac 保姆级教程）

这份教程假设你**什么都不懂**，只需要照着做。全程不用懂编程，不用改代码。

Windows 和 Mac 的命令不一样，每一步我都会分开写，**你只照着你自己系统的那些行复制粘贴就行**。

> [!WARNING]
> 开始之前请先知道：这是逆向 ChatGPT 官网接口做的工具，**有账号被限制或封禁的风险**。
> 请先拿一个**不重要的账号**试，别用你的主力号。详细风险见 [README](../README.md)。

---

## 目录

- [最简单的办法：双击一下就完事](#最简单的办法双击一下就完事)
- [如果双击不行：手动三步](#如果双击不行手动三步)
- [完全手动：一步一步来](#完全手动一步一步来)
- [启动之后要做什么](#启动之后要做什么)
- [怎么停止、怎么重启、怎么彻底删掉](#怎么停止怎么重启怎么彻底删掉)
- [遇到问题看这里](#遇到问题看这里)

---

## 最简单的办法：双击一下就完事

我在项目里放了两个启动脚本，**会自动帮你检查环境**：

- 没装 Docker → 帮你装
- 装了但没启动 → 帮你启动，并等到能用为止
- 没有密钥 → 自动生成一个
- 全都好了 → 启动服务，并把登录密钥和网址打给你

### Windows

双击项目文件夹里的 **`start-windows.bat`**

会弹出一个黑色的命令行窗口，自己跑。中途如果弹出「是否允许此应用对你的设备进行更改」，点**「是」**。

### Mac

双击项目文件夹里的 **`start-mac.command`**

> **Mac 第一次双击可能不让打开**，提示「无法打开，因为来自身份不明的开发者」或「Apple 无法检查其是否包含恶意软件」。
> 这是 Mac 的安全机制，不是文件有问题。**解决办法**：
> 1. 在文件上**点右键** → 选「打开」→ 再点一次「打开」
> 2. 或者：打开「系统设置」→「隐私与安全性」→ 往下拉到「安全性」→ 点「仍要打开」
>
> 如果双击后**什么都没发生**（只是用文本编辑器打开了它），说明文件少了执行权限。
> 打开终端，粘贴这两行：
> ```bash
> cd ~/Downloads/Drawbridge     # ← 换成你实际放项目的文件夹
> chmod +x start-mac.command
> ```
> 然后再双击一次。

### 脚本跑完你会看到什么

```
================================================
  🎉 启动完成
================================================

  打开面板：   http://localhost:3000

  登录密钥：   xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

  下一步：进面板 →「号池管理」→「导入」→ OAuth 登录，
         把 GPT 账号导进去才能生成图片。
```

**把这个密钥复制下来存好**，登录要用。

> 脚本第一次运行要下载和构建，**大约 3 到 8 分钟**，窗口里会长时间不动，这是正常的，别关窗口。

---

## 如果双击不行：手动三步

不用管为什么，照着复制粘贴就行。

### 第 1 步：确认 Docker 装好并且开着

Docker 是这个项目的运行环境，必须先装。

- **Windows**：去 <https://www.docker.com/products/docker-desktop/> 下载 Windows 版，安装时**保持勾选 `Use WSL 2 instead of Hyper-V`**。装完**重启一次电脑**，然后从开始菜单打开「Docker Desktop」，等右下角托盘里的小鲸鱼图标**不再转圈**。
- **Mac**：同样网址下载 Mac 版，注意选对芯片（M1/M2/M3 选「Apple Silicon」，老 Intel 机器选「Intel Chip」）。装完打开「Docker」，等顶部菜单栏的小鲸鱼图标**不再转圈**。

### 第 2 步：打开终端，进入项目文件夹

**Windows**：按 `Win` 键 → 输入 `powershell` → 点「Windows PowerShell」

**Mac**：按 `Command + 空格` → 输入 `终端` 或 `terminal` → 回车

打开后，粘贴这一行（**把路径换成你实际存放项目的文件夹**）：

**Windows**（注意反斜杠）：
```powershell
cd "$env:USERPROFILE\Downloads\Drawbridge"
```

**Mac**：
```bash
cd ~/Downloads/Drawbridge
```

### 第 3 步：启动

**两个系统都是这一行**：

```
docker compose up -d
```

第一次会构建镜像，等几分钟。看到类似这样的输出就是成功：

```
 Container drawbridge  Started
```

---

## 完全手动：一步一步来

适合你想弄明白每一步在干什么，或者脚本失败了要排查。

### 第 0 步：先认识两个东西

- **Docker**：一个「应用打包盒」。这个项目依赖很多软件，Docker 把它们全打包好了，你不需要自己装 Python、装数据库。
- **终端 / PowerShell**：一个用打字下命令的窗口。下面所有命令都是粘进去按回车。

### 第 1 步：装 Docker Desktop

同上面「手动三步」的第 1 步。**装完务必重启电脑**（Windows 尤其重要），然后打开 Docker Desktop，等图标不转为止。

验证装好了：

```
docker --version
```

应该输出类似 `Docker version 29.x.x, build xxx`。如果提示「不是内部或外部命令」或者 `command not found`，说明没装好或者要重启。

### 第 2 步：把项目下载到电脑上

**方式 A：用 Git 下载**（推荐，以后更新方便）

先确认装了 Git：

```
git --version
```

如果提示找不到，Windows 去 <https://git-scm.com/download/win> 装，Mac 粘贴 `xcode-select --install` 按提示装。

然后：

```bash
cd ~/Downloads
git clone https://github.com/Frank-789/Drawbridge.git
cd Drawbridge
```

**方式 B：直接下载压缩包**

在 GitHub 页面点绿色 `Code` → `Download ZIP` → 解压 → 用第 2 步的方法进到解压出来的文件夹。

### 第 3 步：进到项目文件夹

确认你现在在正确的位置：

```
ls
```

（Windows 上如果 `ls` 不好使，用 `dir`）

你应该能看到 `docker-compose.yml`、`README.md` 这些文件。**看不到就说明文件夹进错了**，重新 `cd`。

### 第 4 步：生成登录密钥

这个项目**必须**有一个只有你知道的密钥，否则启动会失败（这是故意的，防止别人也能进你的面板）。

**Mac** —— 复制这**两行**，一次粘贴：

```bash
cp .env.example .env
echo "CHATGPT2API_AUTH_KEY=$(openssl rand -hex 24)" >> .env
```

**Windows** —— 复制这**三行**，一次粘贴：

```powershell
$bytes = New-Object byte[] 24
[System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
Add-Content .env ("CHATGPT2API_AUTH_KEY=" + (-join ($bytes | ForEach-Object { $_.ToString("x2") })))
```

> Windows 没有 `openssl`，所以用上面这段。如果你更喜欢用记事本：把 `.env.example` 复制一份改名成 `.env`，用记事本打开，在最后加一行
> `CHATGPT2API_AUTH_KEY=` 后面接一串你自己瞎敲的、**至少 24 位**的字母数字。
> 用记事本保存**不会有问题**，Windows 的换行符 Docker 能正确处理（已实测）。

### 第 5 步：启动

```
docker compose up -d
```

第一次会构建，**3 到 8 分钟**，中途像卡住一样是正常的。别关窗口。

### 第 6 步：确认起来了

```
docker compose ps
```

看 `STATUS` 那一列，应该显示 `Up ... (healthy)`。

- 显示 `(health: starting)` → 再等半分钟，重新跑一次这条命令
- 显示 `Restarting` 或者根本看不到容器 → 去看[遇到问题](#遇到问题看这里)
- 提示 `failed to connect to the docker API` → **Docker Desktop 没启动**，去打开它，等图标不转再重试

### 第 7 步：打开面板

浏览器打开：

**<http://localhost:3000>**

### 第 8 步：取出你的密钥，登录

**Mac**：
```bash
grep CHATGPT2API_AUTH_KEY .env
```

**Windows**：
```powershell
Select-String CHATGPT2API_AUTH_KEY .env
```

把等号后面的那串复制下来，粘贴到面板的登录框里。

### 第 9 步：导入一个 GPT 账号

面板左侧「**号池管理**」→ 点「**导入**」→ 选「**OAuth 登录**」→ 页面上会给你一个网址，**复制它，在已经登录了 GPT 账号的浏览器里打开**，完成授权，然后把跳转后的地址粘回面板，点「完成导入」。

导入成功后账号会出现在列表里，额度会自动刷新出来。

> ⚠️ 建议**先拿一个不重要的账号**试通流程。别一上来就导主力号。

### 第 10 步：生成第一张图

**最简单的方式**：面板上的「在线画图」，输入提示词直接生成，不用敲命令。

**想用命令行调 API**：

**Mac**（可以多行粘贴）：
```bash
KEY=$(grep CHATGPT2API_AUTH_KEY .env | cut -d= -f2)
curl http://localhost:3000/v1/images/generations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $KEY" \
  -d '{"model":"gpt-image-2","prompt":"一只漂浮在太空里的猫","n":1}'
```

**Windows**（注意是 `curl.exe`，不是 `curl`，原因见[常见问题](#遇到问题看这里)）：
```powershell
$KEY = ((Select-String CHATGPT2API_AUTH_KEY .env).Line -split "=")[1]
$body = '{"model":"gpt-image-2","prompt":"a cat floating in space","n":1}'
curl.exe -X POST http://localhost:3000/v1/images/generations -H "Content-Type: application/json" -H "Authorization: Bearer $KEY" -d $body
```

成功后返回一大串 JSON，里面 `b64_json` 字段就是图片数据（Base64 编码）。

---

## 启动之后要做什么

1. **导入至少一个 GPT 账号**，否则无法生成图片（第 9 步）
2. **存好你的密钥**，登录和调 API 都要用
3. 想给别的软件用（Cherry Studio、New API 等）：填 API 地址 `http://localhost:3000/v1`，密钥填你那个密钥
4. **别忘了这是有风险的工具**，别用主力账号

---

## 怎么停止、怎么重启、怎么彻底删掉

先进入项目文件夹（第 3 步）。

**暂时停止**（数据保留，下次秒开）：
```
docker compose stop
```

**重新启动**：
```
docker compose start
```

**改了配置想让它生效**：
```
docker compose restart
```

**升级到最新版**：
```bash
git pull
docker compose up -d --build
```

**彻底删掉容器**（`data/` 文件夹里的账号数据**会保留**）：
```
docker compose down
```

**连数据一起删干净**（⚠️ 会删掉所有导入的账号，不可恢复）：
- Mac：`rm -rf data && docker compose down`
- Windows：`Remove-Item -Recurse -Force data; docker compose down`

**换一个登录密钥**：把 `.env` 里 `CHATGPT2API_AUTH_KEY=` 后面改成新的一串，然后 `docker compose restart`。

---

## 遇到问题看这里

### `docker: command not found` / 「不是内部或外部命令」

Docker 没装，或者装了但没重启电脑。**Windows 装完必须重启一次**。

### `failed to connect to the docker API ... check if the daemon is running`

**这是最常见的问题**：Docker 装了但**没启动**。

- Windows：开始菜单打开「Docker Desktop」，等右下角小鲸鱼图标**不再转圈**
- Mac：启动台打开「Docker」，等右上角小鲸鱼图标**不再转圈**

或者干脆直接双击 `start-windows.bat` / `start-mac.command`，脚本会帮你启动并等它就绪。

### Mac：双击 `start-mac.command` 没反应 / 提示来自身份不明的开发者

见[最简单的办法](#最简单的办法双击一下就完事)里的 Mac 说明（右键打开，或先 `chmod +x`）。

### Windows：`curl` 报错，说什么 `Invoke-WebRequest` 或者参数不认识

Windows 自带的 PowerShell 里，`curl` 其实是另一个命令的**别名**，不是真的 curl。所以要用 **`curl.exe`**（带 `.exe`）。教程里的命令已经写好了。

### Windows：安装 Docker 时提示要 WSL2

按提示做就行。如果没自动装，在**管理员** PowerShell 里粘贴：

```powershell
wsl --install
```

然后重启电脑。

### Windows：装完 Docker 第一次启动失败

Docker Desktop 首次安装后通常**需要注销或重启一次 Windows** 才能正常工作。重启后重试。

### 启动时报 `auth-key 未设置，或仍在使用随仓库公开的默认值`

你的 `.env` 里没有密钥，或者填的是 `chatgpt2api` 这种公开默认值。按第 4 步重新生成一个。

### 访问 `localhost:3000` 打不开 / 一直转圈

先确认服务起来了：

```
docker compose ps
```

要显示 `(healthy)`。如果不是，看日志：

```
docker compose logs -f
```

（按 `Ctrl + C` 退出日志）

### 提示 3000 端口被占用

有别的东西在用 3000 端口。改一下：打开 `docker-compose.yml`，把

```yaml
- "3000:8080"
```

改成

```yaml
- "3001:8080"
```

然后 `docker compose up -d`，浏览器改用 `http://localhost:3001`。

### 登录时提示「密钥无效或已失效」

- 密钥复制多了空格或换行 → 重新用第 8 步的命令取一次
- 你改过 `.env` 但没重启 → `docker compose restart`

### 想改端口、想换密钥、想清空数据

见上面[启动之后要做什么](#启动之后要做什么)和[怎么停止、怎么重启、怎么彻底删掉](#怎么停止怎么重启怎么彻底删掉)。

### 其他看不懂的报错

```
docker compose logs -f
```

把输出截图，拿去问 AI 或者发 issue。

---

## 附：不用 Docker 可以吗？

可以，但要自己装 Python 3.13 和前端构建工具，对新手麻烦很多。自己装的话：

```bash
uv sync
CHATGPT2API_AUTH_KEY=$(openssl rand -hex 24) uv run main.py
```

前端另外开一个终端：`cd web && bun install && bun run dev`。

**新手建议还是用 Docker**，省掉装环境的所有麻烦。

---

## 附：你的东西都存在哪

| 位置 | 内容 | 要不要备份 |
|:--|:--|:--|
| `data/` | 导入的账号、图片、日志 | **要**，这里面是你的账号 |
| `.env` | 登录密钥 | 记下来就行 |
| `config.json` | 面板里的各种设置 | 改过设置就备份 |

这些都在项目文件夹里，都在你自己电脑上，不会上传到任何地方。

> 补充一句：`.env` 和 `data/` 已经被 `.gitignore` 排除，**不会**被你误提交到 GitHub。
