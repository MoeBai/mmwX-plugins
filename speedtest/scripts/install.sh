#!/bin/bash
# mmwx-speedtester install & run script
# Usage: curl -fsSL <url>/install.sh | bash -s -- -master https://your-master-url -token <token>
set -e

REPO="MMWOrg/mmwX-plugins"
BINARY_NAME="mmwx-speedtester"
INSTALL_DIR="."

# Parse arguments
MASTER=""
TOKEN=""

while [ $# -gt 0 ]; do
  case "$1" in
    -master) MASTER="$2"; shift 2 ;;
    -token) TOKEN="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

if [ -z "$MASTER" ] || [ -z "$TOKEN" ]; then
  echo "Usage: bash install.sh -master <master-url> -token <token>"
  exit 1
fi

detect_platform() {
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"

  case "$OS" in
    linux|linux*|linlx*) OS="linux" ;;
    darwin) OS="darwin" ;;
    mingw*|msys*|cygwin*) OS="windows" ;;
    *) echo "Unsupported OS: $OS"; exit 1 ;;
  esac

  case "$ARCH" in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
  esac
}

select_best_mirror() {
  echo "Checking network connectivity to find the best mirror..."

  BEST_MIRROR="https://gcode.hostcentral.cc/"
  local min_time=999

  # # 放弃数组，直接使用字符串循环，完美兼容各类精简环境
  # for mirror in "https://gh-proxy.com/" "https://mirror.ghproxy.com/"; do
  #   local time_str
  #   time_str=$(curl -o /dev/null -s -w "%{time_total}" --connect-timeout 2 "${mirror}" || echo "999")

  #   # 截取小数点前的整数
  #   local time_int="${time_str%%.*}"

  #   # 纯数字校验，使用最兼容的 case 写法替代正则表达式
  #   case "$time_int" in
  #       ''|*[!0-9]*) time_int=999 ;;
  #   esac

  #   if [ "$time_int" -lt "$min_time" ]; then
  #     min_time=$time_int
  #     BEST_MIRROR=$mirror
  #   fi
  # done

  if [ -n "$BEST_MIRROR" ] && [ "$min_time" -lt 5 ]; then
    echo "Selected mirror: ${BEST_MIRROR}"
  else
    echo "No fast mirror available. Using official GitHub."
    BEST_MIRROR=""
  fi
}

get_download_url() {
  local asset_name="${BINARY_NAME}-${OS}-${ARCH}"
  if [ "$OS" = "windows" ]; then
    asset_name="${asset_name}.exe"
  fi

  echo "Fetching latest release info..."
  local release_url="https://api.github.com/repos/${REPO}/releases/latest"
  local release_json

  if [ -n "$BEST_MIRROR" ]; then
    release_json=$(curl -fsSL --connect-timeout 5 "${BEST_MIRROR}${release_url}" 2>/dev/null || curl -fsSL "${release_url}")
  else
    release_json=$(curl -fsSL "${release_url}")
  fi

  if [ -z "$release_json" ]; then
    echo "Failed to fetch release info"; exit 1
  fi

  DOWNLOAD_URL=$(echo "$release_json" | grep -o '"browser_download_url": *"[^"]*'${asset_name}'"' | head -1 | cut -d'"' -f4)
  if [ -z "$DOWNLOAD_URL" ]; then
    echo "Asset ${asset_name} not found."
    echo "Visit https://github.com/${REPO}/releases/latest to download manually."
    exit 1
  fi

  if [ -n "$BEST_MIRROR" ]; then
    DOWNLOAD_URL="${BEST_MIRROR}${DOWNLOAD_URL}"
  fi

  VERSION=$(echo "$release_json" | grep -o '"tag_name": *"[^"]*"' | head -1 | cut -d'"' -f4)
  echo "Latest version: ${VERSION}"
}

download_binary() {
  local output="${INSTALL_DIR}/${BINARY_NAME}"
  if [ "$OS" = "windows" ]; then
    output="${output}.exe"
  fi

  echo "Downloading from: ${DOWNLOAD_URL}"
  curl -fsSL -o "$output" "$DOWNLOAD_URL" || {
    echo "Download failed"; exit 1
  }
  chmod +x "$output"
  echo "Saved to: ${output}"
  BINARY_PATH="$output"
}

run_binary() {
  echo ""
  echo "========================================"
  echo "Master: ${MASTER}"
  echo "========================================"
  echo ""
  exec "$BINARY_PATH" -master "$MASTER" -token "$TOKEN"
}

detect_platform
select_best_mirror
get_download_url
download_binary
run_binary
