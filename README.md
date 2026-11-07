# Chromium with Chinese Fonts & Supervised CDP Proxy

[![Docker Pulls](https://img.shields.io/docker/pulls/wenchiehlee1020/chromium?style=flat-square)](https://hub.docker.com/r/wenchiehlee1020/chromium)
[![Docker Image Version](https://img.shields.io/docker/v/wenchiehlee1020/chromium?sort=semver&style=flat-square)](https://hub.docker.com/r/wenchiehlee1020/chromium)
[![Docker Image Size](https://img.shields.io/docker/image-size/wenchiehlee1020/chromium/latest?style=flat-square)](https://hub.docker.com/r/wenchiehlee1020/chromium)

A production-ready Chromium container image optimized for **Synology NAS (Container Manager)** and Linux servers. Based on `linuxserver/chromium`, this image pre-bakes full Traditional and Simplified Chinese fonts and includes an integrated s6-overlay supervised proxy for remote Chrome DevTools Protocol (CDP) debugging.

---

## Key Features

- **Pre-installed Chinese Fonts**: Pre-bundles `fonts-noto-cjk`, `fonts-wqy-zenhei`, `fonts-arphic-ukai`, and `fonts-arphic-uming`. Eliminates runtime downloads (saving ~85 MB and 90 seconds on every container start) and prevents Chinese text rendering as tofu blocks (`□□□`).
- **Supervised CDP Remote Debugging Proxy (Port 9222)**: Modern Chromium (M113+) enforces security by strictly binding `--remote-debugging-port` to loopback `127.0.0.1`. This image features a supervised `s6-overlay` background proxy (`socat`) that automatically binds to the container's external interface (`eth0:9222`) and forwards traffic to `127.0.0.1:9222`. Remote Playwright, Puppeteer, or Selenium scripts on the host or LAN can connect reliably without getting `ECONNRESET`.
- **Dual Web GUI Access (Ports 3000 & 3001)**: Integrated KasmVNC web GUI providing responsive desktop browser access over HTTP (3000) and HTTPS (3001) with basic authentication.
- **Zero Startup Delay**: Starts in under 2 seconds without `apt-get` runtime dependency, eliminating 502 Bad Gateway downtime during container updates.
- **Bot-Detection / Cloudflare Evasion**: Real desktop Chromium environment that works seamlessly with `playwright-stealth` for scraping sites protected by Cloudflare Turnstile.

---

## Architecture & Port Mapping

| Port | Protocol | Purpose | Default Host Mapping |
| :--- | :--- | :--- | :--- |
| `3000` | HTTP | KasmVNC Web Desktop GUI (HTTP) | `3020` |
| `3001` | HTTPS | KasmVNC Web Desktop GUI (HTTPS) | `3021` |
| `9222` | TCP | Chromium DevTools Protocol (CDP / WebSocket) | `9222` |

---

## Quickstart with Docker Compose

Create a `compose.yaml`:

```yaml
version: "2.1"

services:
  chromium:
    image: wenchiehlee1020/chromium:v1.0.0
    container_name: CHROMIUM
    restart: unless-stopped
    ports:
      - 3020:3000
      - 3021:3001
      - 9222:9222
    volumes:
      - ./config:/config
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - TITLE=Chromium Desktop
      - CUSTOM_USER=${CHROMIUM_USER:-user}
      - PASSWORD=${CHROMIUM_PASSWORD:-password}
      - PUID=1000
      - PGID=1000
      - TZ=Asia/Taipei
      - NO_DECOR=0
      - CHROME_CLI=--remote-debugging-port=9222 --remote-allow-origins=* --disable-features=FontationsFontBackend https://about:blank
      - LC_ALL=zh_TW.UTF-8
    security_opt:
      - seccomp:unconfined
    shm_size: "1gb"
```

Create a `.env` file alongside `compose.yaml` (do not commit credentials to Git):

```bash
CHROMIUM_USER=myuser
CHROMIUM_PASSWORD=mysecurepassword
```

Start the container:

```bash
docker compose up -d
```

---

## Quickstart with Docker CLI

```bash
docker run -d \
  --name chromium \
  -p 3020:3000 \
  -p 3021:3001 \
  -p 9222:9222 \
  -e TITLE="Chromium Desktop" \
  -e CUSTOM_USER="myuser" \
  -e PASSWORD="mysecurepassword" \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Asia/Taipei \
  -e CHROME_CLI="--remote-debugging-port=9222 --remote-allow-origins=* --disable-features=FontationsFontBackend https://about:blank" \
  -e LC_ALL=zh_TW.UTF-8 \
  --shm-size="1gb" \
  --security-opt seccomp:unconfined \
  -v /path/to/config:/config \
  wenchiehlee1020/chromium:v1.0.0
```

---

## Verifying CDP Remote Connection

Once running, verify the Chrome DevTools Protocol endpoint from your local machine:

```bash
curl http://<HOST_IP>:9222/json/version
```

Example JSON response:

```json
{
   "Browser": "Chrome/132.0.6834.159",
   "Protocol-Version": "1.3",
   "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) ...",
   "V8-Version": "13.2.152.36",
   "WebKit-Version": "537.36 ...",
   "webSocketDebuggerUrl": "ws://<HOST_IP>:9222/devtools/browser/..."
}
```

Connect via Playwright Python:

```python
from playwright.async_api import async_playwright

async with async_playwright() as p:
    browser = await p.chromium.connect_over_cdp("http://<HOST_IP>:9222")
    context = browser.contexts[0]
    page = await context.new_page()
    await page.goto("https://example.com")
    print(await page.title())
    await page.close()
```

---

## Environment Variables Reference

| Variable | Default | Description |
| :--- | :--- | :--- |
| `CUSTOM_USER` | `user` | Username for KasmVNC web login |
| `PASSWORD` | - | Password for KasmVNC web login |
| `TITLE` | `Chromium` | Window/browser title shown in the KasmVNC web top bar |
| `CHROME_CLI` | - | Chromium startup CLI arguments (must include `--remote-debugging-port=9222 --remote-allow-origins=*`) |
| `PUID` / `PGID` | `1000` | User/Group ID for file permission management inside `/config` |
| `TZ` | `Asia/Taipei` | Timezone configuration |
| `LC_ALL` | `zh_TW.UTF-8` | System locale setting for Chinese display |
| `NO_DECOR` | `0` | Set to `1` to disable window decorations / borders |

---

## Security Recommendations

- **Keep CDP on Private LAN**: Port `9222` exposes full DevTools Protocol access (arbitrary JavaScript execution and DOM access). **Never expose port 9222 to the public internet** or configure port forwarding for it on external routers.
- **Use Reverse Proxy for Web GUI**: Forward ports `3020`/`3021` via Synology DSM Reverse Proxy or Tailscale Funnel with SSL certificates and strong authentication.
- **Environment Variables**: Use `.env` files with proper filesystem permissions (`chmod 600 .env`) to prevent committing passwords to Git.
