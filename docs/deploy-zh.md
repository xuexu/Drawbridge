# Drawbridge 部署教程：从零搭一个图片生成 API

本教程把 Drawbridge 部署到一台 Linux 服务器上，最终得到一个可以用 `POST /v1/images/generations`
调用的图片生成 API。

> 想在**自己的 Windows 或 Mac 电脑**上跑，不用看这份，去看
> **[本机运行教程 docs/local-zh.md](local-zh.md)** —— 那份是给新手写的，双击就能启动。

> [!WARNING]
> 开始之前请确认你读过 [README](../README.md) 里的风险须知。**请勿使用你自己的重要账号或高价值账号**，
> 逆向接口存在账号被限制或封禁的风险。

## 0. 服务器要求

- 一台能访问 `chatgpt.com` 和 `auth.openai.com` 的 Linux 服务器。
- **不要选中国大陆地区**，会连不上或极不稳定。
- 最低 1 核 2G / 20G 盘即可起步；如果要起 WARP 稳定代理链路，建议 2 核 4G。
- 系统推荐 Ubuntu 22.04 / 24.04。

购买哪家的服务器本教程不做推荐，按上面的条件自行选择即可。你只需要能 SSH 登录并拿到公网 IP。

## 1. 安装 Docker

以 Ubuntu 24.04 为例：

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo docker run hello-world
```

看到 `Hello from Docker!` 就装好了。

## 2. 拉取代码

```bash
git clone <本仓库地址> drawbridge
cd drawbridge
```

## 3. 设置密钥（这一步不能跳过）

**Drawbridge 和上游最大的区别就在这里**：上游把默认密钥 `chatgpt2api` 直接写在仓库里，
很多人照着教程部署完，管理面板就一直挂在公网上用着一个全网都知道的密钥。

Drawbridge 改成：**密钥为空、或者是 `chatgpt2api` / `drawbridge` / `changeme` / `password` / `admin`
这类公开默认值时，服务直接拒绝启动。**

生成一个随机密钥并写进 `.env`：

```bash
cp .env.example .env
echo "CHATGPT2API_AUTH_KEY=$(openssl rand -hex 24)" >> .env
```

记下这个密钥，后面登录面板和调 API 都要用。想查看：

```bash
grep CHATGPT2API_AUTH_KEY .env
```

## 4. 启动

```bash
docker compose up -d
```

第一次会构建镜像，需要几分钟。构建完成后看状态：

```bash
docker compose ps
```

`STATUS` 那一列应该显示 `Up ... (healthy)`。如果一直不是 healthy：

```bash
docker compose logs -f
```

## 5. 打开面板并登录

浏览器访问：

```
http://你的服务器IP:3000
```

在登录页填入第 3 步那个密钥。

> 如果打不开，先确认云厂商的安全组／防火墙放通了 **3000** 端口。

## 6. 导入 ChatGPT 账号

1. 侧栏进入「号池管理」。
2. 点「导入」→ 选择 **OAuth 登录**。
3. 复制页面上给出的 URL，在**已经登录了 GPT 账号的浏览器**里打开它并完成授权。
4. 把回调地址粘贴回面板，点「完成导入」。
5. 账号出现在列表里，额度会自动刷新出来。

建议先只导入一个测试账号跑通流程，不要一上来就批量导入。

## 7. 调用 API

图片生成：

```bash
curl http://你的服务器IP:3000/v1/images/generations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer 你的密钥" \
  -d '{"model":"gpt-image-2","prompt":"一张极简产品海报","n":1}'
```

图片编辑：

```bash
curl http://你的服务器IP:3000/v1/images/edits \
  -H "Authorization: Bearer 你的密钥" \
  -F "model=gpt-image-2" \
  -F "prompt=把这张图改成赛博朋克夜景风格" \
  -F "image=@./input.png"
```

也可以把 `http://你的服务器IP:3000/v1` 作为 OpenAI 兼容地址填进 Cherry Studio、New API 等客户端。

## 8. 图片链路被 Cloudflare 拦截怎么办

如果生图经常失败、日志里出现 403 或 Cloudflare 相关内容，可以启用附带的稳定代理方案：

```bash
docker compose -f docker-compose.warp.yml up -d --build
```

它会额外启动 `warp-proxy`、`privoxy`、`flaresolverr` 三个容器。默认只让上游请求走这条链路。

## 9. 安全提醒

部署完务必检查这几件事：

1. **不要把 3000 端口直接暴露到公网。** 更稳妥的做法是只监听本机、前面挂 Nginx 配 TLS：
   把 `docker-compose.yml` 里的端口改成 `127.0.0.1:3000:8080`。
2. **`.env` 和 `config.json` 不要提交到任何仓库**，里面有你的密钥。
3. **`./data` 目录里是账号凭据**，备份要加密存放。
4. 定期更新：`git pull && docker compose up -d --build`。

## 10. 常见问题

**Q：`docker compose up -d` 报 `please set CHATGPT2API_AUTH_KEY`**
第 3 步没做，或者 `.env` 不在 `docker compose` 的执行目录下。

**Q：启动时报 `auth-key 未设置，或仍在使用随仓库公开的默认值`**
你在 `config.json` 里填的是被拉黑的公开默认值。换一个随机密钥。

**Q：访问 3000 端口超时**
云厂商安全组／防火墙没放通，或者服务没起来（`docker compose ps` 看状态）。

**Q：容器状态一直是 `starting` 而不是 `healthy`**
`docker compose logs -f` 看报错。常见原因是外部依赖（数据库、代理）没就绪。

**Q：改了 `config.json` 但没生效**
`config.json` 是挂载进容器的，改完要重启：`docker compose restart`。

**Q：想换端口**
改 `docker-compose.yml` 里的 `"3000:8080"` 左侧数字，例如 `"8080:8080"`。右侧的 `8080`
是容器内端口（非 root 用户无法绑定 80），不要改。
