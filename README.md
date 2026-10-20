<h1 align="center">Drawbridge</h1>

<p align="center">把 ChatGPT 官网的图片生成能力，桥接成一个 OpenAI 兼容 API。自托管、带网页画图台与号池管理。</p>

---

## 它是怎么工作的

```mermaid
flowchart LR
    subgraph clients["你的客户端"]
        direction TB
        A1["Cherry Studio"]
        A2["New API"]
        A3["网页画图台"]
        A4["curl / 自己的代码"]
    end

    subgraph bridge["Drawbridge（跑在你自己电脑或服务器上）"]
        direction TB
        B1["OpenAI 兼容接口<br/>/v1/images/generations<br/>/v1/images/edits"]
        B2["号池管理<br/>多账号轮换 · 额度刷新"]
        B3["管理面板 :3000<br/>画图 · 导入账号 · 查看日志"]
    end

    subgraph upstream["ChatGPT 官网"]
        C1["图片生成 / 图片编辑"]
    end

    A1 --> B1
    A2 --> B1
    A4 --> B1
    A3 --> B3
    B1 --> B2
    B3 --> B2
    B2 --> C1

    style bridge fill:#eef2ff,stroke:#6366f1,stroke-width:2px
    style clients fill:#f8fafc,stroke:#cbd5e1
    style upstream fill:#f0fdf4,stroke:#22c55e
```

一句话：**你用什么客户端都行，Drawbridge 在中间负责把请求翻译成 ChatGPT 官网能听懂的形式，并帮你轮换多个账号。**

---

## 这是什么

Drawbridge 把 ChatGPT 官网的图片生成能力，桥接成一个标准的 OpenAI 兼容 API。

用自己的 ChatGPT 账号，通过 `POST /v1/images/generations` 和 `POST /v1/images/edits` 就能画图、改图，
可以直接接进 Cherry Studio、New API 以及各种支持 OpenAI 接口的客户端。自带一个网页画图工作台和号池
管理面板，一条 `docker compose` 就能起服务。

它是 [chatgpt2api](https://github.com/basketikun/chatgpt2api) 的**安全加固分支**。上游功能完整，
但默认配置里有几个会真正伤到使用者的问题，这个分支把它们修掉了：

| 问题 | 上游默认行为 | Drawbridge 的处理 |
|:--|:--|:--|
| 管理面板裸奔 | 默认密钥 `chatgpt2api` 写在仓库里，教程也让你直接用 | 密钥为空或是公开默认值时**直接拒绝启动** |
| 图片 URL 的 SSRF | 普通用户密钥即可让服务器请求内网、云元数据地址 | 非公网地址一律拒绝，重定向**逐跳**校验 |
| 任意文件下载 | `/files/{path}` 无鉴权，可遍历下载他人产出的 PPT/PSD | 加鉴权并校验任务归属 |
| 密钥回传浏览器 | 设置接口明文返回 AI key、R2 密钥、WebDAV 密码 | 统一打码返回，回写时自动还原 |
| 凭据不校验证书 | OAuth 换 token 时硬编码 `verify=False` | 移除，交由配置控制 |
| 容器以 root 运行 | 无 `USER`，无健康检查 | 非 root 运行 + `HEALTHCHECK` |
| 默认拉上游镜像 | compose 用 `ghcr.io/...:latest`，跑的不是本仓库代码 | 改为从本仓库构建 |

> [!WARNING]
> **风险须知**
>
> 本项目涉及对 ChatGPT 官网文本生成、图片生成与图片编辑等相关接口的逆向研究，仅供个人学习、
> 技术研究与非商业性技术交流使用。
>
> - **使用的账号有被限制、临时封禁或永久封禁的风险。请勿使用你自己的重要账号、常用账号或高价值账号。**
> - 严禁用于任何商业用途、盈利性使用、批量操作、自动化滥用或规模化调用。
> - 严禁用于破坏市场秩序、恶意竞争、套利倒卖、二次售卖相关服务，以及任何违反 OpenAI 服务条款或当地法律法规的行为。
> - 严禁用于生成、传播或协助生成违法、暴力、色情、未成年人相关内容，或用于诈骗、欺诈、骚扰等非法或不当用途。
> - 使用者应自行承担全部风险，包括但不限于账号被限制、封禁以及因违规使用所导致的法律责任。
> - 使用本项目即视为你已充分理解并同意本免责声明全部内容。

## 快速开始

### 方式一：一键启动（推荐给新手）

项目里带了自动启动脚本，**会自己检查 Docker 装没装、开没开，缺什么补什么**，
然后启动服务并把登录密钥打给你。

| 你的系统 | 怎么做 |
|:--|:--|
| **Windows** | 双击 `start-windows.bat` |
| **macOS** | 双击 `start-mac.command` |

跑完窗口里会直接告诉你面板地址和登录密钥。第一次要构建镜像，约 3–8 分钟。

> 不熟悉终端、不知道 Docker 是什么？看 **[保姆级教程 docs/local-zh.md](docs/local-zh.md)**，
> Windows 和 Mac 的每一步命令都分开写好了，复制粘贴即可。

### 方式二：手动命令

```bash
git clone https://github.com/Frank-789/Drawbridge.git
cd Drawbridge

# 先生成并设置一个随机密钥 —— 不做这步服务会拒绝启动
cp .env.example .env
echo "CHATGPT2API_AUTH_KEY=$(openssl rand -hex 24)" >> .env

# 启动
docker compose up -d
```

- Web 面板：`http://localhost:3000`
- API 地址：`http://localhost:3000/v1`
- 数据目录：`./data`

用 `grep CHATGPT2API_AUTH_KEY .env` 取出密钥，在页面上登录。

### 部署到 Linux 服务器

见 **[docs/deploy-zh.md](docs/deploy-zh.md)**（含服务器选购条件、防火墙、WARP 代理链路、常见故障）。

### 如果图片链路经常被 Cloudflare 拦截

可以启用附带的 WARP + Privoxy + FlareSolverr 方案：

```bash
docker compose -f docker-compose.warp.yml up -d --build
```

该 compose 会启动 `warp-proxy`、`privoxy`、`flaresolverr`、`init-config` 和主服务 `app`。
默认只让上游 OpenAI / ChatGPT 请求走稳定代理，辅助链路不受影响。

### 本地开发

```bash
# 后端
uv sync
CHATGPT2API_AUTH_KEY=$(openssl rand -hex 24) uv run main.py

# 前端（另开一个终端）
cd web
bun install
bun run dev
```

### 存储后端

通过 `STORAGE_BACKEND` 切换：`json`（默认）、`sqlite`、`postgres`（需 `DATABASE_URL`）、
`git`（需 `GIT_REPO_URL` 与 `GIT_TOKEN`）。

## 功能

- 兼容 `POST /v1/images/generations`、`POST /v1/images/edits`
- 兼容面向图片场景的 `POST /v1/chat/completions`、`POST /v1/responses`
- `GET /v1/models` 返回 `gpt-image-2`、`gpt-image-2.5`、`codex-gpt-image-2`、`codex-gpt-image-2.5`、`auto`、`gpt-5` 系列等
- 支持 `n` 返回多张结果；支持生成可编辑 PPT / PSD
- 支持 ChatGPT Images 2.5：官网链路 `gpt-image-2.5`（上游模型名可单独配置，留空跟随 `gpt-image-2`）；Codex 链路 `codex-gpt-image-2.5`（支持 `plus` / `team` / `pro` 前缀，工具模型默认 `gpt-image-2.5-flare`，可切换 `gpt-image-2.5-sunburst`，质量档额外支持 `xhigh` / `max`）
- 内置在线画图工作台：生成、图片编辑、多图组图编辑、历史回看
- 号池管理：自动刷新额度、轮询可用账号、失效自动剔除、四种导入方式
- 网页端配置 HTTP / HTTPS / SOCKS5 代理，支持 WARP / FlareSolverr 稳定代理运行时

## API

所有 AI 接口都需要请求头：

```http
Authorization: Bearer <你的密钥>
```

```bash
curl http://localhost:3000/v1/images/generations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <你的密钥>" \
  -d '{"model":"gpt-image-2","prompt":"一只漂浮在太空里的猫","n":1}'
```

```bash
curl http://localhost:3000/v1/images/edits \
  -H "Authorization: Bearer <你的密钥>" \
  -F "model=gpt-image-2" \
  -F "prompt=把这张图改成赛博朋克夜景风格" \
  -F "image=@./input.png"
```

完整字段说明见 [docs/deployment.md](docs/deployment.md)。

## 安全说明

- 密钥在磁盘上只存 SHA-256 哈希；管理密钥用常量时间比较。
- 图片 URL 抓取拒绝非公网地址，重定向逐跳校验，单张上限 50MB。
- 上传体积有上限，避免超大请求打满内存。
- 设置接口返回的密钥一律打码（`********`），前端回写时自动还原为已保存的真实值。
- 公开的 `/health` 未鉴权时只返回一个状态，不暴露号池数量和额度；带管理员密钥才有完整明细。
- 容器以非 root 用户运行，并带健康检查。

自行加固时仍需注意：本服务默认监听 `0.0.0.0`，**不要把 3000 端口直接暴露到公网**。
建议放在反向代理后面并配置 TLS，或只监听 `127.0.0.1`。

## 授权

MIT License。本项目是基于 [basketikun/chatgpt2api](https://github.com/basketikun/chatgpt2api) 的
衍生作品，原始版权归 kunkun 所有，按 MIT 协议保留其声明。详见 [LICENSE](LICENSE)。

## 社区

学 AI，上 L 站：[LinuxDO](https://linux.do)
