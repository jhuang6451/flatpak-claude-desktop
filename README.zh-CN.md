<div align="center">
  <img src="icons/hicolor/128x128/apps/com.anthropic.Claude.png" alt="Claude" width="88" height="88" />

  <h1>Claude Desktop for Linux (Flatpak)</h1>

  <p>Anthropic 官方 Linux 桌面客户端的 Flatpak 打包与软件源。</p>

  <p><a href="README.md">English</a> · 简体中文</p>

  <p>
    <a href="https://github.com/jhuang6451/flatpak-claude-desktop/actions/workflows/build-and-deploy.yml"><img src="https://img.shields.io/github/actions/workflow/status/jhuang6451/flatpak-claude-desktop/build-and-deploy.yml?branch=master&label=build&labelColor=141413&color=d97757" alt="构建状态" /></a>
    <a href="https://github.com/jhuang6451/flatpak-claude-desktop/actions/workflows/check-update.yml"><img src="https://img.shields.io/github/actions/workflow/status/jhuang6451/flatpak-claude-desktop/check-update.yml?branch=master&label=upstream%20check&labelColor=141413&color=d97757" alt="上游检查状态" /></a>
    <a href="https://github.com/jhuang6451/flatpak-claude-desktop/releases/latest"><img src="https://img.shields.io/github/v/release/jhuang6451/flatpak-claude-desktop?label=release&labelColor=141413&color=d97757" alt="最新版本" /></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-d97757?labelColor=141413" alt="许可证" /></a>
  </p>

  <p>
    <a href="https://jhuang6451.github.io/flatpak-claude-desktop/">项目主页</a> ·
    <a href="https://github.com/jhuang6451/flatpak-claude-desktop/releases/latest">下载离线包</a> ·
    <a href="#已知限制">已知限制</a>
  </p>
</div>

## 简介

Anthropic 只为 Linux 提供 `.deb` 软件包。本项目把这个官方安装包重新打成 Flatpak,并托管一个 OSTree 软件源,这样 Fedora Atomic、Bazzite、SteamOS 这类不方便装 `.deb` 的系统也能用 `flatpak install` 安装和更新。

打包时不修改上游程序。构建流程从 Anthropic 的 APT 源下载 `.deb`,核对 SHA-256 后原样解包,再加上启动脚本、桌面文件和图标。

主要特性:

- 安装包来自 Anthropic 官方 APT 源,清单中固定了下载地址和 SHA-256。
- 启动脚本会检测 Wayland 并启用对应的 Ozone 参数,也支持用配置文件追加 Electron 参数。
- 通过 `flatpak-spawn --host` 可以让 MCP Server 运行在宿主系统上。
- 登录状态保存在 GNOME Keyring 或 KDE Wallet 中。
- GitHub Actions 每 6 小时检查一次上游,发现新版本后自动更新清单、构建并发布。

当前只构建和发布 **x86_64**。清单里保留了 aarch64 的下载源,但持续集成不会构建它,发布的软件源和离线包里也没有 aarch64 版本。

## 安装

### 通过软件源安装(推荐)

```bash
flatpak remote-add --if-not-exists claude https://jhuang6451.github.io/flatpak-claude-desktop/claude.flatpakrepo
flatpak install claude com.anthropic.Claude
flatpak run com.anthropic.Claude
```

添加软件源后,`flatpak update` 会和其他应用一起更新 Claude。应用 Runtime 来自 Flathub,没有启用 Flathub 的系统需要先添加:

```bash
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

### 通过 `.flatpakref` 安装

下载 [claude.flatpakref](https://jhuang6451.github.io/flatpak-claude-desktop/claude.flatpakref),双击用 GNOME 软件或 KDE Discover 打开。这个文件带有 Flathub 的地址,Runtime 会一并安装。

### 通过离线包安装

在 [Releases](https://github.com/jhuang6451/flatpak-claude-desktop/releases/latest) 下载 `com.anthropic.Claude.flatpak`:

```bash
flatpak install --user com.anthropic.Claude.flatpak
```

离线包不会自动更新,升级时需要重新下载。

### 软件源签名

软件源的提交和 summary 都用 GPG 签名,`claude.flatpakrepo` 和 `claude.flatpakref` 内嵌了公钥并启用了 `gpg-verify=true`,Flatpak 会在下载后校验。签名密钥指纹:

```text
6176 AE45 DD3A 94D2 5ACB D8BD 128B 2D5D 4D43 0E28
```

如果你在签名启用之前就添加过 `claude` 软件源,旧配置没有公钥,更新会失败。删除后重新添加即可:

```bash
flatpak remote-delete claude
flatpak remote-add claude https://jhuang6451.github.io/flatpak-claude-desktop/claude.flatpakrepo
```

离线包 `com.anthropic.Claude.flatpak` 不走这套校验,请从本仓库的 Releases 页面下载。

## 使用

### 启动参数

启动脚本读取下面两个文件之一,每行一个参数,空行和以 `#` 开头的行会被忽略。前者存在时不会读取后者。

```text
~/.var/app/com.anthropic.Claude/config/claude-flags.conf
~/.var/app/com.anthropic.Claude/config/claude-desktop-flags.conf
```

路径在沙箱内对应 `$XDG_CONFIG_HOME`,所以不是 `~/.config`。例如强制使用 X11:

```text
--ozone-platform=x11
```

在 Wayland 会话中,启动脚本默认加上 `--ozone-platform-hint=auto` 和 `--enable-features=WaylandWindowDecorations`。如果你在配置文件里也写了 `--enable-features=...`,启动脚本会把它和默认值合并,不需要重复写 `WaylandWindowDecorations`。

### 配置 MCP Server

配置文件位置:

```text
~/.var/app/com.anthropic.Claude/config/Claude/claude_desktop_config.json
```

沙箱里没有 `npx`、`uvx`、`docker` 这些工具。需要用宿主系统上的程序时,用 `flatpak-spawn --host` 启动:

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
    }
  }
}
```

这个方式依赖下一节所说的 `org.freedesktop.Flatpak` 权限。

## 权限与安全

这个 Flatpak 的沙箱隔离很弱,请在安装前了解这一点。

清单授予了 `--talk-name=org.freedesktop.Flatpak` 和 `--filesystem=home`。前者允许应用通过 `flatpak-spawn --host` 在宿主系统执行任意命令,后者允许读写整个用户目录。两项合起来,应用实际拥有当前用户的全部权限,沙箱起不到隔离作用。保留它们是为了支持宿主 MCP Server 和对任意项目目录的访问。

完整权限如下:

| 权限 | 用途 |
| --- | --- |
| `--socket=wayland`、`--socket=fallback-x11`、`--share=ipc` | 显示 |
| `--share=network` | 访问 Claude 服务和 MCP Server |
| `--socket=pulseaudio`、`--filesystem=xdg-run/pipewire-0` | 音频 |
| `--device=dri` | GPU 加速 |
| `--device=kvm` | Cowork 本地虚拟机 |
| `--filesystem=home` | 读写用户目录 |
| `--talk-name=org.freedesktop.Flatpak` | 在宿主系统运行命令 |
| `--talk-name=org.freedesktop.Notifications`、`org.kde.StatusNotifierWatcher`、`com.canonical.AppMenu.Registrar` | 通知、托盘图标、全局菜单 |
| `--talk-name=org.freedesktop.secrets`、`org.kde.kwalletd5`、`org.kde.kwalletd6` | 密钥环 |

想收紧权限,可以用 [Flatseal](https://flathub.org/apps/com.github.tchx84.Flatseal) 或命令行撤销:

```bash
flatpak override --user --nofilesystem=home com.anthropic.Claude
flatpak override --user --no-talk-name=org.freedesktop.Flatpak com.anthropic.Claude
```

撤销后,宿主 MCP Server 和对用户目录的访问都会失效。

## 已知限制

- **仅 x86_64。** 持续集成只构建 x86_64。
- **GNOME 搜索提供器不可用。** 上游的搜索提供器依赖宿主系统的 `gjs`,沙箱内无法注册到 GNOME Shell。
- **Claude in Chrome 需要手动配置。** 它需要宿主浏览器通过 native messaging 启动沙箱里的 `chrome-native-host`。安装后运行一次 `scripts/install-chrome-native-host.sh`,再重启 Claude Desktop 和浏览器。该脚本会在 `~/.local/bin` 放一个包装脚本,并向宿主上的 Chrome、Chromium、Brave、Edge、Vivaldi 注册清单。Flatpak 版浏览器暂不支持。
- **Cowork 需要 KVM。** 它基于 QEMU 和 KVM。宿主没有 `/dev/kvm` 时,应用仍可使用,Cowork 的本地虚拟机无法启动。
- **离线包的 Runtime 不会自动安装。** 安装前需要启用 Flathub。

## 本地构建

需要 `flatpak` 和 `flatpak-builder`(没有时脚本会安装 `org.flatpak.Builder`):

```bash
git clone https://github.com/jhuang6451/flatpak-claude-desktop.git
cd flatpak-claude-desktop
./scripts/build-local.sh
```

脚本会安装所需 Runtime,构建并把结果导出到本地 `repo/` 目录。

## 自动更新流程

1. `check-update.yml` 每 6 小时运行 `scripts/update-checker.py`,读取 Anthropic 的 `Packages.gz` 索引。
2. 有新版本时,脚本更新 `com.anthropic.Claude.yaml` 里的下载地址和哈希,并在 `com.anthropic.Claude.metainfo.xml` 里添加版本记录,然后提交到 `master`。
3. 提交触发 `build-and-deploy.yml`:构建 Flatpak,创建 GitHub Release,并通过 GitHub Pages 发布 OSTree 仓库和项目主页。

每次发布都会从空仓库重新构建,软件源里只有最新一个提交。OSTree 按文件内容寻址,客户端更新时只下载本地没有的对象,但仓库不保存历史版本,也不提供从旧版本出发的增量包。

## 许可证与商标

本项目的打包脚本和配置以 [MIT 许可证](LICENSE)发布。Claude 是 Anthropic PBC 的商标,Claude Desktop 是 Anthropic 的专有软件,本项目与 Anthropic 没有隶属关系,也未获其背书。
