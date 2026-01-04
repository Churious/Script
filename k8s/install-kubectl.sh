#!/usr/bin/env bash

set -e
trap 'echo "[ERROR] kubectl installation failed (line $LINENO)" >&2; exit 1' ERR

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) KUBECTL_ARCH="amd64" ;;
  aarch64|arm64) KUBECTL_ARCH="arm64" ;;
  *)
    echo "[ERROR] Unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

# Fetch latest stable version (fail-fast)
KUBECTL_VERSION=$(curl -fsSL https://dl.k8s.io/release/stable.txt)

# Download kubectl
curl -fLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${KUBECTL_ARCH}/kubectl"

chmod +x kubectl
sudo mv kubectl /usr/bin/kubectl

# Optional short alias
sudo ln -sf /usr/bin/kubectl /usr/local/bin/k

# Verify
k version --client
