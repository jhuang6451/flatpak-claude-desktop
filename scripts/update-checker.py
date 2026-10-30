#!/usr/bin/env python3
"""
Claude Desktop Flatpak Automated Upstream Update Checker

Checks the upstream Anthropic Debian/APT repository for new releases,
fetches the official package SHA-256 and metadata from Packages.gz,
and updates the Flatpak manifest (com.anthropic.Claude.yaml) and AppStream metadata.
"""

import os
import re
import sys
import gzip
import argparse
import datetime
import subprocess

REPO_BASE_URL = "https://downloads.claude.ai/claude-desktop/apt/stable"
PACKAGES_AMD64_URL = f"{REPO_BASE_URL}/dists/stable/main/binary-amd64/Packages.gz"
PACKAGES_ARM64_URL = f"{REPO_BASE_URL}/dists/stable/main/binary-arm64/Packages.gz"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
MANIFEST_PATH = os.path.join(REPO_ROOT, "com.anthropic.Claude.yaml")
METAINFO_PATH = os.path.join(REPO_ROOT, "com.anthropic.Claude.metainfo.xml")


def fetch_url(url, timeout=30):
    cmd = ["curl", "-sSL", "--fail", "--connect-timeout", "15", "-m", str(timeout), url]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if res.returncode != 0:
        raise RuntimeError(f"curl failed for {url}: {res.stderr.decode('utf-8', errors='ignore')}")
    return res.stdout


def parse_latest_package(packages_gz_data):
    raw_text = gzip.decompress(packages_gz_data).decode("utf-8", errors="ignore")
    entries = raw_text.strip().split("\n\n")
    latest = {}
    for entry in entries:
        pkg = {}
        for line in entry.splitlines():
            if ":" in line:
                k, v = line.split(":", 1)
                pkg[k.strip()] = v.strip()
        if pkg.get("Package") == "claude-desktop":
            latest = pkg
    return latest


def set_github_output(outputs):
    gh_output = os.environ.get("GITHUB_OUTPUT")
    if gh_output and os.path.exists(gh_output):
        with open(gh_output, "a", encoding="utf-8") as f:
            for k, v in outputs.items():
                f.write(f"{k}={v}\n")


def parse_current_manifest():
    if not os.path.exists(MANIFEST_PATH):
        raise FileNotFoundError(f"Manifest not found: {MANIFEST_PATH}")

    with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    ver_match = re.search(r"claude-desktop_([0-9.]+)_amd64\.deb", content)
    sha_matches = re.findall(r"sha256:\s*([a-f0-9]{64})", content)

    if not ver_match or len(sha_matches) < 2:
        raise ValueError("Could not parse current package version or sha256 from manifest")

    return {
        "version": ver_match.group(1),
        "amd64_sha": sha_matches[0],
        "arm64_sha": sha_matches[1],
        "content": content
    }


def update_manifest(old_content, version, amd64_sha, arm64_sha):
    content = re.sub(
        r"(url:\s*https://downloads\.claude\.ai/.+?claude-desktop_)[0-9.]+_amd64\.deb",
        f"\\g<1>{version}_amd64.deb",
        old_content,
    )
    content = re.sub(
        r"(url:\s*https://downloads\.claude\.ai/.+?claude-desktop_)[0-9.]+_arm64\.deb",
        f"\\g<1>{version}_arm64.deb",
        content,
    )
    content = re.sub(
        r"(sha256:\s*)[0-9a-fA-F]{64}(\s*\n\s*dest-filename:\s*claude\.deb\s*\n\s*only-arches:\s*\n\s*-\s*x86_64)",
        f"\\g<1>{amd64_sha}\\2",
        content,
    )
    content = re.sub(
        r"(sha256:\s*)[0-9a-fA-F]{64}(\s*\n\s*dest-filename:\s*claude\.deb\s*\n\s*only-arches:\s*\n\s*-\s*aarch64)",
        f"\\g<1>{arm64_sha}\\2",
        content,
    )

    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Updated manifest at {MANIFEST_PATH}")


def update_metainfo(new_version, release_date):
    if not os.path.exists(METAINFO_PATH):
        return

    with open(METAINFO_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    rel_block = (
        f'    <release version="{new_version}" date="{release_date}">\n'
        f'      <description>\n'
        f'        <p>Anthropic Claude Desktop Linux release {new_version}.</p>\n'
        f'      </description>\n'
        f'    </release>'
    )

    if f'version="{new_version}"' not in content and "<releases>" in content:
        content = re.sub(r"(<releases>)", f"\\1\n{rel_block}", content, count=1)
        with open(METAINFO_PATH, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Added release {new_version} to {METAINFO_PATH}")


def main():
    parser = argparse.ArgumentParser(description="Claude Desktop Flatpak update checker")
    parser.add_argument("--check", action="store_true", help="Only check for updates without modifying files")
    parser.add_argument("--update", action="store_true", help="Perform the update if new version found")
    parser.add_argument("--force", action="store_true", help="Force recalculation and update even if up to date")
    parser.add_argument("--ci", action="store_true", help="Output GitHub Actions step variables")

    args = parser.parse_args()

    print("==> Fetching latest upstream Packages.gz from Anthropic APT repo...")
    amd64_data = fetch_url(PACKAGES_AMD64_URL)
    amd64_pkg = parse_latest_package(amd64_data)

    arm64_data = fetch_url(PACKAGES_ARM64_URL)
    arm64_pkg = parse_latest_package(arm64_data)

    ver = amd64_pkg.get("Version")
    amd64_sha = amd64_pkg.get("SHA256")
    arm64_sha = arm64_pkg.get("SHA256")

    print(f"Upstream latest version: {ver}")
    print(f"  amd64 deb: {amd64_pkg.get('Filename')} (SHA256: {amd64_sha})")
    print(f"  arm64 deb: {arm64_pkg.get('Filename')} (SHA256: {arm64_sha})")

    if not ver or not amd64_sha or not arm64_sha:
        print("Error: Could not retrieve complete package metadata.")
        sys.exit(1)

    if arm64_pkg.get("Version") != ver:
        print(f"Error: amd64 ({ver}) and arm64 ({arm64_pkg.get('Version')}) versions differ; skipping update.")
        sys.exit(1)

    curr = parse_current_manifest()
    print(f"Current manifest version: {curr['version']}")

    needs_update = (
        ver != curr["version"]
        or amd64_sha != curr["amd64_sha"]
        or arm64_sha != curr["arm64_sha"]
        or args.force
    )

    if not needs_update:
        print(f"Manifest is already up-to-date with latest release {ver}.")
        if args.ci:
            set_github_output({
                "updated": "false",
                "version": curr["version"]
            })
        return 0

    print(f"Update available: {curr['version']} -> {ver}")

    if args.check:
        print("Check mode only. Manifest not updated.")
        if args.ci:
            set_github_output({
                "updated": "true",
                "version": ver,
                "amd64_sha": amd64_sha,
                "arm64_sha": arm64_sha
            })
        return 0

    today = datetime.date.today().isoformat()
    update_manifest(curr["content"], ver, amd64_sha, arm64_sha)
    update_metainfo(ver, today)

    if args.ci:
        set_github_output({
            "updated": "true",
            "version": ver,
            "amd64_sha": amd64_sha,
            "arm64_sha": arm64_sha
        })

    print(f"Successfully updated files for Claude Desktop v{ver}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
