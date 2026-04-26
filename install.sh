#!/bin/bash

REPO="https://raw.githubusercontent.com/mson-ssh/synology-fshare/main"
PLUGIN_DIR="/var/packages/DownloadStation/etc/download/userhosts/fshare-vn"
HOST_DIR="/var/packages/DownloadStation/target/hostscript/hosts/fshare-vn"
PYLOAD_HOSTER="/var/packages/DownloadStation/target/pyload/module/plugins/hoster"
PYLOAD_ACCOUNT="/var/packages/DownloadStation/target/pyload/module/plugins/accounts"
PYLOAD_CONF="/var/packages/DownloadStation/etc/pyload/plugin.conf"
HOST_ENABLED="/var/packages/DownloadStation/etc/download/host_enabled.conf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${BOLD}Fshare.vn Plugin Installer${NC}               ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  for Synology Download Station            ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

if [ ! -f /etc/synoinfo.conf ]; then
    echo -e "${RED}  ✗ Script này chỉ chạy trên Synology NAS.${NC}"
    exit 1
fi

if [ ! -d /volume1/@appstore/DownloadStation ]; then
    echo -e "${RED}  ✗ Download Station chưa được cài đặt.${NC}"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo -e "${RED}  ✗ curl không có sẵn trên hệ thống.${NC}"
    exit 1
fi

echo ""

# ── Xóa plugin cũ nếu có ─────────────────────────────────────────────────────
echo -e "${YELLOW}  →${NC} Dọn dẹp plugin cũ..."
rm -rf "$PLUGIN_DIR"
rm -rf "$HOST_DIR"
rm -rf "/var/packages/DownloadStation/etc/download/userhosts/fsharevn"
rm -rf "/var/packages/DownloadStation/target/hostscript/hosts/fsharevn"

# ── Tạo thư mục ──────────────────────────────────────────────────────────────
echo -e "${YELLOW}  →${NC} Tạo thư mục plugin..."
mkdir -p "$PLUGIN_DIR"
mkdir -p "$HOST_DIR"

# ── Tải host.php ─────────────────────────────────────────────────────────────
echo -e "${YELLOW}  →${NC} Tải host.php..."
curl -fsSL "$REPO/host.php" -o "$PLUGIN_DIR/host.php"
if [ $? -ne 0 ]; then
    echo -e "${RED}  ✗ Tải host.php thất bại.${NC}"
    exit 1
fi
cp "$PLUGIN_DIR/host.php" "$HOST_DIR/host.php"
cp "$PLUGIN_DIR/host.php" "$HOST_DIR/fsharevn.php"

# ── Ghi INFO ─────────────────────────────────────────────────────────────────
echo -e "${YELLOW}  →${NC} Ghi INFO..."
cat > "$PLUGIN_DIR/INFO" << 'JSON'
{
    "name":                  "fshare-vn",
    "hostprefix":            "fshare.vn,www.fshare.vn",
    "displayname":           "Fshare.vn",
    "version":               "1.0",
    "majorversion":          "3",
    "minorversion":          "4",
    "minfirmware":           "2600",
    "min_dl_major_version":  "3",
    "min_dl_minor_version":  "4",
    "min_dl_build":          "2600",
    "authentication":        "yes",
    "module":                "host.php",
    "class":                 "SynoFileHostingFshareVn",
    "supporttasklist":       "yes",
    "description":           "Update 04.2026"
}
JSON
cp "$PLUGIN_DIR/INFO" "$HOST_DIR/INFO"

# ── Bật plugin trong host_enabled.conf ───────────────────────────────────────
echo -e "${YELLOW}  →${NC} Bật plugin..."
if ! grep -q "\[fshare-vn\]" "$HOST_ENABLED" 2>/dev/null; then
    echo "" >> "$HOST_ENABLED"
    echo "[fshare-vn]" >> "$HOST_ENABLED"
    echo "enable=1" >> "$HOST_ENABLED"
fi

# ── Update pyLoad ─────────────────────────────────────────────────────────────
echo -e "${YELLOW}  →${NC} Cập nhật pyLoad plugin..."
if [ -f "$PYLOAD_HOSTER/FshareVn.py" ]; then
    cp "$PYLOAD_HOSTER/FshareVn.py" "$PYLOAD_HOSTER/FshareVn.py.bak"
    sed -i 's/L2S7R6ZMagggC5wWkQhX2+aDi467PPuftWUMRFSn/dMnqMMZMUnN5YpvKENaEhdQQ5jxDqddt/g' "$PYLOAD_HOSTER/FshareVn.py"
    sed -i 's/okhttp\/3.6.0/pyLoad-B1RS5N/g' "$PYLOAD_HOSTER/FshareVn.py"
    rm -f "$PYLOAD_HOSTER/FshareVn.pyc"
fi

if [ -f "$PYLOAD_ACCOUNT/FshareVn.py" ]; then
    cp "$PYLOAD_ACCOUNT/FshareVn.py" "$PYLOAD_ACCOUNT/FshareVn.py.bak"
    sed -i 's/L2S7R6ZMagggC5wWkQhX2+aDi467PPuftWUMRFSn/dMnqMMZMUnN5YpvKENaEhdQQ5jxDqddt/g' "$PYLOAD_ACCOUNT/FshareVn.py"
    sed -i 's/okhttp\/3.6.0/pyLoad-B1RS5N/g' "$PYLOAD_ACCOUNT/FshareVn.py"
    rm -f "$PYLOAD_ACCOUNT/FshareVn.pyc"
fi

# ── Tắt FshareVn pyLoad mặc định, bật plugin mới ────────────────────────────
echo -e "${YELLOW}  →${NC} Cập nhật cấu hình pyLoad..."
if [ -f "$PYLOAD_CONF" ]; then
    # Tắt plugin FshareVn mặc định của pyLoad
    sed -i '/^FshareVn - "FshareVn":$/{n; s/bool activated : "Activated" = True/bool activated : "Activated" = False/}' "$PYLOAD_CONF"
fi

# ── Fix owner ────────────────────────────────────────────────────────────────
echo -e "${YELLOW}  →${NC} Fix quyền truy cập..."
chown -R DownloadStation:DownloadStation "$PLUGIN_DIR"
chmod -R 755 "$PLUGIN_DIR"

# ── Xóa session cache cũ ─────────────────────────────────────────────────────
echo -e "${YELLOW}  →${NC} Xóa session cache cũ..."
rm -rf /tmp/dsm_fshare-vn/

# ── Restart DS ────────────────────────────────────────────────────────────────
echo -e "${YELLOW}  →${NC} Restart Download Station..."
synopkg stop DownloadStation > /dev/null 2>&1
sleep 2
synopkg start DownloadStation > /dev/null 2>&1
sleep 2

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}  ${BOLD}✓ Cài đặt hoàn tất!${NC}                      ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Bước tiếp theo:${NC}"
echo -e "  ${CYAN}1.${NC} Mở Download Station"
echo -e "  ${CYAN}2.${NC} Settings → File Hosting → ${BOLD}Fshare.vn${NC}"
echo -e "  ${CYAN}3.${NC} Edit → nhập email + password → Verify"
echo ""
echo -e "  ${BOLD}Enjoy! <3${NC}"
echo ""
