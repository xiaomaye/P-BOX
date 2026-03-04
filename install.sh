#!/bin/bash

set -e

############################################
# P-BOX Fixed Version Installer
############################################

VERSION="3.1.6"
INSTALL_DIR="/etc/p-box"
SERVICE_NAME="p-box"
DEFAULT_PORT=8666

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔══════════════════════════════════════╗"
echo "║     🚀 P-BOX Installer v${VERSION}      ║"
echo "╚══════════════════════════════════════╝"
echo -e "${NC}"

# 必须 root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Please run as root${NC}"
    exit 1
fi

# 自动识别架构
detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *)
            echo -e "${RED}Unsupported architecture: $(uname -m)${NC}"
            exit 1
            ;;
    esac
}

ARCH=$(detect_arch)

echo -e "${GREEN}✓ Architecture: ${ARCH}${NC}"

FILENAME="p-box-${VERSION}-linux-${ARCH}.tar.gz"
DOWNLOAD_URL="https://github.com/xiaomaye/P-BOX/releases/download/${VERSION}/${FILENAME}"

TEMP_DIR=$(mktemp -d)
TEMP_FILE="${TEMP_DIR}/${FILENAME}"

echo -e "${BLUE}⬇ Downloading ${FILENAME}...${NC}"

curl -L --retry 5 --retry-delay 3 -o "$TEMP_FILE" "$DOWNLOAD_URL"

echo -e "${GREEN}✓ Download completed${NC}"

# 停止旧服务
if systemctl is-active --quiet "$SERVICE_NAME"; then
    systemctl stop "$SERVICE_NAME"
fi

# 创建目录
mkdir -p "$INSTALL_DIR"

# 解压
tar -xzf "$TEMP_FILE" -C "$TEMP_DIR"

EXTRACT_DIR=$(find "$TEMP_DIR" -type d -name "p-box-*" | head -n 1)
[ -z "$EXTRACT_DIR" ] && EXTRACT_DIR="$TEMP_DIR"

cp -r "$EXTRACT_DIR"/* "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/p-box"

# 修改端口
if [ -f "$INSTALL_DIR/config.yaml" ]; then
    sed -i "s/port:.*/port: ${DEFAULT_PORT}/" "$INSTALL_DIR/config.yaml"
fi

rm -rf "$TEMP_DIR"

############################################
# 创建 systemd 服务
############################################

cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=P-BOX Proxy Management Panel
After=network.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/p-box
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

IP=$(hostname -I | awk '{print $1}')
[ -z "$IP" ] && IP="localhost"

echo ""
echo -e "${CYAN}══════════════════════════════════════${NC}"
echo -e "✅ Installation Complete"
echo -e "Version : ${VERSION}"
echo -e "Panel   : http://${IP}:${DEFAULT_PORT}"
echo -e "Path    : ${INSTALL_DIR}"
echo -e "${CYAN}══════════════════════════════════════${NC}"
echo ""