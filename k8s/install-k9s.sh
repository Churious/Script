#!/usr/bin/env bash
set -euo pipefail

REPO="derailed/k9s"
OS="linux"

need() { command -v "$1" >/dev/null 2>&1; }

fetch() {
  local url="$1"
  if need curl; then curl -fsSL "$url"
  else wget -qO- "$url"
  fi
}

download_to() {
  local url="$1" out="$2"
  if need curl; then curl -fL "$url" -o "$out"
  else wget -q "$url" -O "$out"
  fi
}

# ---- prerequisites ----
if ! need curl && ! need wget; then
  echo "ERROR: curl or wget is required." >&2
  exit 1
fi

# ---- arch detect ----
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64)   ARCH="amd64" ;;
  aarch64|arm64)  ARCH="arm64" ;;
  armv7l|armv7|armv6l|armv6) ARCH="arm" ;;
  *) echo "ERROR: Unsupported arch: $ARCH" >&2; exit 1 ;;
esac

# ---- choose pkg type by system ----
PKG=""
if need dnf || need yum || need zypper || need rpm; then
  PKG="rpm"
elif need apt-get || need dpkg; then
  PKG="deb"
fi

# ---- get latest asset url (jq if available) ----
API="https://api.github.com/repos/${REPO}/releases/latest"
JSON="$(fetch "$API")"

pick_url_jq() {
  local ext="$1"
  jq -r --arg os "$OS" --arg arch "$ARCH" --arg ext "$ext" '
    .assets[]
    | select(.name == ("k9s_" + $os + "_" + $arch + "." + $ext))
    | .browser_download_url
  ' <<<"$JSON" | head -n 1
}

pick_url_grep() {
  local ext="$1"
  echo "$JSON" \
    | grep -Eo '"browser_download_url":[^"]*"https:[^"]+"' \
    | sed -E 's/^"browser_download_url":[^"]*"//; s/"$//' \
    | grep -E "k9s_${OS}_${ARCH}\.${ext}$" \
    | head -n 1
}

pick_url() {
  local ext="$1"
  if need jq; then pick_url_jq "$ext"
  else pick_url_grep "$ext"
  fi
}

URL=""
if [[ -n "$PKG" ]]; then
  URL="$(pick_url "$PKG" || true)"
fi
if [[ -z "$URL" ]]; then
  URL="$(pick_url "tar.gz" || true)"
fi

if [[ -z "$URL" ]]; then
  echo "ERROR: No asset found for ${OS}/${ARCH}." >&2
  echo "Check: https://github.com/${REPO}/releases/latest" >&2
  exit 1
fi

echo "Selected: $URL"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# ---- install ----
if [[ "$URL" == *.rpm ]]; then
  FILE="$TMPDIR/k9s.rpm"
  download_to "$URL" "$FILE"

  if need dnf; then
    sudo dnf -y install "$FILE"
  elif need yum; then
    sudo yum -y localinstall "$FILE" || sudo yum -y install "$FILE"
  elif need zypper; then
    sudo zypper --non-interactive install "$FILE"
  else
    # last resort: rpm (deps not handled)
    sudo rpm -Uvh --replacepkgs "$FILE"
  fi

elif [[ "$URL" == *.deb ]]; then
  FILE="$TMPDIR/k9s.deb"
  download_to "$URL" "$FILE"

  sudo dpkg -i "$FILE" || true
  if need apt-get; then
    sudo apt-get -y -f install
    sudo dpkg -i "$FILE"
  else
    echo "ERROR: dpkg install failed and apt-get not found." >&2
    exit 1
  fi

else
  FILE="$TMPDIR/k9s.tar.gz"
  download_to "$URL" "$FILE"
  tar -xzf "$FILE" -C "$TMPDIR"

  BIN="$(find "$TMPDIR" -maxdepth 2 -type f -name k9s | head -n 1 || true)"
  [[ -n "$BIN" && -f "$BIN" ]] || { echo "ERROR: k9s binary not found in tar." >&2; exit 1; }

  sudo install -m 0755 "$BIN" /usr/local/bin/k9s
fi

echo "Installed: $(command -v k9s)"
k9s version || true
