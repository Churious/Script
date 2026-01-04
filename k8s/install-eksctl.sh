#!/usr/bin/env bash
set -euo pipefail

trap 'echo "[ERROR] eksctl installation failed (line $LINENO)" >&2; exit 1' ERR

# Detect architecture
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64) EKSCTL_ARCH="amd64" ;;
  aarch64|arm64) EKSCTL_ARCH="arm64" ;;
  *)
    echo "[ERROR] Unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

# Detect OS and build platform string used by eksctl release assets
OS="$(uname -s)"
case "$OS" in
  Linux|Darwin) : ;;
  *)
    echo "[ERROR] Unsupported OS: $OS" >&2
    exit 1
    ;;
esac

PLATFORM="${OS}_${EKSCTL_ARCH}"

# Requirements (light sanity check)
for cmd in curl tar sha256sum grep sudo install; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "[ERROR] Missing required command: $cmd" >&2; exit 1; }
done

TMPDIR="$(mktemp -d)"
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

TARBALL="eksctl_${PLATFORM}.tar.gz"
CHECKSUMS="eksctl_checksums.txt"

# Download tarball and checksums (fail-fast on HTTP errors)
curl -fsSLO "https://github.com/eksctl-io/eksctl/releases/latest/download/${TARBALL}"
curl -fsSL  "https://github.com/eksctl-io/eksctl/releases/latest/download/${CHECKSUMS}" -o "${CHECKSUMS}"

# Verify checksum (will exit non-zero on mismatch)
grep " ${TARBALL}\$" "${CHECKSUMS}" | sha256sum -c -

# Extract and install
tar -xzf "${TARBALL}" -C "$TMPDIR"

sudo install -m 0755 "$TMPDIR/eksctl" /usr/local/bin/eksctl

# Verify
eksctl version
