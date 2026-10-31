#!/usr/bin/env bash
set -euo pipefail

# Local Flatpak Build & Test Helper Script for Claude Desktop

MANIFEST="com.anthropic.Claude.yaml"
BUILD_DIR="${BUILD_DIR:-build-dir}"
REPO_DIR="${REPO_DIR:-repo}"

echo "==> Checking required Flatpak runtimes..."
flatpak install -y --user flathub \
  org.freedesktop.Platform//25.08 \
  org.freedesktop.Sdk//25.08 \
  org.electronjs.Electron2.BaseApp//25.08 || true

BUILDER_CMD=""
if command -v flatpak-builder >/dev/null 2>&1; then
  BUILDER_CMD="flatpak-builder"
elif flatpak info org.flatpak.Builder >/dev/null 2>&1; then
  BUILDER_CMD="flatpak run org.flatpak.Builder"
else
  echo "Installing org.flatpak.Builder..."
  flatpak install -y --user flathub org.flatpak.Builder
  BUILDER_CMD="flatpak run org.flatpak.Builder"
fi

echo "==> Using Flatpak Builder: ${BUILDER_CMD}"
echo "==> Building Claude Desktop Flatpak package..."
${BUILDER_CMD} --user --force-clean --repo="${REPO_DIR}" "${BUILD_DIR}" "${MANIFEST}"

echo "==> Updating repository index & generating static deltas..."
flatpak build-update-repo --generate-static-deltas "${REPO_DIR}"

echo "==> Building standalone bundle..."
flatpak build-bundle --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo \
  "${REPO_DIR}" com.anthropic.Claude.flatpak com.anthropic.Claude stable

echo "==> Done! You can install and test your local build with:"
echo "    flatpak install --user --bundle com.anthropic.Claude.flatpak"
echo "    flatpak run com.anthropic.Claude"
