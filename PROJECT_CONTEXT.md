# Anthropic Claude Linux client: Flatpak packaging context (session handoff)

English · [简体中文](PROJECT_CONTEXT.zh-CN.md)

> **Last updated**: 2026-10-30 (synced to 4.4212.0)
> **Working directory**: `/var/home/jhuang/Workspace/flatpak-claude-desktop`
> **GitHub repository**: `https://github.com/jhuang6451/flatpak-claude-desktop`
> **Pages site and software repository**: `https://jhuang6451.github.io/flatpak-claude-desktop/`

---

## 1. Upstream source

* **Official APT root**: `https://downloads.claude.ai/claude-desktop/apt/stable`
* **Version indexes**:
  * x86_64: `https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-amd64/Packages.gz`
  * aarch64: `https://downloads.claude.ai/claude-desktop/apt/stable/dists/stable/main/binary-arm64/Packages.gz`
* **Current version**: `4.4212.0`
  * amd64 deb: `https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_4.4212.0_amd64.deb`
    * SHA-256: `4fcf658e0fc895390ab82593287281dfbce261b0ec3ea90060e82d8bfbfd7a84`
  * arm64 deb: `https://downloads.claude.ai/claude-desktop/apt/stable/pool/main/c/claude-desktop/claude-desktop_4.4212.0_arm64.deb`
    * SHA-256: `7022dc56de30e0beb7fa0a7dc84e09aa00d7f9d4e1b7f93043b32baf75a2f6d8`
* **Layout of the official DEB**:
  * Main binary: `/usr/lib/claude-desktop/claude-desktop` (ELF 64-bit PIE, Electron 44.9.3)
  * Chromium SUID sandbox: `/usr/lib/claude-desktop/chrome-sandbox` (forwarded through `zypak-wrapper` under Flatpak)
  * Cowork isolation helper: `/usr/lib/claude-desktop/resources/cowork-linux-helper` (statically linked Go, QEMU/KVM)
  * VM image: `/usr/lib/claude-desktop/resources/smol-bin.x64.img`
  * Shared filesystem daemon: `/usr/lib/claude-desktop/resources/virtiofsd`
  * Icons: 16x16 to 256x256 (hicolor) and 512x512 (`resources/icon.png`)
  * MIME rules: `/usr/lib/claude-desktop/resources/linux-mime/com.anthropic.Claude.xml`

---

## 2. Flatpak decisions

### 2.1 Base and sandbox
* **App ID**: `com.anthropic.Claude`
* **Runtime**: `org.freedesktop.Platform//25.08`
* **SDK**: `org.freedesktop.Sdk//25.08`
* **BaseApp**: `org.electronjs.Electron2.BaseApp//25.08`
* **Why**:
  * It matches Flathub and the GitHub Actions container image (`ghcr.io/flathub-infra/flatpak-github-actions:freedesktop-25.08`).
  * Electron/Chromium needs unprivileged user namespaces. `zypak-wrapper`, bundled in `Electron2.BaseApp`, forwards the sandbox setup to the host namespace.

### 2.2 Launcher (`/app/bin/claude`)
* Detects Wayland or X11 and enables `--ozone-platform-hint=auto` and `--enable-features=WaylandWindowDecorations`.
* Reads extra Electron flags from `~/.var/app/com.anthropic.Claude/config/claude-flags.conf`.
* Starts the main process with `zypak-wrapper /app/lib/claude-desktop/claude-desktop`.

### 2.3 Local MCP servers
* Config file: `~/.var/app/com.anthropic.Claude/config/Claude/claude_desktop_config.json`
* Permissions: `--talk-name=org.freedesktop.Flatpak` and `--filesystem=home`. Together they remove sandbox limits; the README's "Permissions and security" section says so.
* Host calls: set `"command": "flatpak-spawn", "args": ["--host", ...]` in `claude_desktop_config.json` to run host tools such as `npx`, `node`, `python`, or `docker`.

### 2.4 Cowork local sandbox
* Built on QEMU, KVM, virtiofsd, and a prebuilt root filesystem (`smol-bin.x64.img`).
* Permissions: `--device=kvm` for hardware acceleration. Without KVM or QEMU the main program degrades gracefully.

---

## 3. CI/CD and hosting

1. **Build and deploy (`.github/workflows/build-and-deploy.yml`)**:
   * Runs on every push to `master`.
   * Builds in the official Flathub Action container.
   * Builds from an empty repository each time and generates a from-scratch static delta. The repository keeps only the latest commit and offers no incremental deltas.
   * Tags the release and publishes a GitHub Release with the offline `.flatpak` bundle, `ostree-repo.tar.gz`, `.flatpakref`, and `.flatpakrepo`.
   * Deploys GitHub Pages through the Actions Pages API (Pages source set to GitHub Actions). Pages hosts both the static site and the full OSTree repository, with no 100 MB Git file limit.
2. **Upstream version check (`.github/workflows/check-update.yml`)**:
   * Runs `scripts/update-checker.py` every 6 hours.
   * When Anthropic publishes a new version, it edits the manifest and metadata, commits, and triggers the build and release.
