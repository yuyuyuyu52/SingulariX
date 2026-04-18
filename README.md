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
- 根入口脚本会自动委托执行核心脚本，减少重复实现和维护成本。

## 使用方式

### 1. 本地执行
```bash
chmod +x singularix.sh
./singularix.sh
```

### 2. 直接执行核心脚本
```bash
chmod +x platforms/container/nodejs/start.sh
./platforms/container/nodejs/start.sh
```

### 3. Node.js 容器入口
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
