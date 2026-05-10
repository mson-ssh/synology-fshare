#!/bin/bash

REPO="https://raw.githubusercontent.com/mson-ssh/synology-fshare/main"
PLUGIN_DIR="/var/packages/DownloadStation/etc/download/userhosts/fshare-vn"
HOST_DIR="/var/packages/DownloadStation/target/hostscript/hosts/fshare-vn"
PYLOAD_HOSTER="/var/packages/DownloadStation/target/pyload/module/plugins/hoster"
PYLOAD_ACCOUNT="/var/packages/DownloadStation/target/pyload/module/plugins/accounts"
PYLOAD_CONF="/var/packages/DownloadStation/etc/pyload/plugin.conf"
HOST_ENABLED="/var/packages/DownloadStation/etc/download/host_enabled.conf"
TARGET_PYLOAD_CONF="/var/packages/DownloadStation/target/etc/pyload/plugin.conf"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
print_header() {
    echo ""
    echo -e "${CYAN}--------------------------------------------${NC}"
    echo -e "  ${BOLD}Fshare.vn Plugin Installer${NC}"
    echo -e "  for Synology Download Station"
    echo -e "${CYAN}--------------------------------------------${NC}"
    echo ""
}

exit_if_failed() {
    local status="$1"
    local message="$2"
    if [ "$status" -ne 0 ]; then
        echo -e "${RED}  ✗ ${message}${NC}"
        exit 1
    fi
}

has_root() {
    [ "$(id -u)" -eq 0 ]
}

find_downloadstation_volume() {
    local path
    for path in /volume*/@appstore/DownloadStation; do
        if [ -d "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    return 1
}

append_unique_path() {
    local candidate="$1"

    [ -n "$candidate" ] || return 0
    [ -f "$candidate" ] || return 0

    case "|$PYLOAD_CONF_PATHS|" in
        *"|$candidate|"*) ;;
        *)
            if [ -n "$PYLOAD_CONF_PATHS" ]; then
                PYLOAD_CONF_PATHS="$PYLOAD_CONF_PATHS|$candidate"
            else
                PYLOAD_CONF_PATHS="$candidate"
            fi
            ;;
    esac
}

build_pyload_conf_paths() {
    local etc_real target_real

    PYLOAD_CONF_PATHS=""

    append_unique_path "$PYLOAD_CONF"
    append_unique_path "$TARGET_PYLOAD_CONF"

    etc_real="$(readlink -f /var/packages/DownloadStation/etc 2>/dev/null)"
    target_real="$(readlink -f /var/packages/DownloadStation/target 2>/dev/null)"

    # Keep plugin.conf patching narrow to avoid changing unrelated config copies.
    # We only follow the Synology package symlinks exposed through /var/packages.
    append_unique_path "$etc_real/pyload/plugin.conf"
    append_unique_path "$target_real/etc/pyload/plugin.conf"
}

for_each_pyload_conf() {
    local old_ifs conf
    old_ifs="$IFS"
    IFS='|'
    for conf in $PYLOAD_CONF_PATHS; do
        [ -n "$conf" ] && printf '%s\n' "$conf"
    done
    IFS="$old_ifs"
}

check_system_environment() {
    echo ""
    echo -e "${BOLD}System environment check${NC}"

    if [ -f /etc/synoinfo.conf ]; then
        echo -e "${GREEN}  ✓${NC} Synology DSM detected"
    else
        echo -e "${RED}  ✗${NC} Synology DSM not detected"
    fi

    if has_root; then
        echo -e "${GREEN}  ✓${NC} Running with root privileges"
    else
        echo -e "${RED}  ✗${NC} Not running as root (run ${BOLD}sudo -i${NC}${RED} first)${NC}"
    fi

    if [ -n "$DS_APP_PATH" ]; then
        echo -e "${GREEN}  ✓${NC} Download Station package found at ${DS_APP_PATH}"
    else
        echo -e "${RED}  ✗${NC} Download Station package not found"
    fi

    if command -v curl >/dev/null 2>&1; then
        echo -e "${GREEN}  ✓${NC} curl is available"
    else
        echo -e "${RED}  ✗${NC} curl is not available"
    fi

    if [ -f "$HOST_ENABLED" ]; then
        echo -e "${GREEN}  ✓${NC} host_enabled.conf found"
    else
        echo -e "${YELLOW}  !${NC} host_enabled.conf not found"
    fi

    if [ -f "$PYLOAD_CONF" ]; then
        echo -e "${GREEN}  ✓${NC} pyLoad plugin.conf found"
    else
        echo -e "${YELLOW}  !${NC} pyLoad plugin.conf not found"
    fi

    if [ -f "$TARGET_PYLOAD_CONF" ]; then
        echo -e "${GREEN}  ✓${NC} Runtime pyLoad plugin.conf found"
    else
        echo -e "${YELLOW}  !${NC} Runtime pyLoad plugin.conf not found"
    fi

    if [ -f "$PYLOAD_HOSTER/FshareVn.py" ]; then
        echo -e "${GREEN}  ✓${NC} pyLoad hoster plugin found"
    else
        echo -e "${YELLOW}  !${NC} pyLoad hoster plugin not found"
    fi

    if [ -f "$PYLOAD_ACCOUNT/FshareVn.py" ]; then
        echo -e "${GREEN}  ✓${NC} pyLoad account plugin found"
    else
        echo -e "${YELLOW}  !${NC} pyLoad account plugin not found"
    fi

    if curl -fsI "$REPO/host.php" >/dev/null 2>&1; then
        echo -e "${GREEN}  ✓${NC} Network access to GitHub raw is working"
    else
        echo -e "${YELLOW}  !${NC} Unable to verify GitHub raw access"
    fi

    if command -v synopkg >/dev/null 2>&1; then
        echo -e "${GREEN}  ✓${NC} synopkg is available"
        synopkg status DownloadStation >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}  ✓${NC} Download Station package responds to synopkg"
        else
            echo -e "${YELLOW}  !${NC} Download Station package did not respond to synopkg status"
        fi
    else
        echo -e "${YELLOW}  !${NC} synopkg is not available"
    fi

    if id DownloadStation >/dev/null 2>&1; then
        echo -e "${GREEN}  ✓${NC} DownloadStation user/group exists"
    else
        echo -e "${YELLOW}  !${NC} DownloadStation user/group not found"
    fi

    if [ -d "$PLUGIN_DIR" ]; then
        ls -ld "$PLUGIN_DIR" 2>/dev/null | sed 's/^/    /'
    fi

    if [ -d "$HOST_DIR" ]; then
        ls -ld "$HOST_DIR" 2>/dev/null | sed 's/^/    /'
    fi

    echo ""
}

check_plugin_status() {
    echo ""
    echo -e "${BOLD}Current plugin status${NC}"

    if [ -f "$PLUGIN_DIR/host.php" ] && [ -f "$PLUGIN_DIR/INFO" ]; then
        echo -e "${GREEN}  ✓${NC} Custom host module files are installed"
    else
        echo -e "${YELLOW}  !${NC} Custom host module files are missing or incomplete"
    fi

    if [ -d "$PLUGIN_DIR" ]; then
        ls -ld "$PLUGIN_DIR" 2>/dev/null | sed 's/^/    /'
        find "$PLUGIN_DIR" -maxdepth 1 -type f 2>/dev/null | sort | while read file; do
            ls -l "$file" 2>/dev/null | sed 's/^/    /'
        done
    fi

    if [ -d "$HOST_DIR" ]; then
        ls -ld "$HOST_DIR" 2>/dev/null | sed 's/^/    /'
        find "$HOST_DIR" -maxdepth 1 -type f 2>/dev/null | sort | while read file; do
            ls -l "$file" 2>/dev/null | sed 's/^/    /'
        done
    else
        echo -e "${YELLOW}  !${NC} Hostscript directory does not exist"
    fi

    if grep -q "\[fshare-vn\]" "$HOST_ENABLED" 2>/dev/null; then
        echo -e "${GREEN}  ✓${NC} host_enabled.conf contains the plugin entry"
        grep -n -A2 -B1 'fshare-vn' "$HOST_ENABLED" 2>/dev/null | sed 's/^/    /'
    else
        echo -e "${YELLOW}  !${NC} host_enabled.conf does not contain the plugin entry"
    fi

    build_pyload_conf_paths
    if [ -n "$PYLOAD_CONF_PATHS" ]; then
        for conf in $(for_each_pyload_conf); do
            if grep -A1 '^FshareVn - "FshareVn":$' "$conf" 2>/dev/null | grep -q 'False'; then
                echo -e "${GREEN}  ✓${NC} pyLoad Fshare plugin appears to be disabled in: $conf"
            else
                echo -e "${YELLOW}  !${NC} pyLoad Fshare plugin may still be enabled in: $conf"
            fi
            grep -n -A3 -B1 'FshareVn' "$conf" 2>/dev/null | sed 's/^/    /'
        done
    else
        echo -e "${YELLOW}  !${NC} No pyLoad plugin.conf file was found"
    fi

    if [ -f "$PYLOAD_HOSTER/FshareVn.py" ]; then
        echo -e "${GREEN}  ✓${NC} pyLoad hoster file exists"
        ls -l "$PYLOAD_HOSTER/FshareVn.py" 2>/dev/null | sed 's/^/    /'
    fi

    if [ -f "$PYLOAD_ACCOUNT/FshareVn.py" ]; then
        echo -e "${GREEN}  ✓${NC} pyLoad account file exists"
        ls -l "$PYLOAD_ACCOUNT/FshareVn.py" 2>/dev/null | sed 's/^/    /'
    fi

    echo ""
}

show_runtime_summary() {
    echo ""
    echo -e "${BOLD}Runtime summary${NC}"
    echo -e "  Plugin directory : ${PLUGIN_DIR}"
    echo -e "  Hostscript dir   : ${HOST_DIR}"
    echo -e "  host_enabled.conf: ${HOST_ENABLED}"
    echo -e "  pyLoad conf      : ${PYLOAD_CONF}"
    echo ""
}

disable_pyload_fshare_plugin() {
    local conf
    local found_any=0

    echo -e "${YELLOW}  →${NC} Cập nhật cấu hình pyLoad..."

    build_pyload_conf_paths
    for conf in $(for_each_pyload_conf); do
        found_any=1
        sed -i '/^FshareVn - "FshareVn":$/{n; s/bool activated : "Activated" = True/bool activated : "Activated" = False/}' "$conf"
        exit_if_failed $? "Failed to update pyLoad plugin.conf: $conf"
    done

    if [ "$found_any" -eq 0 ]; then
        echo -e "${YELLOW}  !${NC} No plugin.conf file was found for pyLoad"
    fi
}

enable_pyload_fshare_plugin() {
    local conf

    echo -e "${YELLOW}  →${NC} Re-enabling default pyLoad Fshare plugin..."

    build_pyload_conf_paths
    for conf in $(for_each_pyload_conf); do
        sed -i '/^FshareVn - "FshareVn":$/{n; s/bool activated : "Activated" = False/bool activated : "Activated" = True/}' "$conf"
        exit_if_failed $? "Failed to restore pyLoad plugin.conf: $conf"
    done
}

set_runtime_permissions() {
    echo -e "${YELLOW}  →${NC} Applying runtime permissions..."

    if id DownloadStation >/dev/null 2>&1; then
        chown -R DownloadStation:DownloadStation "$PLUGIN_DIR"
        exit_if_failed $? "Failed to set ownership on plugin directory."

        chown -R DownloadStation:DownloadStation "$HOST_DIR"
        exit_if_failed $? "Failed to set ownership on hostscript directory."
    else
        echo -e "${YELLOW}  !${NC} DownloadStation user/group not found. Skipping chown."
    fi

    chmod 755 "$HOST_DIR"
    exit_if_failed $? "Failed to set permissions on hostscript directory."

    find "$HOST_DIR" -mindepth 1 -type d -exec chmod 755 {} \;
    exit_if_failed $? "Failed to set directory permissions inside hostscript directory."

    # Keep PLUGIN_DIR close to the legacy working installer behavior.
    chmod -R 755 "$PLUGIN_DIR"
    exit_if_failed $? "Failed to set permissions on plugin directory."

    find "$HOST_DIR" -type f -exec chmod 644 {} \;
    exit_if_failed $? "Failed to set file permissions inside hostscript directory."

    if [ -f "$PLUGIN_DIR/custom_api_key.txt" ]; then
        chmod 640 "$PLUGIN_DIR/custom_api_key.txt"
        exit_if_failed $? "Failed to set permissions on custom API key file."
    fi
}

verify_runtime_permissions() {
    echo -e "${YELLOW}  →${NC} Verifying runtime permissions..."

    [ -d "$PLUGIN_DIR" ] || exit_if_failed 1 "Plugin directory is missing after installation."
    [ -d "$HOST_DIR" ] || exit_if_failed 1 "Hostscript directory is missing after installation."

    [ -r "$PLUGIN_DIR/host.php" ] || exit_if_failed 1 "host.php is not readable in plugin directory."
    [ -r "$PLUGIN_DIR/INFO" ] || exit_if_failed 1 "INFO is not readable in plugin directory."
    [ -r "$HOST_DIR/host.php" ] || exit_if_failed 1 "host.php is not readable in hostscript directory."
    [ -r "$HOST_DIR/fsharevn.php" ] || exit_if_failed 1 "fsharevn.php is not readable in hostscript directory."
    [ -r "$HOST_DIR/INFO" ] || exit_if_failed 1 "INFO is not readable in hostscript directory."

    if ! ls -ld "$HOST_DIR" >/dev/null 2>&1; then
        exit_if_failed 1 "Failed to inspect hostscript directory permissions."
    fi

    echo -e "${GREEN}  ✓${NC} Runtime paths and files are readable"
}

verify_uninstall_state() {
    echo -e "${YELLOW}  →${NC} Verifying uninstall state..."

    if [ -d "$PLUGIN_DIR" ] || [ -d "$HOST_DIR" ]; then
        exit_if_failed 1 "Plugin directories still exist after uninstall."
    fi

    if grep -q "\[fshare-vn\]" "$HOST_ENABLED" 2>/dev/null; then
        exit_if_failed 1 "host_enabled.conf still contains the fshare-vn entry."
    fi

    echo -e "${GREEN}  ✓${NC} Custom plugin files and config entries were removed"
}

perform_install() {
    local mode_label="$1"

    echo ""
    echo -e "${BOLD}Chế độ hiện tại:${NC} ${mode_label}"
    echo ""

    # ── Dọn dẹp plugin cũ ────────────────────────────────────────────────────
    echo -e "${YELLOW}  →${NC} Dọn dẹp plugin cũ..."
    rm -rf "$PLUGIN_DIR"
    rm -rf "$HOST_DIR"
    rm -rf "/var/packages/DownloadStation/etc/download/userhosts/fsharevn"
    rm -rf "/var/packages/DownloadStation/target/hostscript/hosts/fsharevn"
    exit_if_failed $? "Failed to remove old plugin files."

    # ── Tạo thư mục ──────────────────────────────────────────────────────────
    echo -e "${YELLOW}  →${NC} Tạo thư mục plugin..."
    mkdir -p "$PLUGIN_DIR"
    mkdir -p "$HOST_DIR"
    exit_if_failed $? "Failed to create plugin directories."

    # ── Tải host.php ─────────────────────────────────────────────────────────
    echo -e "${YELLOW}  →${NC} Tải host.php..."
    curl -fsSL "$REPO/host.php" -o "$PLUGIN_DIR/host.php"
    exit_if_failed $? "Failed to download host.php."
    cp "$PLUGIN_DIR/host.php" "$HOST_DIR/host.php"
    cp "$PLUGIN_DIR/host.php" "$HOST_DIR/fsharevn.php"
    exit_if_failed $? "Failed to copy host.php into hostscript directory."

    # ── Ghi INFO ─────────────────────────────────────────────────────────────
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
    exit_if_failed $? "Failed to write INFO metadata."

    # ── Lưu custom API key nếu có ────────────────────────────────────────────
    if [ -n "$CUSTOM_API_KEY" ]; then
        echo "$CUSTOM_API_KEY" > "$PLUGIN_DIR/custom_api_key.txt"
        echo -e "${YELLOW}  →${NC} Đã lưu custom API key"
        exit_if_failed $? "Failed to save custom API key."
    fi

    # ── Bật plugin ───────────────────────────────────────────────────────────
    echo -e "${YELLOW}  →${NC} Bật plugin..."
    if ! grep -q "\[fshare-vn\]" "$HOST_ENABLED" 2>/dev/null; then
        echo "" >> "$HOST_ENABLED"
        echo "[fshare-vn]" >> "$HOST_ENABLED"
        echo "enable=1" >> "$HOST_ENABLED"
    fi

    # ── Cập nhật pyLoad ───────────────────────────────────────────────────────
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

    disable_pyload_fshare_plugin

    # ── Fix owner ────────────────────────────────────────────────────────────
    echo -e "${YELLOW}  →${NC} Fix quyền truy cập..."
    set_runtime_permissions

    # ── Xóa session cache ─────────────────────────────────────────────────────
    echo -e "${YELLOW}  →${NC} Xóa session cache cũ..."
    rm -rf /tmp/dsm_fshare-vn/
    exit_if_failed $? "Failed to clear old session cache."

    # ── Restart DS ────────────────────────────────────────────────────────────
    echo -e "${YELLOW}  →${NC} Restart Download Station..."
    synopkg stop DownloadStation && synopkg start DownloadStation
    exit_if_failed $? "Failed to restart Download Station."
    sleep 2
    if ! synopkg status DownloadStation >/dev/null 2>&1; then
        echo -e "${YELLOW}  !${NC} Download Station restart could not be verified automatically."
    fi

    verify_runtime_permissions

    echo -e "${YELLOW}  →${NC} Verifying plugin state..."
    check_plugin_status
}

uninstall_plugin() {
    echo ""
    echo -e "${RED}  Are you sure you want to uninstall the plugin?${NC}"
    read -p "  Confirm [y/N]: " CONFIRM_UNINSTALL
    if [[ ! "$CONFIRM_UNINSTALL" =~ ^[Yy]$ ]]; then
        echo -e "  ${YELLOW}→${NC} Uninstall cancelled."
        echo ""
        return 0
    fi

    echo ""
    echo -e "${YELLOW}  →${NC} Removing fshare-vn plugin..."
    rm -rf "$PLUGIN_DIR"
    rm -rf "$HOST_DIR"
    rm -rf "/var/packages/DownloadStation/etc/download/userhosts/fsharevn"
    rm -rf "/var/packages/DownloadStation/target/hostscript/hosts/fsharevn"

    echo -e "${YELLOW}  →${NC} Removing host_enabled.conf entry..."
    sed -i '/^\[fshare-vn\]/,/^enable/d' "$HOST_ENABLED" 2>/dev/null

    echo -e "${YELLOW}  →${NC} Restoring pyLoad plugin..."
    if [ -f "$PYLOAD_HOSTER/FshareVn.py.bak" ]; then
        cp "$PYLOAD_HOSTER/FshareVn.py.bak" "$PYLOAD_HOSTER/FshareVn.py"
        rm -f "$PYLOAD_HOSTER/FshareVn.pyc"
    fi
    if [ -f "$PYLOAD_ACCOUNT/FshareVn.py.bak" ]; then
        cp "$PYLOAD_ACCOUNT/FshareVn.py.bak" "$PYLOAD_ACCOUNT/FshareVn.py"
        rm -f "$PYLOAD_ACCOUNT/FshareVn.pyc"
    fi

    enable_pyload_fshare_plugin

    echo -e "${YELLOW}  →${NC} Clearing session cache..."
    rm -rf /tmp/dsm_fshare-vn/

    echo -e "${YELLOW}  →${NC} Restarting Download Station..."
    synopkg stop DownloadStation && synopkg start DownloadStation
    exit_if_failed $? "Failed to restart Download Station during uninstall."

    verify_uninstall_state
    check_plugin_status

    echo ""
    echo -e "${GREEN}--------------------------------------------${NC}"
    echo -e "  ${GREEN}${BOLD}[OK] Plugin uninstalled.${NC}"
    echo -e "${GREEN}--------------------------------------------${NC}"
    echo ""
    exit 0
}

# ── Header ────────────────────────────────────────────────────────────────────
print_header

# ── Kiểm tra môi trường ───────────────────────────────────────────────────────
if [ ! -f /etc/synoinfo.conf ]; then
    echo -e "${RED}  ✗ Script này chỉ chạy trên Synology NAS.${NC}"
    exit 1
fi

DS_APP_PATH="$(find_downloadstation_volume)"
if [ -z "$DS_APP_PATH" ]; then
    echo -e "${RED}  ✗ Download Station chưa được cài đặt.${NC}"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo -e "${RED}  ✗ curl không có sẵn trên hệ thống.${NC}"
    exit 1
fi

# Root is required for all install/uninstall operations.
if ! has_root; then
    echo -e "${RED}  ✗ Please run this script as root (use sudo -i first).${NC}"
    exit 1
fi

# ── Main menu ────────────────────────────────────────────────────────────────
while true; do
    print_header
    echo -e "  ${BOLD}Select an option:${NC}"
    echo ""
    echo -e "  ${CYAN}1.${NC} Install for VIP Account"
    echo -e "  ${CYAN}2.${NC} Check System Environment"
    echo -e "  ${CYAN}3.${NC} Check Current Plugin Status"
    echo -e "  ${CYAN}4.${NC} Repair / Reinstall Plugin"
    echo -e "  ${CYAN}5.${NC} Uninstall Plugin"
    echo -e "  ${CYAN}0.${NC} Exit"
    echo ""
    read -p "  Enter your choice [0/1/2/3/4/5]: " MENU_CHOICE

    case "$MENU_CHOICE" in
        1)
            CUSTOM_API_KEY=""
            INSTALL_MODE="VIP"
            break
            ;;
        2)
            check_system_environment
            read -p "  Press Enter to return to the menu..." _pause
            ;;
        3)
            check_plugin_status
            read -p "  Press Enter to return to the menu..." _pause
            ;;
        4)
            echo ""
            echo -e "  ${BOLD}Repair options:${NC}"
            echo -e "  ${CYAN}1.${NC} Quick Repair (reuse current/default settings)"
            echo -e "  ${CYAN}2.${NC} Reinstall for VIP Account"
            echo -e "  ${CYAN}0.${NC} Back to Main Menu"
            echo ""
            read -p "  Enter your choice [0/1/2]: " REPAIR_CHOICE
            case "$REPAIR_CHOICE" in
                1)
                    if [ -f "$PLUGIN_DIR/custom_api_key.txt" ]; then
                        CUSTOM_API_KEY="$(cat "$PLUGIN_DIR/custom_api_key.txt" 2>/dev/null)"
                    else
                        CUSTOM_API_KEY=""
                    fi
                    INSTALL_MODE="REPAIR_QUICK"
                    echo -e "  ${YELLOW}→${NC} Quick repair mode selected"
                    break 2
                    ;;
                2)
                    CUSTOM_API_KEY=""
                    INSTALL_MODE="REPAIR_VIP"
                    echo -e "  ${YELLOW}→${NC} Repair + reinstall for VIP selected"
                    break 2
                    ;;
                0)
                    echo ""
                    ;;
                *)
                    echo -e "${RED}  ✗ Invalid repair option.${NC}"
                    echo ""
                    ;;
            esac
            ;;
        5)
            uninstall_plugin
            ;;
        0)
            echo ""
            echo -e "  ${YELLOW}→${NC} Exiting installer."
            echo ""
            exit 0
            ;;
        *)
            echo -e "${RED}  ✗ Invalid option. Please enter 0, 1, 2, 3, 4 or 5.${NC}"
            echo ""
            ;;
    esac
done

show_runtime_summary
perform_install "$INSTALL_MODE"

# ── Footer ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}--------------------------------------------${NC}"
echo -e "  ${GREEN}${BOLD}[OK] Cai dat hoan tat!${NC}"
echo -e "${GREEN}--------------------------------------------${NC}"
echo ""
echo -e "  ${BOLD}Bước tiếp theo:${NC}"
echo -e "  ${CYAN}1.${NC} Mở Download Station"
echo -e "  ${CYAN}2.${NC} Settings → File Hosting → ${BOLD}Fshare.vn${NC}"
echo -e "  ${CYAN}3.${NC} Edit → nhập email + password → Verify"
echo ""
echo -e "  ${BOLD}Enjoy! <3${NC}"
echo ""
