# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SingulariX is a Linux VPS proxy deployment tool. It installs and configures proxy kernels (Xray / Sing-box) on remote servers via shell scripts, then outputs ready-to-use node links and subscription URLs.

## Architecture

Two-layer entry point:

- `singularix.sh` — outer shell: interactive menu, shortcut (`sgx`) installation, kernel upgrades, BBR, uninstall. Delegates actual installation to the core script.
- `platforms/container/nodejs/start.sh` — core logic: downloads kernels, generates JSON configs, starts processes, outputs node links and subscription files.

Container entry (`platforms/container/nodejs/index.js`) provides an HTTP + WebSocket server for PaaS platforms (Railway, Render, etc.), launching `start.sh` on startup.

## Dual Kernel Model

| Kernel | Protocols | Config file |
|--------|-----------|-------------|
| Xray | VLESS-Reality (TCP), VLESS-xhttp-reality, VLESS-xhttp-enc, VLESS-ws-enc, VMess-WS, SOCKS5 | `$HOME/sgx/xr.json` |
| Sing-box | Hysteria2, TUIC, Shadowsocks-2022, AnyTLS, Any-Reality, VMess-WS, SOCKS5 | `$HOME/sgx/sb.json` |

VMess-WS and SOCKS5 go to whichever kernel is active. If only sing-box protocols are selected, only sing-box is installed (and vice versa). Mixed selections install both.

## State & Persistence

Install directory: `$HOME/sgx`. Each config value (port, UUID, keys, etc.) is persisted as a plain file named after its variable (e.g., `$HOME/sgx/hypt` stores the Hysteria2 port). On re-run without env vars, `load_saved_var()` recovers them.

Log files: `$HOME/sgx/xr.log`, `$HOME/sgx/sb.log`. Auto-truncated to ~100KB when exceeding 1MB at startup.

## Key Variables

Port variables: `vlpt`, `xhpt`, `vxpt`, `vwpt` (Xray); `hypt`, `tupt`, `anpt`, `arpt`, `sspt` (Sing-box); `vmpt`, `sopt` (shared).

Other: `uuid`, `reym` (Reality domain), `cdnym` (CDN domain), `ippz` (IP version preference), `name` (node name prefix).

## Conventions

- Terminal output strings are in English. README is in Chinese (中文).
- Shell scripts target POSIX sh (`#!/bin/sh`), not bash.
- No external dependencies beyond coreutils, curl/wget, tar, unzip, openssl.
