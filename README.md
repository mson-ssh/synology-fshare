# Fshare.vn — Synology Download Station Host Module

Module tích hợp Fshare.vn vào Synology Download Station, cho phép tải file trực tiếp thông qua giao thức kết nối chính thức của Fshare.

> **Lưu ý:** Module chỉ hỗ trợ tài khoản **Fshare VIP**. Tài khoản thường (Free) không được Fshare cấp quyền truy cập API của bên thứ ba. Người dùng tài khoản thường cần được Fshare cấp API key cá nhân riêng để sử dụng.

---

## Yêu cầu

- Synology NAS với DSM 3.2 trở lên
- Download Station đã cài đặt
- Tài khoản Fshare.vn (Free hoặc VIP)
- Quyền truy cập SSH vào NAS

---

## Kết nối SSH

Tìm địa chỉ IP của NAS tại **Control Panel** → **Network** → **Network Interface** (ví dụ: `192.168.1.100`).

**Bật SSH trên Synology:**

1. Đăng nhập vào giao diện DSM
2. Vào **Control Panel** → **Terminal & SNMP**
3. Tích vào **Enable SSH service**
4. Bấm **Apply**

**Kết nối từ máy tính:**

- **Windows**: Mở **Command Prompt** hoặc **PowerShell**, chạy:
```
ssh admin@192.168.1.100
```

- **Mac / Linux**: Mở **Terminal**, chạy:
```
ssh admin@192.168.1.100
```

> Thay `admin` bằng tên tài khoản DSM của bạn, và `192.168.1.100` bằng IP thực của NAS. Nhập mật khẩu DSM khi được hỏi.

---

## Cài đặt

### Cách 1 — Tự động (khuyến nghị)

Sau khi kết nối SSH, chạy lệnh sau:

```bash
curl -fsSL https://raw.githubusercontent.com/mson-ssh/synology-fshare/main/install.sh -o /tmp/install_fshare.sh && bash /tmp/install_fshare.sh
```

> Nếu gặp lỗi quyền truy cập, chạy `sudo -i` trước rồi thử lại.

Script sẽ tự động tải plugin, cấu hình đúng và khởi động lại Download Station. Trong quá trình cài đặt, menu sẽ hiển thị bằng tiếng Anh, còn nội dung hướng dẫn cài đặt vẫn giữ tiếng Việt.

- Chọn **1** nếu bạn có tài khoản **VIP**
- Chọn **2** nếu bạn có tài khoản thường và đã được Fshare cấp **API key cá nhân**
- Chọn **3** để kiểm tra môi trường hệ thống
- Chọn **4** để kiểm tra trạng thái plugin hiện tại
- Chọn **5** để cài đè / sửa lỗi plugin
- Chọn **6** để gỡ plugin
- Chọn **0** để thoát

Sau khi script hoàn tất, mở Download Station → Settings → File Hosting → chọn **Fshare.vn** → Edit → nhập email và mật khẩu Fshare → Verify.

### Post-install verification

Sau khi cài xong, trạng thái mong muốn trong **Download Station → Settings → File Hosting** là:

- Host Fshare cũ của Synology / pyLoad vẫn có thể còn xuất hiện, nhưng ở trạng thái **Deactive**
- Host Fshare do script cài đặt phải ở trạng thái **Active**

Kiểm tra nhanh:

1. Mở **Download Station** → **Settings** → **File Hosting**
2. Xác nhận dòng Fshare cũ là **Deactive**
3. Xác nhận dòng host custom `fshare-vn` là **Active**
4. Chọn dòng host custom → **Edit** → nhập email + password → **Verify**
5. Dán thử một link `https://www.fshare.vn/file/XXXXXXXXXX` để kiểm tra tải thực tế

Nếu file đã được cài nhưng host mới không hoạt động, hãy kiểm tra thêm quyền truy cập của runtime path:

```bash
chmod 755 /var/packages/DownloadStation/target/hostscript/hosts/fshare-vn
chmod 644 /var/packages/DownloadStation/target/hostscript/hosts/fshare-vn/*
```

---


---

## API Key

### Tài khoản VIP

Tài khoản VIP sử dụng API key mặc định — không cần thêm bước nào. Chọn **1** khi chạy script cài đặt là xong.

### Tài khoản thường (Free) — API Key cá nhân

Fshare hiện không cấp API key công khai cho người dùng cá nhân. Để sử dụng tài khoản thường, bạn cần liên hệ Fshare để được cấp API key riêng:

1. Gửi email đến **hotro@fshare.vn**
2. Tiêu đề: `Yêu cầu cấp API key cá nhân`
3. Nội dung: Nêu rõ mục đích sử dụng (tích hợp Download Station trên Synology NAS)
4. Đính kèm thông tin tài khoản Fshare của bạn

Sau khi được cấp API key, chọn **2** khi chạy script cài đặt và nhập API key vào khi được hỏi.

### Cách 2 — Thủ công

**Bước 1. Tải file**

Tải `FshareVn.host` từ mục Releases của repository này.

**Bước 2. Thêm vào Download Station**

Mở Download Station → Settings → File Hosting → Add → chọn `FshareVn.host`.

**Bước 3. Cập nhật cấu hình qua SSH**

Sau khi kết nối SSH, chạy lệnh sau:

```bash
cat > /var/packages/DownloadStation/etc/download/userhosts/fshare-vn/INFO << 'EOF'
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
EOF

chown -R DownloadStation:DownloadStation /var/packages/DownloadStation/etc/download/userhosts/fshare-vn
sudo synopkg stop DownloadStation && sudo synopkg start DownloadStation
```

**Bước 4. Nhập thông tin tài khoản**

Mở Download Station → Settings → File Hosting → chọn **Fshare.vn** → Edit → nhập email và mật khẩu Fshare → Verify.

| Kết quả | Ý nghĩa |
|---------|---------|
| Valid | Tài khoản VIP, sẵn sàng sử dụng |
| Free user / Login failed | Sai email/mật khẩu, tài khoản không phải VIP, hoặc chưa được cấp API key cá nhân |

![Hướng dẫn cài đặt](assets/screenshot1.png)

---

## Sử dụng

Dán link Fshare vào Download Station như bình thường:

```
https://www.fshare.vn/file/XXXXXXXXXX
```

![Kết quả tải](assets/screenshot2.png)

---

## Lưu ý

Mã nguồn này không thu thập bất kỳ dữ liệu cá nhân nào của người dùng. Thông tin đăng nhập chỉ được sử dụng để xác thực trực tiếp với hệ thống Fshare và không được lưu trữ hay gửi đến bất kỳ bên thứ ba nào.

Module ưu tiên tái sử dụng phiên đăng nhập đã được lưu tạm trên thiết bị. Việc xác thực lại với hệ thống Fshare chỉ xảy ra khi phiên hiện tại hết hạn hoặc không còn hợp lệ.

Module sử dụng giao thức kết nối của Fshare không có khóa đăng ký chính thức. Fshare hiện đã tạm ngưng cấp quyền truy cập cho cá nhân. Người dùng tự chịu trách nhiệm khi sử dụng.

---

## Giấy phép

MIT

---
---

# Fshare.vn — Synology Download Station Host Module

A file hosting module that enables Synology Download Station to download files from Fshare.vn using Fshare's official service interface.

> **Note:** This module only supports **Fshare VIP accounts**. Free accounts are not granted API access for third-party applications by Fshare. Free account users need a personal API key issued directly by Fshare.

---

## Requirements

- Synology NAS with DSM 3.2 or later
- Download Station installed
- Fshare.vn account (Free or VIP)
- SSH access to the NAS

---

## Connect via SSH

Find your NAS IP address at **Control Panel** → **Network** → **Network Interface** (e.g. `192.168.1.100`).

**Enable SSH on Synology:**

1. Log in to DSM
2. Go to **Control Panel** → **Terminal & SNMP**
3. Check **Enable SSH service**
4. Click **Apply**

**Connect from your computer:**

- **Windows**: Open **Command Prompt** or **PowerShell** and run:
```
ssh admin@192.168.1.100
```

- **Mac / Linux**: Open **Terminal** and run:
```
ssh admin@192.168.1.100
```

> Replace `admin` with your DSM username and `192.168.1.100` with your NAS IP. Enter your DSM password when prompted.

---

## Installation

### Method 1 — Automatic (recommended)

Once connected via SSH, run:

```bash
curl -fsSL https://raw.githubusercontent.com/mson-ssh/synology-fshare/main/install.sh -o /tmp/install_fshare.sh && bash /tmp/install_fshare.sh
```

> If you encounter a permission error, run `sudo -i` first then try again.

The script will automatically download the plugin, apply the correct configuration, and restart Download Station. The main menu is shown in English, while the installation flow keeps Vietnamese prompts for local users.

- Select **1** if you have a **VIP** account
- Select **2** if you have a free account and have been issued a **personal API key** by Fshare
- Select **3** to check the system environment
- Select **4** to check the current plugin status
- Select **5** to repair or reinstall the plugin
- Select **6** to uninstall the plugin
- Select **0** to exit

Once complete, open Download Station → Settings → File Hosting → select **Fshare.vn** → Edit → enter your Fshare email and password → Verify.

### Post-install verification

After installation, the expected state in **Download Station → Settings → File Hosting** is:

- The old Synology / pyLoad Fshare entry may still appear, but it should stay **Deactive**
- The host installed by this script should be **Active**

Quick checks:

1. Open **Download Station** → **Settings** → **File Hosting**
2. Confirm the old Fshare entry is **Deactive**
3. Confirm the custom `fshare-vn` host is **Active**
4. Select the custom host → **Edit** → enter your email and password → **Verify**
5. Test a real link such as `https://www.fshare.vn/file/XXXXXXXXXX`

If the files are present but the new host still does not work, verify the runtime permissions:

```bash
chmod 755 /var/packages/DownloadStation/target/hostscript/hosts/fshare-vn
chmod 644 /var/packages/DownloadStation/target/hostscript/hosts/fshare-vn/*
```

---


---

## API Key

### VIP Account

VIP accounts use the default API key — no additional steps required. Simply select **1** when running the install script.

### Free Account — Personal API Key

Fshare does not publicly issue API keys to individual users. To use a free account, you need to contact Fshare directly to request a personal API key:

1. Send an email to **hotro@fshare.vn**
2. Subject: `Request for personal API key`
3. Body: Clearly state your intended use (integration with Download Station on Synology NAS)
4. Include your Fshare account information

Once you receive your API key, select **2** when running the install script and enter the key when prompted.

### Method 2 — Manual

**Step 1. Download**

Download `FshareVn.host` from the Releases section of this repository.

**Step 2. Add to Download Station**

Open Download Station → Settings → File Hosting → Add → select `FshareVn.host`.

**Step 3. Fix configuration via SSH**

Once connected via SSH, run:

```bash
cat > /var/packages/DownloadStation/etc/download/userhosts/fshare-vn/INFO << 'EOF'
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
EOF

chown -R DownloadStation:DownloadStation /var/packages/DownloadStation/etc/download/userhosts/fshare-vn
sudo synopkg stop DownloadStation && sudo synopkg start DownloadStation
```

**Step 4. Configure credentials**

Open Download Station → Settings → File Hosting → select **Fshare.vn** → Edit → enter your Fshare email and password → Verify.

| Result | Meaning |
|--------|---------|
| Valid | VIP account, ready to use |
| Free user / Login failed | Incorrect email/password, non-VIP account, or personal API key not yet configured |

![Installation guide](assets/screenshot1.png)

---

## Usage

Paste any Fshare link into Download Station as usual:

```
https://www.fshare.vn/file/XXXXXXXXXX
```

![Download result](assets/screenshot2.png)

---

## Disclaimer

This module does not collect any personal data. Credentials are used solely to authenticate with Fshare's service and are never stored or transmitted to any third party.

The module prioritizes reusing an existing session cached on the device. Re-authentication only occurs when the current session has expired or is no longer valid.

This module communicates with Fshare's service without an officially registered access key. Fshare has suspended access for individual developers. The author assumes no responsibility for any consequences arising from its use.

---

## License

MIT
