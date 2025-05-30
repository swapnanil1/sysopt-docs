# Guide: Setup DoT with dnsmasq + stubby on Arch Linux (Optimized for Speed)

This guide details how to configure DNS over TLS (DoT) using `dnsmasq` and `stubby` on Arch Linux, optimizing for performance with Cloudflare. It involves disabling `systemd-resolved` and locking `/etc/resolv.conf`.

**Assumptions:**

*   You are running Arch Linux.
*   You have `sudo` privileges.
*   You want to completely replace `systemd-resolved`.
*   Speed is prioritized over Public Key Pinning security.
*   IPv6 DNS resolution is not required for this setup.

---

## Step 1: Install `dnsmasq` and `stubby`

Ensure your system is up-to-date and install the necessary packages using `pacman`.

```bash
sudo pacman -Syu dnsmasq stubby
```

---

## DNS Query Flow Diagram (What We Are Building)

This diagram shows how DNS requests will travel through the system once configured:

```
💻 **Your Application** (Needs DNS Resolution)
  |
  V
📄 **/etc/resolv.conf**
   *   Content: `nameserver 127.0.0.1`
   *   Purpose: Points all system DNS queries to local dnsmasq -> ✔️ (Configured in Step 4)
   *   Locked (`chattr +i`) -> ✔️ (Locked in Step 5)
  |
  V (Query sent to 127.0.0.1 Port 53)
  |
⚙️  **dnsmasq Service**
   *   Listens on: `127.0.0.1:53` -> ✔️ (Configured in Step 6)
   *   Checks local cache (Fast replies for known domains) ⚡
   *   If not cached, forwards to: `127.0.0.1#54` (stubby's address) -> ✔️ (Configured in Step 6)
  |
  V (Query sent to 127.0.0.1 Port 54)
  |
⚙️  **stubby Service**
   *   Listens on: `127.0.0.1:54` -> ✔️ (Configured in Step 7)
   *   Encrypts query using **DNS over TLS (DoT)** 🔒
   *   Sends encrypted query to: Cloudflare (`1.1.1.1:853`, `1.0.0.1:853`) -> ✔️ (Configured in Step 7)
  |
  V (Encrypted Query 🔒 via Internet)
  |
☁️ **Cloudflare DNS Servers**
   *   Receives encrypted query, resolves it, sends encrypted reply back.
```

This setup ensures local caching via `dnsmasq` for speed and encrypted upstream lookups via `stubby` for privacy.

---

## Step 2: Stop and Disable `systemd-resolved`

Completely stop and disable the built-in systemd resolver service.

```bash
sudo systemctl stop systemd-resolved.service
sudo systemctl disable systemd-resolved.service
```

---

## Step 3: Remove Existing `/etc/resolv.conf` Link

If `/etc/resolv.conf` is currently a symlink managed by `systemd-resolved` or another tool, remove it.

```bash
sudo rm /etc/resolv.conf
```

---

## Step 4: Create Manual `/etc/resolv.conf`

Create a new static `/etc/resolv.conf` file pointing all local DNS queries to `dnsmasq`.

```bash
echo -e "nameserver 127.0.0.1\noptions edns0" | sudo tee /etc/resolv.conf
```

The content of `/etc/resolv.conf` should be:

```
nameserver 127.0.0.1
options edns0
```

---

## Step 5: Lock `/etc/resolv.conf`

Make the file immutable to prevent it from being overwritten by network managers or other processes.

```bash
sudo chattr +i /etc/resolv.conf
```

---

## Step 6: Configure `dnsmasq` for Performance

Overwrite `/etc/dnsmasq.conf` with the following performance-optimized configuration.

```bash
echo -e "listen-address=127.0.0.1\nno-resolv\nbind-interfaces\ncache-size=10000\nmin-cache-ttl=3600\nproxy-dnssec\ndomain-needed\nbogus-priv\nserver=127.0.0.1#54" | sudo tee /etc/dnsmasq.conf
```

The content of `/etc/dnsmasq.conf` will be:

```conf
listen-address=127.0.0.1
no-resolv
bind-interfaces
cache-size=10000
min-cache-ttl=3600
proxy-dnssec
domain-needed
bogus-priv
server=127.0.0.1#54
```

---

## Step 7: Configure `stubby` for Performance (Cloudflare DoT)

Overwrite `/etc/stubby/stubby.yml` to use Cloudflare's IPv4 DoT servers.

```bash
sudo tee /etc/stubby/stubby.yml > /dev/null <<'EOF'
resolution_type: GETDNS_RESOLUTION_STUB
dns_transport_list:
  - GETDNS_TRANSPORT_TLS
tls_authentication: GETDNS_AUTHENTICATION_REQUIRED
round_robin_upstreams: 1
idle_timeout: 10000
listen_addresses:
  - 127.0.0.1@54
upstream_recursive_servers:
  - address_data: 1.1.1.1
    tls_port: 853
    tls_auth_name: "cloudflare-dns.com"
  - address_data: 1.0.0.1
    tls_port: 853
    tls_auth_name: "cloudflare-dns.com"
EOF
```

The content of `/etc/stubby/stubby.yml` will be:

```yaml
resolution_type: GETDNS_RESOLUTION_STUB
dns_transport_list:
  - GETDNS_TRANSPORT_TLS
tls_authentication: GETDNS_AUTHENTICATION_REQUIRED
round_robin_upstreams: 1
idle_timeout: 10000
listen_addresses:
  - 127.0.0.1@54
upstream_recursive_servers:
  - address_data: 1.1.1.1
    tls_port: 853
    tls_auth_name: "cloudflare-dns.com"
  - address_data: 1.0.0.1
    tls_port: 853
    tls_auth_name: "cloudflare-dns.com"

```

---

## Step 8: Enable and Start `dnsmasq` and `stubby` Services

Enable the services to start automatically on boot and start them immediately.

```bash
sudo systemctl enable --now dnsmasq.service
sudo systemctl enable --now stubby.service
```

---

## Step 9: Verification

Perform these checks to ensure the setup is working correctly.

1.  **Check Service Status:**
    ```bash
    systemctl status dnsmasq.service stubby.service
    ```
    *   Look for `active (running)` for both services. Press `q` to exit.

2.  **Check `/etc/resolv.conf`:**
    ```bash
    cat /etc/resolv.conf
    lsattr /etc/resolv.conf
    ```
    *   Verify the content is `nameserver 127.0.0.1` (and optionally `options edns0`).
    *   Confirm the `lsattr` output shows the `i` (immutable) flag: `----i---------e------- /etc/resolv.conf`.

3.  **Test DNS Resolution:**
    ```bash
    dig @127.0.0.1 google.com
    ```
    *   Run it twice. The second query should return very quickly (low `Query time:`) indicating `dnsmasq` caching is working.

4.  **Check DoT Status Online:**
    *   Visit [https://1.1.1.1/help](https://1.1.1.1/help) in your web browser.
    *   **Expected Result:**
        *   Connected to 1.1.1.1: **Yes**
        *   Using DNS over TLS (DoT): **Yes**
        *   Using DNS over HTTPS (DoH): **No**

---

Your Arch Linux system is now configured to use `dnsmasq` and `stubby` for fast, cached, DoT-encrypted DNS resolution via Cloudflare.
