# SearXNG search server

[Start here](../README.md) · [Network access](05-network-access.md) · [Code client](04-code-oss-setup.md#4-optional-add-free-local-web-search)

**Run this guide on the server.** SearXNG searches online engines and returns results to a client's MCP adapter. It can run alongside llama.cpp without loading another model or allocating GPU memory. The adapter runs on each client and fetches selected web pages directly.

This installation targets an **Arch/CachyOS server**. A client can use another OS and does not need Docker. The service requires internet access. There is no search API key or subscription, but upstream engines can block or rate-limit requests. Searches leave the server; this is not an offline search index.

## 1. Install Docker

```bash
sudo pacman -Syu --needed docker curl openssl
sudo systemctl enable --now docker
sudo docker info
```

Confirm that `docker info` shows server details before continuing. If the daemon does not start, inspect `sudo journalctl -u docker -b --no-pager -n 50`. These commands use `sudo`; no Docker group change is needed.

## 2. Configure and start SearXNG

For a first installation, paste this block into a terminal. It creates the settings and generates SearXNG's internal secret automatically:

```bash
mkdir -p ~/llm/searxng/config
cat > ~/llm/searxng/config/settings.yml <<EOF
use_default_settings: true
search:
  formats:
    - html
    - json
server:
  secret_key: "$(openssl rand -hex 32)"
  limiter: false
  public_instance: false
EOF

sudo docker run -d --name searxng --restart unless-stopped \
  -p 0.0.0.0:8888:8080 \
  -v "$HOME/llm/searxng/config:/etc/searxng" \
  -v searxng-data:/var/cache/searxng \
  docker.io/searxng/searxng:latest
```

The image downloads on first use. `0.0.0.0:8888:8080` publishes search on the server's IPv4 interfaces at port **8888**, without API authentication. Any device that can reach that port can use it; use this setup on a trusted home LAN and do not forward the port through the router. HTTP does not encrypt searches or results. llama.cpp uses **18080**. The limiter is disabled for this private setup; `secret_key` is SearXNG's internal signing secret, not a client API key. See [Docker's port-publishing reference](https://docs.docker.com/engine/network/port-publishing/) and the [SearXNG container documentation](https://docs.searxng.org/admin/installation-docker.html).

Wait a few seconds, then open **http://127.0.0.1:8888** in a browser and try a search. Also check the JSON endpoint used by MCP:

```bash
curl -fsS --get 'http://127.0.0.1:8888/search' \
  --data-urlencode 'q=llama.cpp server documentation' \
  --data-urlencode 'format=json'
```

Expect JSON containing a nonempty `results` array with titles and URLs. An empty array is not a successful search check; inspect `unresponsive_engines` for upstream failures. Enabling `json` in `search.formats` is required for the [search API](https://docs.searxng.org/dev/search_api.html).

## 3. Check from a client

Use the server's address from [network access](05-network-access.md). For example, replace `192.168.1.50` below with your server IP:

```bash
curl -fsS --get 'http://192.168.1.50:8888/search' \
  --data-urlencode 'q=llama.cpp server documentation' \
  --data-urlencode 'format=json'
```

On Windows PowerShell, use `curl.exe` and put the command on one line. A browser can also test `http://192.168.1.50:8888/search?q=llama.cpp&format=json`. Expect a nonempty `results` array. When both the server-local and client checks work, connect the [Code search MCP adapter](04-code-oss-setup.md#4-optional-add-free-local-web-search).

## 4. Manage the service

SearXNG runs in the background and starts after reboot unless you explicitly stop it. Use these commands as needed; run only the command for the action you want:

```bash
sudo docker stop searxng            # Stop search when not needed
sudo docker start searxng           # Start the existing container again
sudo docker restart searxng         # Reload after editing settings.yml
sudo docker logs --tail 50 searxng   # Inspect startup/search errors
```

- **Container name already in use:** use `sudo docker start searxng`; the creation command is only needed once.
- **Cannot connect to the Docker daemon / missing docker.sock:** run `sudo systemctl enable --now docker`, then `sudo docker info`. If startup fails, inspect `sudo journalctl -u docker -b --no-pager -n 50`.
- **Browser or curl cannot connect:** check `sudo docker ps -a` and the container logs before troubleshooting MCP. For remote client access, verify the server IP and the published binding `0.0.0.0:8888->8080/tcp`; guest Wi-Fi isolation or firewall rules can block access.
- **JSON request returns 403:** check that the mounted `settings.yml` includes `json`, then restart the container. The browser UI working alone does not prove JSON access works.
- **Empty results, CAPTCHA, or 429:** an upstream engine may be blocking requests. Wait and retry less frequently; inspect the engine errors and try another available engine. Self-hosting does not remove upstream limits.
