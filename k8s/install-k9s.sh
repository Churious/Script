#!/usr/bin/env bash
set -euo pipefail

trap 'echo "[ERROR] k9s installation failed (line $LINENO)" >&2; exit 1' ERR

REPO="derailed/k9s"

# ---- Detect architecture ----
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64)   K9S_ARCH="amd64" ;;
  aarch64|arm64)  K9S_ARCH="arm64" ;;
  armv7l|armv7)   K9S_ARCH="arm" ;;
  *)
    echo "[ERROR] Unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

# ---- Detect OS ----
OS="$(uname -s)"
case "$OS" in
  Linux)  K9S_OS="linux" ;;
  Darwin) K9S_OS="darwin" ;;
  *)
    echo "[ERROR] Unsupported OS: $OS" >&2
    exit 1
    ;;
esac

# ---- Requirements (minimal) ----
for cmd in curl tar grep sudo install uname mktemp; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "[ERROR] Missing required command: $cmd" >&2; exit 1; }
done

TMPDIR="$(mktemp -d)"
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

# ---- Choose preferred package format ----
# Linux: prefer native package manager if possible
PKG_EXT=""
if [[ "$K9S_OS" == "linux" ]]; then
  if command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1 || command -v zypper >/dev/null 2>&1; then
    PKG_EXT="rpm"
  elif command -v apt-get >/dev/null 2>&1 || command -v dpkg >/dev/null 2>&1; then
    PKG_EXT="deb"
  fi
fi

# ---- Fetch latest release metadata ----
API="https://api.github.com/repos/${REPO}/releases/latest"
JSON="$(curl -fsSL "$API")"

# Prefer jq if available, else fallback to grep/sed extraction
pick_url() {
  local ext="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg os "$K9S_OS" --arg arch "$K9S_ARCH" --arg ext "$ext" '
      .assets[]
      | select(.name == ("k9s_" + $os + "_" + $arch + "." + $ext))
      | .browser_download_url
    ' <<<"$JSON" | head -n 1
  else
    echo "$JSON" \
      | grep -Eo '"browser_download_url":[^"]*"https:[^"]+"' \
      | sed -E 's/^"browser_download_url":[^"]*"//; s/"$//' \
      | grep -E "k9s_${K9S_OS}_${K9S_ARCH}\.${ext}$" \
      | head -n 1
  fi
}

URL=""
if [[ -n "$PKG_EXT" ]]; then
  URL="$(pick_url "$PKG_EXT" || true)"
fi
if [[ -z "$URL" ]]; then
  URL="$(pick_url "tar.gz" || true)"
fi

if [[ -z "$URL" ]]; then
  echo "[ERROR] No suitable release asset found for ${K9S_OS}/${K9S_ARCH}" >&2
  echo "        Check: https://github.com/${REPO}/releases/latest" >&2
  exit 1
fi

echo "[INFO] Selected asset: $URL"

# ---- Download & install ----
if [[ "$URL" == *.rpm ]]; then
  FILE="$TMPDIR/k9s.rpm"
  curl -fL "$URL" -o "$FILE"

  if command -v dnf >/dev/null 2>&1; then
    sudo dnf -y install "$FILE"
  elif command -v yum >/dev/null 2>&1; then
    sudo yum -y localinstall "$FILE" || sudo yum -y install "$FILE"
  elif command -v zypper >/dev/null 2>&1; then
    sudo zypper --non-interactive install "$FILE"
  else
    sudo rpm -Uvh --replacepkgs "$FILE"
  fi

elif [[ "$URL" == *.deb ]]; then
  FILE="$TMPDIR/k9s.deb"
  curl -fL "$URL" -o "$FILE"

  sudo dpkg -i "$FILE" || true
  sudo apt-get -y -f install
  sudo dpkg -i "$FILE"

else
  FILE="$TMPDIR/k9s.tar.gz"
  curl -fL "$URL" -o "$FILE"

  tar -xzf "$FILE" -C "$TMPDIR"

  BIN="$(find "$TMPDIR" -maxdepth 2 -type f -name k9s | head -n 1 || true)"
  [[ -n "$BIN" && -f "$BIN" ]] || { echo "[ERROR] k9s binary not found in tarball" >&2; exit 1; }

  sudo install -m 0755 "$BIN" /usr/local/bin/k9s
fi

echo "[INFO] Installed: $(command -v k9s)"
k9s version || true
