# SingulariX

SingulariX 是面向 Linux VPS 与容器环境的代理部署项目，核心能力由 Shell 脚本与 Node.js 容器入口共同提供。

## 核心特性
- 双内核支持：Xray 与 Sing-box。
- 多协议支持：VLESS、Hysteria2、Shadowsocks-2022、Tuic、VMess、Socks5 等。
- 脚本部署：支持常见 Linux 发行版与 `amd64`/`arm64` 架构。
- 容器入口：提供 Node.js 服务端入口，支持 WebSocket 转发与订阅信息输出。

## 当前目录结构
```text
.
├── index.html
├── README.md
├── singularix.sh
├── .github/
│   └── workflows/
│       ├── sap-multi-account-deploy.yml
│       └── sap-multi-account-keepalive.yml
└── platforms/
	└── container/
		└── nodejs/
			├── index.js
			├── package.json
			└── start.sh
```

## 脚本入口说明
- `singularix.sh` 是仓库根入口脚本。
- 真实核心逻辑位于 `platforms/container/nodejs/start.sh`。
- 默认直接运行 `./singularix.sh` 会进入交互菜单（选择安装方案）。
- 传入环境变量或参数时，会走无交互模式并直接委托核心脚本。

### 交互菜单功能
- `[1]` 极致伪装 (Reality)：自动设为 443 端口。
- `[2]` 暴力提速 (Hy2)：自动随机 UDP 端口。
- `[3]` 黄金组合：Reality + Hy2。
- `[4]` 全家桶：一口气开启 6 种主流协议。
- `[5]` 查看节点与状态。
- `[6]` 重启服务。
- `[7]` 更新内核（Xray/Sing-box）。
- `[8]` 彻底卸载。
- `[9]` 开启 BBR。
- `[10]` 检测 IP 纯净度。

## 使用方式

### 1. 推荐入口（交互菜单）
```bash
chmod +x singularix.sh
./singularix.sh
```

首次运行 `./singularix.sh` 会自动安装快捷命令 `sgx`（普通用户安装到 `~/.local/bin/sgx`）。

如果提示找不到 `sgx`，先执行：
```bash
export PATH="$HOME/.local/bin:$PATH"
```

之后可以直接：
```bash
sgx
```

注意：`0`、`1`、`2` 这些数字是菜单内选项，不是 Shell 命令。请先进入脚本菜单再输入。

### 2. 无交互执行示例
```bash
vlpt=443 hypt=8443 ./singularix.sh
```

### 3. 管理命令模式
```bash
./singularix.sh list   # 查看节点与状态
./singularix.sh res    # 重启服务
./singularix.sh upx    # 升级 Xray
./singularix.sh ups    # 升级 Sing-box
./singularix.sh del    # 彻底卸载
```

### 3.1 订阅输出格式
执行 `./singularix.sh list` 时会同时输出：
- Base64 订阅链接：适合大多数通用导入场景。
- ShadowBox/Sing-box 订阅链接：自动生成或回退为在线转换链接。
- Clash 订阅链接：自动生成或回退为在线转换链接。
- 原始 URI 链接：逐条节点明文链接集合。

可通过环境变量 `SUBCONVERTER_URL` 自定义转换服务地址（默认 `https://api.v1.mk/sub`）。

### 4. 直接执行核心脚本
```bash
chmod +x platforms/container/nodejs/start.sh
./platforms/container/nodejs/start.sh
```

### 5. Node.js 容器入口
```bash
cd platforms/container/nodejs
npm install
npm start
```

## 常用环境变量
- `uuid`：自定义 UUID。
- `DOMAIN`：节点分享域名。
- `PORT`：Node.js HTTP 服务端口。
- `NAME`：节点名称后缀。

## 维护说明
- Workflow 文件已采用语义化命名，便于区分“自动部署”与“仅保活”。
- 建议后续新增脚本优先复用 `platforms/container/nodejs/start.sh`，避免再次出现多份同源逻辑分叉。
