FROM linuxserver/chromium:amd64-50ba601b-ls108

# 1. Pre-install Traditional & Simplified Chinese fonts and socat
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        fonts-noto-cjk \
        fonts-wqy-zenhei \
        fonts-arphic-ukai \
        fonts-arphic-uming \
        socat && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 2. Supervised CDP proxy service via s6-overlay v3
# Proxies container eth0 IP:9222 to 127.0.0.1:9222 (bypasses Chromium loopback-only binding)
RUN mkdir -p /etc/s6-overlay/s6-rc.d/svc-cdp-proxy && \
    echo "longrun" > /etc/s6-overlay/s6-rc.d/svc-cdp-proxy/type && \
    printf '#!/usr/bin/with-contenv bash\nwhile true; do\n  ETH0_IP=$(hostname -I | awk '\''{print $1}'\'')\n  if [ -n "$ETH0_IP" ]; then break; fi\n  sleep 1\ndone\nexec socat TCP-LISTEN:9222,bind="$ETH0_IP",fork,reuseaddr TCP:127.0.0.1:9222\n' > /etc/s6-overlay/s6-rc.d/svc-cdp-proxy/run && \
    chmod +x /etc/s6-overlay/s6-rc.d/svc-cdp-proxy/run && \
    touch /etc/s6-overlay/s6-rc.d/user/contents.d/svc-cdp-proxy
