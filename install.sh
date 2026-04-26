#!/bin/bash

REPO="https://raw.githubusercontent.com/mson-ssh/synology-fshare/main"
PHP_DIR1="/var/packages/DownloadStation/etc/download/userhosts/fsharevn"
PHP_DIR2="/var/packages/DownloadStation/target/hostscript/hosts/fsharevn"
PYLOAD_HOSTER="/var/packages/DownloadStation/target/pyload/module/plugins/hoster"
PYLOAD_ACCOUNT="/var/packages/DownloadStation/target/pyload/module/plugins/accounts"
PYLOAD_CONF="/var/packages/DownloadStation/etc/pyload/plugin.conf"

echo "========================================"
echo "  Fshare.vn Plugin Installer"
echo "  for Synology Download Station"
echo "========================================"

# Kiểm tra đang chạy trên Synology
if [ ! -f /etc/synoinfo.conf ]; then
    echo "[!] Script này chỉ chạy trên Synology NAS."
    exit 1
fi

# Kiểm tra Download Station đã cài chưa
if [ ! -d /volume1/@appstore/DownloadStation ]; then
    echo "[!] Download Station chưa được cài đặt."
    exit 1
fi

# Kiểm tra curl
if ! command -v curl &> /dev/null; then
    echo "[!] curl không có sẵn trên hệ thống."
    exit 1
fi

echo ""

# ── PHP plugin ────────────────────────────────────────────────────────────────
echo "[*] Cài đặt PHP plugin..."
mkdir -p "$PHP_DIR1"
mkdir -p "$PHP_DIR2"

curl -fsSL "$REPO/host.php" -o "$PHP_DIR1/host.php"
if [ $? -ne 0 ]; then
    echo "[!] Tải host.php thất bại."
    exit 1
fi
cp "$PHP_DIR1/host.php" "$PHP_DIR2/host.php"
cp "$PHP_DIR1/host.php" "$PHP_DIR2/fsharevn.php"

cat > "$PHP_DIR1/INFO" << 'JSON'
{
    "name":                  "fsharevn",
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
cp "$PHP_DIR1/INFO" "$PHP_DIR2/INFO"

# ── pyLoad plugin ─────────────────────────────────────────────────────────────
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

# ── Restart Download Station ──────────────────────────────────────────────────
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
