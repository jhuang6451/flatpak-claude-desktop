<div align="center">
  <img src="icons/hicolor/128x128/apps/com.anthropic.Claude.png" alt="Claude" width="88" height="88" />

  <h1>Claude Desktop for Linux (Flatpak)</h1>

  <p>Flatpak packaging and a software repository for Anthropic's official Linux desktop client.</p>

  <p>
    <a href="https://github.com/jhuang6451/flatpak-claude-desktop/actions/workflows/build-and-deploy.yml"><img src="https://img.shields.io/github/actions/workflow/status/jhuang6451/flatpak-claude-desktop/build-and-deploy.yml?branch=master&label=build&labelColor=141413&color=d97757" alt="Build status" /></a>
    <a href="https://github.com/jhuang6451/flatpak-claude-desktop/actions/workflows/check-update.yml"><img src="https://img.shields.io/github/actions/workflow/status/jhuang6451/flatpak-claude-desktop/check-update.yml?branch=master&label=upstream%20check&labelColor=141413&color=d97757" alt="Upstream check status" /></a>
    <a href="https://github.com/jhuang6451/flatpak-claude-desktop/releases/latest"><img src="https://img.shields.io/github/v/release/jhuang6451/flatpak-claude-desktop?label=release&labelColor=141413&color=d97757" alt="Latest release" /></a>
    <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-d97757?labelColor=141413" alt="License" /></a>
  </p>

  <p>English · <a href="README.zh-CN.md">简体中文</a></p>

  <p>
    <a href="https://jhuang6451.github.io/flatpak-claude-desktop/">Website</a> ·
    <a href="https://github.com/jhuang6451/flatpak-claude-desktop/releases/latest">Offline bundle</a> ·
    <a href="#known-limitations">Known limitations</a>
  </p>
</div>

## Overview

Anthropic ships its Linux client only as a `.deb` package. This project repackages that official installer as a Flatpak and hosts an OSTree repository, so systems where installing a `.deb` is awkward (Fedora Atomic, Bazzite, SteamOS) can use `flatpak install` and get updates the usual way.

The upstream program is not modified. The build downloads the `.deb` from Anthropic's APT repository, checks its SHA-256, unpacks it as is, and adds a launcher script, a desktop file, and icons.

- The package comes from Anthropic's official APT repository. The manifest pins the download URL and SHA-256.
- The launcher detects Wayland and enables the matching Ozone flags. A config file can add more Electron flags.
- `flatpak-spawn --host` lets MCP servers run on the host system.
- Login state is stored in GNOME Keyring or KDE Wallet.
- GitHub Actions checks upstream every 6 hours. When a new version appears, it updates the manifest, builds, and publishes.

Only **x86_64** is built and published. The manifest keeps an aarch64 download source, but CI does not build it, and neither the repository nor the offline bundle contains an aarch64 version.

## Installation

### From the repository (recommended)

```bash
flatpak remote-add --if-not-exists claude https://jhuang6451.github.io/flatpak-claude-desktop/claude.flatpakrepo
flatpak install claude com.anthropic.Claude
flatpak run com.anthropic.Claude
```

Once the remote is added, `flatpak update` updates Claude along with your other apps. The runtime comes from Flathub, so add Flathub first if it isn't enabled:

```bash
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

### From a `.flatpakref`

Download [claude.flatpakref](https://jhuang6451.github.io/flatpak-claude-desktop/claude.flatpakref) and open it with GNOME Software or KDE Discover. The file includes the Flathub URL, so the runtime is installed too.

### From the offline bundle

Download `com.anthropic.Claude.flatpak` from [Releases](https://github.com/jhuang6451/flatpak-claude-desktop/releases/latest):

```bash
flatpak install --user com.anthropic.Claude.flatpak
```

The bundle doesn't update itself. To upgrade, download a new one.

### Repository signing

Commits and the summary file are signed with GPG. `claude.flatpakrepo` and `claude.flatpakref` embed the public key and set `gpg-verify=true`, so Flatpak verifies signatures after download. The signing key fingerprint is:

```text
6176 AE45 DD3A 94D2 5ACB D8BD 128B 2D5D 4D43 0E28
```

If you added the `claude` remote before signing was enabled, your old configuration has no public key and updates will fail. Remove the remote and add it again:

```bash
flatpak remote-delete claude
flatpak remote-add claude https://jhuang6451.github.io/flatpak-claude-desktop/claude.flatpakrepo
```

The offline bundle is not covered by this verification, so download it only from this repository's Releases page.

## Usage

### Launch flags

The launcher reads one of the two files below, with one flag per line. Blank lines and lines starting with `#` are ignored. If the first file exists, the second is not read.

```text
~/.var/app/com.anthropic.Claude/config/claude-flags.conf
~/.var/app/com.anthropic.Claude/config/claude-desktop-flags.conf
```

Inside the sandbox this path is `$XDG_CONFIG_HOME`, not `~/.config`. For example, to force X11:

```text
--ozone-platform=x11
```

On Wayland sessions the launcher adds `--ozone-platform-hint=auto` and `--enable-features=WaylandWindowDecorations` by default. If your config file also sets `--enable-features=...`, the launcher merges it with the defaults, so you don't need to repeat `WaylandWindowDecorations`.

### Configuring MCP servers

The config file lives at:

```text
~/.var/app/com.anthropic.Claude/config/Claude/claude_desktop_config.json
```

The sandbox has no `npx`, `uvx`, or `docker`. To use programs from the host, start them with `flatpak-spawn --host`:

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

This depends on the `org.freedesktop.Flatpak` permission described in the next section.

## Permissions and security

This Flatpak has weak sandbox isolation. Read this before installing.

The manifest grants `--talk-name=org.freedesktop.Flatpak` and `--filesystem=home`. The first lets the app run arbitrary commands on the host through `flatpak-spawn --host`. The second lets it read and write your whole home directory. Together they give the app all of the current user's privileges, so the sandbox doesn't isolate anything. They stay because host MCP servers and access to arbitrary project directories need them.

The full permission list:

| Permission | Purpose |
| --- | --- |
| `--socket=wayland`, `--socket=fallback-x11`, `--share=ipc` | Display |
| `--share=network` | Claude services and MCP servers |
| `--socket=pulseaudio`, `--filesystem=xdg-run/pipewire-0` | Audio |
| `--device=dri` | GPU acceleration |
| `--device=kvm` | Cowork local virtual machine |
| `--filesystem=home` | Read and write the home directory |
| `--talk-name=org.freedesktop.Flatpak` | Run commands on the host |
| `--talk-name=org.freedesktop.Notifications`, `org.kde.StatusNotifierWatcher`, `com.canonical.AppMenu.Registrar` | Notifications, tray icon, global menu |
| `--talk-name=org.freedesktop.secrets`, `org.kde.kwalletd5`, `org.kde.kwalletd6` | Keyring |

To tighten permissions, use [Flatseal](https://flathub.org/apps/com.github.tchx84.Flatseal) or revoke them on the command line:

```bash
flatpak override --user --nofilesystem=home com.anthropic.Claude
flatpak override --user --no-talk-name=org.freedesktop.Flatpak com.anthropic.Claude
```

After revoking, host MCP servers and access to your home directory stop working.

## Known limitations

- **x86_64 only.** CI builds only x86_64.
- **No GNOME search provider.** The upstream provider needs `gjs` on the host and can't register with GNOME Shell from inside the sandbox.
- **Claude in Chrome needs manual setup.** The host browser has to start `chrome-native-host` inside the sandbox through native messaging. After installing, run `scripts/install-chrome-native-host.sh` once, then restart Claude Desktop and the browser. The script puts a wrapper in `~/.local/bin` and registers a manifest with Chrome, Chromium, Brave, Edge, and Vivaldi on the host. Flatpak builds of those browsers aren't supported yet.
- **Cowork needs KVM.** It runs on QEMU and KVM. Without `/dev/kvm` on the host, the app still works but the Cowork virtual machine can't start.
- **The offline bundle doesn't install the runtime.** Enable Flathub before installing it.

## Building locally

You need `flatpak` and `flatpak-builder`. The script installs `org.flatpak.Builder` if `flatpak-builder` is missing.

```bash
git clone https://github.com/jhuang6451/flatpak-claude-desktop.git
cd flatpak-claude-desktop
./scripts/build-local.sh
```

The script installs the required runtimes, builds, and exports the result to a local `repo/` directory.

## Automatic updates

1. `check-update.yml` runs `scripts/update-checker.py` every 6 hours and reads Anthropic's `Packages.gz` index.
2. When there is a new version, the script updates the download URL and hash in `com.anthropic.Claude.yaml`, adds a release entry to `com.anthropic.Claude.metainfo.xml`, and commits to `master`.
3. The commit triggers `build-and-deploy.yml`, which builds the Flatpak, creates a GitHub Release, and publishes the OSTree repository and the website through GitHub Pages.

Each release is built from an empty repository, so the remote holds only the latest commit. OSTree addresses files by content, and clients download only the objects they don't already have. The repository keeps no history and offers no deltas from older versions.

## License and trademarks

The packaging scripts and configuration are released under the [MIT License](LICENSE). Claude is a trademark of Anthropic PBC, and Claude Desktop is Anthropic's proprietary software. This project is not affiliated with or endorsed by Anthropic.
