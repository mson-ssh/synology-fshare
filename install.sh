#!/bin/bash

REPO="https://raw.githubusercontent.com/mson-ssh/synology-fshare/main"
PLUGIN_DIR="/var/packages/DownloadStation/etc/download/userhosts/fshare-vn"
HOST_DIR="/var/packages/DownloadStation/target/hostscript/hosts/fshare-vn"
PYLOAD_HOSTER="/var/packages/DownloadStation/target/pyload/module/plugins/hoster"
PYLOAD_ACCOUNT="/var/packages/DownloadStation/target/pyload/module/plugins/accounts"
PYLOAD_CONF="/var/packages/DownloadStation/etc/pyload/plugin.conf"
HOST_ENABLED="/var/packages/DownloadStation/etc/download/host_enabled.conf"

echo "========================================"
echo "  Fshare.vn Plugin Installer"
echo "  for Synology Download Station"
echo "========================================"

if [ ! -f /etc/synoinfo.conf ]; then
    echo "[!] Script này chỉ chạy trên Synology NAS."
    exit 1
fi

if [ ! -d /volume1/@appstore/DownloadStation ]; then
    echo "[!] Download Station chưa được cài đặt."
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "[!] curl không có sẵn trên hệ thống."
    exit 1
fi

echo ""

# ── Xóa plugin cũ nếu có ─────────────────────────────────────────────────────
echo "[*] Dọn dẹp plugin cũ..."
rm -rf "$PLUGIN_DIR"
rm -rf "$HOST_DIR"
rm -rf "/var/packages/DownloadStation/etc/download/userhosts/fsharevn"
rm -rf "/var/packages/DownloadStation/target/hostscript/hosts/fsharevn"

# ── Tạo thư mục ──────────────────────────────────────────────────────────────
echo "[*] Tạo thư mục plugin..."
mkdir -p "$PLUGIN_DIR"
mkdir -p "$HOST_DIR"

# ── Tải host.php ─────────────────────────────────────────────────────────────
echo "[*] Tải host.php..."
curl -fsSL "$REPO/host.php" -o "$PLUGIN_DIR/host.php"
if [ $? -ne 0 ]; then
    echo "[!] Tải host.php thất bại."
    exit 1
fi
cp "$PLUGIN_DIR/host.php" "$HOST_DIR/host.php"
cp "$PLUGIN_DIR/host.php" "$HOST_DIR/fsharevn.php"

# ── Ghi INFO ─────────────────────────────────────────────────────────────────
echo "[*] Ghi INFO..."
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
echo "[*] Bật plugin..."
if ! grep -q "\[fshare-vn\]" "$HOST_ENABLED" 2>/dev/null; then
    echo "" >> "$HOST_ENABLED"
    echo "[fshare-vn]" >> "$HOST_ENABLED"
    echo "enable=1" >> "$HOST_ENABLED"
fi

# ── Update pyLoad ─────────────────────────────────────────────────────────────
echo "[*] Cập nhật pyLoad plugin..."
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

# ── Bật FshareVn trong pyLoad config ─────────────────────────────────────────
echo "[*] Bật FshareVn trong pyLoad..."
if [ -f "$PYLOAD_CONF" ]; then
    sed -i '/FshareVn - "FshareVn":/{n; s/= False/= True/}' "$PYLOAD_CONF"
fi

# ── Xóa session cache cũ ─────────────────────────────────────────────────────
echo "[*] Xóa session cache cũ..."
rm -rf /tmp/dsm_fsharevn/

# ── Restart DS ────────────────────────────────────────────────────────────────
echo "[*] Restart Download Station..."
synopkg stop DownloadStation > /dev/null 2>&1
sleep 2
synopkg start DownloadStation > /dev/null 2>&1
sleep 2

echo ""
echo "========================================"
echo "  [+] Cài đặt hoàn tất!"
echo ""
echo "  Bước tiếp theo:"
echo "  1. Mở Download Station"
echo "  2. Settings > File Hosting > Fshare.vn"
echo "  3. Edit > nhập email + password > Verify"
echo "========================================"
