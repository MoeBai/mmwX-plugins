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

while [[ $# -gt 0 ]]; do
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

# Detect OS and architecture
detect_platform() {
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"

  case "$OS" in
    linux) OS="linux" ;;
    linux*|linlx*) OS="linux" ;; 
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

# 自动检测并选择最优的镜像源
select_best_mirror() {
  echo "Checking network connectivity to find the best mirror..."
  
  # 定义候选镜像列表（末尾带 /）
  local mirrors=(
    "https://ghproxy.net/"
    "https://gh-proxy.com/"
    "https://mirror.ghproxy.com/"
  )
  
  BEST_MIRROR=""
  local min_time=999

  # 遍历测试每个镜像的响应时间
  for mirror in "${mirrors[@]}"; do
    # 使用 curl 测试连接，超时时间设为 2 秒
    local time
    time=$(curl -o /dev/null -s -w "%{time_total}" --connect-timeout 2 "${mirror}" || echo "999")
    
    # 如果连接成功且延迟更低，则更新最优镜像
    if (( $(echo "$time < $min_time" | bc 2>/dev/null || [ "${time%%.*}" -lt "${min_time%%.*}" ]) )); then
      min_time=$time
      BEST_MIRROR=$mirror
    fi
  done

  # 如果测出来的延迟都在正常范围内（没走 999 兜底），就启用镜像
  if [ "$BEST_MIRROR" != "" ] && [ "${BEST_MIRROR}" != "999" ] && (( $(echo "$min_time < 5" | bc 2>/dev/null || [ "${min_time%%.*}" -lt 5 ]) )); then
    echo "Selected mirror: ${BEST_MIRROR} (Response time: ${min_time}s)"
  else
    echo "No fast mirror available or networks look fine. Using official GitHub."
    BEST_MIRROR=""
  fi
}

# Get download URL from latest release
get_download_url() {
  local asset_name="${BINARY_NAME}-${OS}-${ARCH}"
  if [ "$OS" = "windows" ]; then
    asset_name="${asset_name}.exe"
  fi

  echo "Fetching latest release info..."
  local release_url="https://api.github.com/repos/${REPO}/releases/latest"
  local release_json
  
  # 如果连官方 API 都被墙，这里也尝试走一遍镜像代理（针对支持 API 代理的源）
  if [ -n "$BEST_MIRROR" ]; then
    release_json=$(curl -fsSL --connect-timeout 5 "${BEST_MIRROR}${release_url}" 2>/dev/null || curl -fsSL "${release_url}")
  else
    release_json=$(curl -fsSL "${release_url}")
  fi

  if [ -z "$release_json" ]; then
    echo "Failed to fetch release info"; exit 1
  fi

  DOWNLOAD_URL=$(echo "$release_json" | grep -o "\"browser_download_url\": *\"[^\"]*${asset_name}\"" | head -1 | cut -d'"' -f4)
  if [ -z "$DOWNLOAD_URL" ]; then
    echo "Asset ${asset_name} not found."
    echo "Visit https://github.com/${REPO}/releases/latest to download manually."
    exit 1
  fi

  # 将最优镜像前缀拼接到下载链接
  if [ -n "$BEST_MIRROR" ]; then
    DOWNLOAD_URL
