# SingulariX

## 一键安装

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/yuyuyuyu52/SingulariX/main/singularix.sh)
```

```bash
bash <(wget -qO- https://raw.githubusercontent.com/yuyuyuyu52/SingulariX/main/singularix.sh)
```

安装限制：仅支持 root 用户安装与管理（普通用户会被拒绝执行安装流程）。

默认会在安装流程中自动尝试开启 BBR（需要 root 权限）。
如需关闭该行为，可执行：
```bash
SGX_AUTO_BBR=0 bash <(curl -fsSL https://raw.githubusercontent.com/yuyuyuyu52/SingulariX/main/singularix.sh)
```

SingulariX 是面向 Linux VPS 与容器环境的代理部署项目，核心能力由 Shell 脚本与 Node.js 容器入口共同提供。

## 核心特性
- 双内核支持：Xray 与 Sing-box。
- 多协议支持：VLESS、Hysteria2、Shadowsocks-2022、Tuic、VMess、Socks5 等。
- 脚本部署：支持常见 Linux 发行版与 `amd64`/`arm64` 架构。
- 容器入口：提供 Node.js 服务端入口，支持 WebSocket 转发与订阅信息输出。

## 当前目录结构
```text
.
├── README.md
├── singularix.sh
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

### 交互菜单功能
- `[1]` 安装 VLESS-Reality (TCP)。
- `[2]` 安装 Hysteria2。
- `[3]` 安装 TUIC。
- `[4]` 安装 Shadowsocks-2022。
- `[5]` 安装 VLESS-WS。
- `[6]` 安装 VMess-WS。
- `[7]` 安装 SOCKS5。
- `[8]` 查看节点与状态。
- `[9]` 重启服务。
- `[10]` 更新内核（Xray/Sing-box）。
- `[11]` 彻底卸载。
- `[12]` 开启 BBR。
- `[13]` 检测 IP 纯净度。

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

### 2.1 订阅输出格式
执行 `./singularix.sh list` 时会同时输出：
- Base64 订阅链接：适合大多数通用导入场景。
- ShadowBox/Sing-box 订阅链接：自动生成或回退为在线转换链接。
- Clash 订阅链接：自动生成或回退为在线转换链接。
- 原始 URI 链接：逐条节点明文链接集合。

可通过环境变量 `SUBCONVERTER_URL` 自定义转换服务地址（默认 `https://api.v1.mk/sub`）。

