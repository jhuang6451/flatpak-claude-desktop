# Claude Desktop Flatpak

<div align="center">
  <img src="icons/hicolor/128x128/apps/com.anthropic.Claude.png" alt="Claude Logo" width="96" height="96" />
  <h3>Anthropic Claude Linux 桌面客户端 — 生产级 Flatpak 打包与全自动更新项目</h3>
  <p>
    <a href="https://github.com/jhuang6451/flatpak-claude-desktop/actions/workflows/build-and-deploy.yml"><img src="https://img.shields.io/github/actions/workflow/status/jhuang6451/flatpak-claude-desktop/build-and-deploy.yml?branch=master&label=Build%20%26%20Deploy&logo=github-actions&logoColor=white" alt="Build Status" /></a>
    <a href="https://github.com/jhuang6451/flatpak-claude-desktop/actions/workflows/check-update.yml"><img src="https://img.shields.io/github/actions/workflow/status/jhuang6451/flatpak-claude-desktop/check-update.yml?branch=master&label=Auto%20Updater&logo=anthropic&logoColor=white" alt="Update Checker" /></a>
    <a href="https://github.com/jhuang6451/flatpak-claude-desktop/releases/latest"><img src="https://img.shields.io/github/v/release/jhuang6451/flatpak-claude-desktop?label=Latest%20Release&color=d97757" alt="Latest Version" /></a>
    <img src="https://img.shields.io/badge/Flatpak-v25.08-blue?logo=flatpak&logoColor=white" alt="Flatpak Runtime" />
    <img src="https://img.shields.io/badge/Architecture-x86__64%20%7C%20aarch64-brightgreen" alt="Architecture" />
    <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green" alt="License" /></a>
  </p>
  <p>
    <b><a href="https://jhuang6451.github.io/flatpak-claude-desktop/">🌐 在线仓库主页与一键安装</a></b>
  </p>
</div>

---

## 📖 项目简介 (Overview)

本仓库提供 Anthropic 官方 Linux 桌面客户端 **Claude Desktop** 的生产级 Flatpak 打包方案。

针对主流 Linux 发行版（Fedora Silverblue/Atomic、Ubuntu、Debian、Arch Linux、openSUSE、SteamOS 等），本项目实现了：
1. **官方源直通与校验**：直连 Anthropic 官方 APT/GCS 镜像源构建，自动提取 Debian 软件包并进行 SHA-256 完整性校验，构建产物纯净安全。
2. **多架构原生兼容**：清单原生支持 `x86_64` (amd64) 与 `aarch64` (arm64) 架构。
3. **MCP (Model Context Protocol) 互通**：支持配置外部 MCP Server，通过 Flatpak 的 `flatpak-spawn --host` 机制无缝调用宿主机工具。
4. **Wayland 与 HiDPI 原生优化**：自适应 Wayland / X11 显示通道，分数缩放清晰锐利，支持自定义启动参数文件 `~/.config/claude-flags.conf`。
5. **系统凭据与通知集成**：支持 GNOME Keyring 与 KDE KWallet 密钥环，保障登录状态持久保存。
6. **一键安装与全自动更新**：配置专有 OSTree 仓库，GitHub Actions 每 6 小时监控 Anthropic 官方软件源，新版发布时自动构建增量镜像并发布。

---

## 🚀 快速安装 (Quick Start)

### 方式 1：添加仓库一键安装（推荐，支持全自动日常更新）

直接在终端执行以下命令：

```bash
# 1. 添加 Claude 软件源仓库
flatpak remote-add --if-not-exists claude https://jhuang6451.github.io/flatpak-claude-desktop/claude.flatpakrepo

# 2. 安装 Claude Desktop
flatpak install -y claude com.anthropic.Claude

# 3. 运行应用
flatpak run com.anthropic.Claude
```

安装完成后，可以在桌面启动器（GNOME、KDE Plasma 等）的应用列表中直接找到 **Claude** 点击运行。

### 方式 2：使用 `.flatpakref` 单文件图形化安装

1. 下载 [claude.flatpakref](https://jhuang6451.github.io/flatpak-claude-desktop/claude.flatpakref) 或在 [在线主页](https://jhuang6451.github.io/flatpak-claude-desktop/) 点击“一键安装”。
2. 双击该文件，系统应用商店（GNOME Software 或 KDE Discover）将自动弹出并完成安装。

### 方式 3：离线单文件 Bundle 安装

从 [GitHub Releases](https://github.com/jhuang6451/flatpak-claude-desktop/releases/latest) 下载 `com.anthropic.Claude.flatpak`，随后执行：

```bash
flatpak install --user com.anthropic.Claude.flatpak
```

---

## 🔌 配置 MCP (Model Context Protocol)

在 Flatpak 沙箱内，Claude Desktop 的配置文件位于：
```bash
~/.var/app/com.anthropic.Claude/config/Claude/claude_desktop_config.json
```

若需在 Claude 中调用宿主机的开发工具（如 `npx`、`uvx`、`node`、`python` 或 `docker`），可在配置中借助 `flatpak-spawn --host` 穿透至宿主系统：

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "flatpak-spawn",
      "args": [
        "--host",
        "npx",
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/path/to/allowed/directory"
      ]
    },
    "memory": {
      "command": "flatpak-spawn",
      "args": [
        "--host",
        "npx",
        "-y",
        "@modelcontextprotocol/server-memory"
      ]
    }
  }
}
```

---

## 🛠 本地构建与调试 (Local Build)

本项目支持完全在本地进行快速构建与测试：

```bash
# 1. 克隆代码仓库
git clone https://github.com/jhuang6451/flatpak-claude-desktop.git
cd flatpak-claude-desktop

# 2. 运行本地一键构建脚本
./scripts/build-local.sh
```

---

## 🔄 自动化上游更新机制 (Auto-Updater)

仓库配置了 `.github/workflows/check-update.yml` 定时任务（每 6 小时触发）：
1. 运行 `scripts/update-checker.py` 抓取 Anthropic 官方 APT 仓库索引（`Packages.gz`）。
2. 检测到新版本后，自动更新 `com.anthropic.Claude.yaml`（各架构包地址与哈希）和 AppStream 元数据 `com.anthropic.Claude.metainfo.xml`。
3. 提交变动并触发 `build-and-deploy.yml` 自动化构建、发布 Release，并更新 GitHub Pages 上的 OSTree 软件源。

---

## 📄 许可证说明 (License)

* 本打包工程与脚本基于 [MIT 许可证](LICENSE) 开源。
* Claude 与 Anthropic 均为 Anthropic PBC 的注册商标和专有软件。本项目为独立第三方社区开源项目，与 Anthropic 官方无隶属关系。
