<?php
/**
 * Fshare.vn File Hosting Module for Synology Download Station
 * Spec: Synology Developer Guide to File Hosting Module
 *
 * Constructor : __construct($Url, $Username, $Password, $HostInfo)
 * Methods     : GetDownloadInfo() | Verify($ClearCookie)
 */
class SynoFileHostingFshareVn
{
    // ── Properties ───────────────────────────────────────────────────────
    private $Url;
    private $Username;
    private $Password;
    private $HostInfo;

    // ── Fshare API constants ─────────────────────────────────────────────
    const API_URL       = 'https://api.fshare.vn/api/';
    const API_KEY       = 'dMnqMMZMUnN5YpvKENaEhdQQ5jxDqddt';
    const API_USERAGENT = 'pyLoad-B1RS5N';

    // ── Session cache (lưu trong /tmp/ — quy định của Synology) ─────────
    const SESSION_DIR   = '/tmp/dsm_fsharevn/';

    // ════════════════════════════════════════════════════════════════════
    // Constructor — DS truyền vào đủ 4 tham số
    // ════════════════════════════════════════════════════════════════════
    public function __construct($Url, $Username, $Password, $HostInfo)
    {
        $this->Url      = $Url;
        $this->Username = strtolower(trim($Username));
        $this->Password = trim($Password);
        $this->HostInfo = $HostInfo;
    }

    // ════════════════════════════════════════════════════════════════════
    // GetDownloadInfo — DS gọi để lấy direct download URL
    // Return: [DOWNLOAD_URL => "..."] hoặc error constant
    // ════════════════════════════════════════════════════════════════════
    public function GetDownloadInfo()
    {
        // Lấy session (từ cache hoặc login mới)
        $session = $this->getSession();
        if (!$session) {
            return LOGIN_FAIL;
        }

        // Gọi Fshare API lấy direct link
        $payload = json_encode([
            'token'    => $session['token'],
            'url'      => $this->Url,
            'password' => '',
        ]);

        $body = $this->httpPost(
            self::API_URL . 'session/download',
            $payload,
            $session['session_id']
        );

        if ($body === false) {
            // Token có thể hết hạn — xóa cache, thử login lại 1 lần
            $this->clearSession();
            $session = $this->login();
            if (!$session) {
                return LOGIN_FAIL;
            }

            $payload = json_encode([
                'token'    => $session['token'],
                'url'      => $this->Url,
                'password' => '',
            ]);

            $body = $this->httpPost(
                self::API_URL . 'session/download',
                $payload,
                $session['session_id']
            );

            if ($body === false) {
                return ERR_UNKNOWN;
            }
        }

        $data = json_decode($body, true);

        if (empty($data['location'])) {
            // Phân loại lỗi theo code trả về từ Fshare
            $code = isset($data['code']) ? (int)$data['code'] : 0;
            if ($code === 403) return ERR_REQUIRED_PREMIUM;
            if ($code === 404) return ERR_FILE_NO_EXIST;
            return ERR_UNKNOWN;
        }

        // Lấy tên file thật từ URL hoặc từ response
        $filename = '';
        if (!empty($data['name'])) {
            $filename = $data['name'];
        } else {
            // Parse tên file từ direct URL
            $path     = parse_url($data['location'], PHP_URL_PATH);
            $parts    = explode('/', $path);
            $filename = urldecode(end($parts));
            // Bỏ query string nếu có
            $filename = explode('?', $filename)[0];
        }

        $result = [DOWNLOAD_URL => $data['location']];
        if (!empty($filename)) {
            $result[DOWNLOAD_FILENAME] = $filename;
        }

        return $result;
    }

    // ════════════════════════════════════════════════════════════════════
    // Verify — DS gọi khi người dùng bấm "Verify" trong Settings
    // Return: USER_IS_PREMIUM | USER_IS_FREE | LOGIN_FAIL
    // ════════════════════════════════════════════════════════════════════
    public function Verify($ClearCookie)
    {
        // DS yêu cầu clear session → login lại từ đầu
        if ($ClearCookie) {
            $this->clearSession();
        }

        $session = $this->login();
        if (!$session) {
            return LOGIN_FAIL;
        }

        // Lấy thông tin user để kiểm tra VIP
        $body = $this->httpGet(
            self::API_URL . 'user/get',
            $session['session_id']
        );

        if ($body === false) {
            return LOGIN_FAIL;
        }

        $data = json_decode($body, true);
        if (empty($data) || !isset($data['email'])) {
            return LOGIN_FAIL;
        }

        // Kiểm tra expire_vip: nếu là số và > thời gian hiện tại → Premium
        $expireVip = $data['expire_vip'] ?? '';
        $isPremium = is_numeric($expireVip) && ((int)$expireVip > time());

        return $isPremium ? USER_IS_PREMIUM : USER_IS_FREE;
    }

    // ════════════════════════════════════════════════════════════════════
    // PRIVATE: Session management
    // ════════════════════════════════════════════════════════════════════

    /**
     * Trả về session hợp lệ (từ cache hoặc login mới)
     */
    private function getSession()
    {
        $cached = $this->loadSession();
        if ($cached) {
            // Validate session vẫn còn hiệu lực với Fshare
            if ($this->validateSession($cached['session_id'])) {
                return $cached;
            }
            $this->clearSession();
        }
        return $this->login();
    }

    /**
     * Đăng nhập Fshare API, lưu session vào /tmp/
     */
    private function login()
    {
        $payload = json_encode([
            'app_key'    => self::API_KEY,
            'user_email' => $this->Username,
            'password'   => $this->Password,
        ]);

        $body = $this->httpPost(self::API_URL . 'user/login', $payload);
        if ($body === false) return false;

        $data = json_decode($body, true);
        if (empty($data) || (int)($data['code'] ?? 0) !== 200) {
            return false;
        }

        $session = [
            'token'      => $data['token'],
            'session_id' => $data['session_id'],
        ];

        $this->saveSession($session);
        return $session;
    }

    /**
     * Kiểm tra session_id còn hiệu lực không bằng cách gọi user/get
     */
    private function validateSession($sessionId)
    {
        $body = $this->httpGet(
            self::API_URL . 'user/get',
            $sessionId
        );
        if ($body === false) return false;

        $data = json_decode($body, true);
        return !empty($data['email']);
    }

    // ════════════════════════════════════════════════════════════════════
    // PRIVATE: Session file helpers (chỉ ghi vào /tmp/)
    // ════════════════════════════════════════════════════════════════════

    private function sessionFile()
    {
        if (!is_dir(self::SESSION_DIR)) {
            mkdir(self::SESSION_DIR, 0700, true);
        }
        return self::SESSION_DIR . md5($this->Username) . '.json';
    }

    private function loadSession()
    {
        $f = $this->sessionFile();
        if (!file_exists($f)) return null;
        $d = json_decode(file_get_contents($f), true);
        return (!empty($d['token']) && !empty($d['session_id'])) ? $d : null;
    }

    private function saveSession(array $session)
    {
        file_put_contents($this->sessionFile(), json_encode($session), LOCK_EX);
    }

    private function clearSession()
    {
        $f = $this->sessionFile();
        if (file_exists($f)) unlink($f);
    }

    // ════════════════════════════════════════════════════════════════════
    // PRIVATE: HTTP helpers (chỉ dùng curl — quy định Synology)
    // ════════════════════════════════════════════════════════════════════

    private function httpPost($url, $payload, $sessionId = null)
    {
        $headers = [
            'Content-Type: application/json',
            'Accept: application/json',
        ];

        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_POST           => true,
            CURLOPT_POSTFIELDS     => $payload,
            CURLOPT_HTTPHEADER     => $headers,
            CURLOPT_USERAGENT      => self::API_USERAGENT,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_SSL_VERIFYPEER => false,
            CURLOPT_TIMEOUT        => 30,
            CURLOPT_FOLLOWLOCATION => false,
        ]);

        if ($sessionId) {
            curl_setopt($ch, CURLOPT_COOKIE, 'session_id=' . urlencode($sessionId));
        }

        $body = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        return ($code >= 200 && $code < 300 && $body !== false) ? $body : false;
    }

    private function httpGet($url, $sessionId = null)
    {
        $ch = curl_init($url);
        curl_setopt_array($ch, [
            CURLOPT_HTTPGET        => true,
            CURLOPT_HTTPHEADER     => ['Accept: application/json'],
            CURLOPT_USERAGENT      => self::API_USERAGENT,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_SSL_VERIFYPEER => false,
            CURLOPT_TIMEOUT        => 30,
        ]);

        if ($sessionId) {
            curl_setopt($ch, CURLOPT_COOKIE, 'session_id=' . urlencode($sessionId));
        }

        $body = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        return ($code >= 200 && $code < 300 && $body !== false) ? $body : false;
    }
}
?>
