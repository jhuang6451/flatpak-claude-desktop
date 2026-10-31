# TODO

来源：2026-10-30 仓库代码与构建结果审查（CI run 41069196928 / Release v4.4212.0）。

## 高

- [x] **#1 Pages 双源冲突**：Pages 源为 legacy `gh-pages` 分支，同时又用 `actions/deploy-pages` 部署 OSTree 仓库；`gh-pages` 新提交会覆盖掉 `repo/`。→ 移除 `peaceiris/actions-gh-pages`，Pages Source 切换为 GitHub Actions。
- [x] **#2 `deploy-pages` 设了 `continue-on-error`**：软件源部署失败时工作流仍为绿色。→ 已移除。
- [x] **#3 aarch64 未构建**（文档已改为仅 x86_64，CI 构建 aarch64 仍待做）：清单与 README 宣称支持 aarch64，CI 只构建 `x86_64`。→ 增加 arm64 runner matrix，或修正宣传。
- [x] **#4 `claude.flatpakref` 缺少 `RuntimeRepo=`**：未配置 flathub 的用户无法解析 `org.freedesktop.Platform//25.08`。→ 已添加。

## 中

- [x] **#5 “增量更新”不成立**（README、主页、PROJECT_CONTEXT 已修正描述）：CI 每次从空 `repo` 构建，static delta 只有 from-scratch，`--prune` 无意义。→ 先拉取线上仓库再 commit，或修正 README / PROJECT_CONTEXT 描述。
- [x] **#6 版本提取硬编码回退 `4.4212.0`**：提取失败会给新构建打旧 tag。→ 改为报错退出。
- [x] **#7 `update-checker.py` 未校验 amd64/arm64 版本一致**：arm64 滞后时会写入错配的 URL 与 SHA。→ 不一致时报错退出。
  - [x] 附带：`parse_latest_package` 依赖 Packages 条目顺序，宜改为按版本比较取最大值。
- [x] **#8 工作流触发与并发**：`paths` 未包含 `web/**`、`claude.flatpakref`、`claude.flatpakrepo`；无 `concurrency`，并发运行可能旧版本后部署。
- [x] **#9 软件源未 GPG 签名**（`gpg-verify=false`）。→ CI 用仓库 secret 中的 GPG key（`scripts/sign-repo.sh`）签名，公钥内嵌于 `.flatpakrepo` / `.flatpakref`，`gpg-verify=true`。

## 低 / 文档与权限

- [x] **#10 沙箱等效失效**：`--talk-name=org.freedesktop.Flatpak` + `--filesystem=home` 可任意宿主执行，README 应明确说明；PROJECT_CONTEXT 写 `--filesystem=host` 与清单 `home` 不一致；`xdg-download` / `xdg-documents` 与 `home` 冗余。
- [x] **#11 `--env=OZONE_PLATFORM=wayland` 应无效**（Electron 不读此变量）→ 已移除；用户 flags 中的 `--enable-features` 现与默认值合并。
- [x] **#12 `claude.sh` 将 `TMPDIR` 设为缓存根目录**，与缓存混杂。→ 已改为 `$XDG_CACHE_HOME/tmp`。同时修复 Chrome native host 套接字目录不一致：宿主包装脚本原用 `~/.cache`，沙箱内是 `~/.var/app/.../cache`，现统一为沙箱内的 `$XDG_CACHE_HOME`。
- [x] **#13 metainfo**（release 日期现取自上游 .deb 的 Last-Modified，失败时回退为当天）：描述中 “Claude 3.7 Sonnet / 3.5” 过时；`<developer_name>` 已弃用，改用 `<developer id="..."><name>`；release 日期取脚本运行日而非上游发布日期。
- [x] **#14 `.desktop` lint**：导出后 Action 的 Exec 被 Flatpak 改写为单引号，`desktop-file-validate` 报保留字符错误；`Categories` 含两个主类别。→ Action 改为 `claude --action=new-chat/new-code`（由 `claude.sh` 转换为 URL），`Categories=Utility;`。
- [x] **#15 沙箱内不可用的上游组件**：GNOME 搜索提供器（依赖宿主 `gjs`）、`chrome-native-host`（Claude in Chrome native messaging）。→ README 增加“已知限制”。
- [x] **#16 杂项**：`actions/cache` 与 flatpak-builder `cache: true` 重复缓存；`build-local.sh` 生成 bundle 未加 `--runtime-repo`；同版本重新打包时 tag 不会移动。
