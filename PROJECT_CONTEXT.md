# Anthropic Claude Linux 客户端 Flatpak 打包工程完整上下文 (Session 迁移存档)

> **归档与更新时间**: 2026-10-30 (同步升级至 4.4212.0)  
> **维护工程目录**: `/var/home/jhuang/Workspace/flatpak-claude-desktop`  
> **GitHub 托管仓库**: `https://github.com/jhuang6451/flatpak-claude-desktop`  
> **在线 Pages 站点与软件源**: `https://jhuang6451.github.io/flatpak-claude-desktop/`  

---

## 1. 软件源与上游规格信息

* **官方 APT 仓库根地址**: `https://downloads.claude.ai/claude-desktop/apt/stable`
* **版本索引元数据**:
  * x86_64: `https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages.gz`
  * aarch64: `https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-arm64/Packages.gz`
* **当前最新版本**: `4.4212.0`
  * amd64 deb: `https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_4.4212.0_amd64.deb`
    * SHA-256: `4fcf658e0fc895390ab82593287281dfbce261b0ec3ea90060e82d8bfbfd7a84`
  * arm64 deb: `https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_4.4212.0_arm64.deb`
    * SHA-256: `7022dc56de30e0beb7fa0a7dc84e09aa00d7f9d4e1b7f93043b32baf75a2f6d8`
* **官方 DEB 包内部核心结构**:
  * 主执行体: `/usr/lib/claude-desktop/claude-desktop` (ELF 64-bit PIE, Electron 44.9.3)
  * Chromium SUID 沙盒: `/usr/lib/claude-desktop/chrome-sandbox` (Flatpak 下交由 `zypak-wrapper` 转发)
  * Cowork 隔离助手: `/usr/lib/claude-desktop/resources/cowork-linux-helper` (Go 静态编译，QEMU/KVM 隔离)
  * 虚拟机镜像: `/usr/lib/claude-desktop/resources/smol-bin.x64.img`
  * 共享文件系统守护进程: `/usr/lib/claude-desktop/resources/virtiofsd`
  * 图标资产: 16x16 ~ 256x256 (hicolor) 及 512x512 (`resources/icon.png`)
  * MIME 关联规则: `/usr/lib/claude-desktop/resources/linux-mime/com.anthropic.Claude.xml`

---

## 2. Flatpak 规范与关键架构决策

### 2.1 基座与沙盒选型
* **App ID**: `com.anthropic.Claude`
* **Runtime**: `org.freedesktop.Platform//25.08`
* **SDK**: `org.freedesktop.Sdk//25.08`
* **BaseApp**: `org.electronjs.Electron2.BaseApp//25.08`
* **选型原因**:
  * 与 Flathub 及 GitHub Actions 容器底座 (`ghcr.io/flathub-infra/flatpak-github-actions:freedesktop-25.08`) 完全一致。
  * Electron/Chromium 需要非特权用户命名空间沙箱支持，Flatpak 内部通过 `Electron2.BaseApp` 内置的 `zypak-wrapper` 转发至宿主命名空间。

### 2.2 启动包装器 (`/app/bin/claude`)
* 自动检测 Wayland / X11 显示环境，开启 `--ozone-platform-hint=auto` 与 `--enable-features=WaylandWindowDecorations`。
* 支持用户在 `~/.var/app/com.anthropic.Claude/config/claude-flags.conf` 中追加自定义 Electron 启动参数。
* 调用 `zypak-wrapper /app/lib/claude-desktop/claude-desktop` 启动主进程。

### 2.3 Model Context Protocol (MCP) 本地交互方案
* 配置文件位置：`~/.var/app/com.anthropic.Claude/config/Claude/claude_desktop_config.json`
* 权限配置：授予 `--talk-name=org.freedesktop.Flatpak` 与 `--filesystem=home`（两项合起来等同于不受沙箱限制，已在 README 的“权限与安全”中说明）。
* 跨沙箱调用：在 `claude_desktop_config.json` 中配置 `"command": "flatpak-spawn", "args": ["--host", ...]` 即可调用宿主机环境中的 `npx`、`node`、`python` 或 `docker` 等外部 MCP Server。

### 2.4 Cowork 本地代码执行沙箱
* 架构：基于 QEMU + KVM + virtiofsd + 预编译根文件系统 (`smol-bin.x64.img`)。
* 权限配置：开放 `--device=kvm` 硬件加速虚拟化。若系统未启用 KVM 或未安装 QEMU，主程序安全优雅降级。

---

## 3. 自动化 CI/CD 与源托管架构

1. **构建与部署流水线 (`.github/workflows/build-and-deploy.yml`)**:
   * 代码推送至 `master` 时自动触发。
   * 基于 Flathub 官方 Action 容器完成沙箱构建。
   * 每次从空仓库构建并生成 static delta（仅 from-scratch）；仓库只保留最新提交，不提供增量包。
   * 自动打 Tag 并发布 GitHub Release（包含离线 `.flatpak` bundle、`ostree-repo.tar.gz`、`.flatpakref`、`.flatpakrepo`）。
   * 通过 Actions Pages API 部署 GitHub Pages（Pages Source 为 GitHub Actions），同时托管静态主页与完整 OSTree 软件源，无 Git 100MB 单文件限制。
2. **定时版本监控流水线 (`.github/workflows/check-update.yml`)**:
   * 每 6 小时自动执行 `scripts/update-checker.py`。
   * 发现 Anthropic 官方发布新版本时，自动修改清单与元数据，提交代码并级联触发构建与发布。
