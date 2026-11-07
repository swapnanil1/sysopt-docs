# SearXNG search server: CPU only

[Start here](../README.md) · [Network access](05-network-access.md) · [Code MCP setup](04-code-oss-setup.md#4-add-search-and-webpage-reading)

SearXNG queries online search engines and returns results to Code's MCP adapter. It uses CPU and system RAM, not an inference model. The container below has no GPU devices, no GPU runtime, and no privileged mode: it does not allocate Swift's VRAM. The MCP adapter fetches selected webpages on the client. Search still requires internet access and upstream engines can rate-limit or block it.

## 1. Install Docker on Arch/CachyOS

```bash
sudo pacman -Syu --needed docker curl openssl
sudo systemctl enable --now docker
sudo docker info
```

Continue once `docker info` shows server details. Use `sudo` for Docker; adding your user to the Docker group is unnecessary for this guide. If startup fails:

```bash
sudo journalctl -u docker -b --no-pager -n 50
```

## 2. Configure the private instance

For a new installation:

```bash
mkdir -p "$HOME/llm/searxng/config"
cat > "$HOME/llm/searxng/config/settings.yml" <<EOF
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
```

This writes the initial settings and internal signing secret. Do not rerun it over settings you have customized without reviewing them. The secret is not a client API key. JSON must be enabled for the adapter. This is a private trusted-LAN deployment, with the public-instance limiter disabled; it is not a public search service.

## 3. Start one bounded container

```bash
sudo docker run -d \
  --name searxng \
  --restart unless-stopped \
  --cpus=2 \
  --memory=1g \
  --memory-swap=1g \
  -e GRANIAN_WORKERS=1 \
  -p 0.0.0.0:8888:8080 \
  -v "$HOME/llm/searxng/config:/etc/searxng" \
  -v searxng-data:/var/cache/searxng \
  --log-driver local \
  --log-opt max-size=10m \
  --log-opt max-file=2 \
  docker.io/searxng/searxng:latest
```

The limits permit at most two CPU cores' worth of time and 1 GiB RAM, with no additional container swap allowance; they do not reserve those resources continuously. One worker is a starting point for light single-user workloads. Defaults and capacity may need revisiting for multiple simultaneous users. Bounded logs avoid unbounded log growth. Persistent settings and cache survive a container replacement.

This publishes search to IPv4 interfaces on **8888** for clients on the trusted LAN. It is separate from the model on **18080**. Docker-published ports follow Docker's networking rules; an existing UFW model rule does not necessarily restrict this port. Do not router-forward it. See [SearXNG's container options](https://docs.searxng.org/admin/installation-docker.html) and [Docker port publishing](https://docs.docker.com/engine/network/port-publishing/).

Memory and CPU consumption vary with enabled engines and query load. Use `docker stats` to measure your own instance; the configured resource ceilings are not a fixed usage estimate. Confirm LAN access from each client.

If you already created the localhost-bound container, `docker start` cannot change its port mapping. To recreate only the container with the LAN mapping, preserving its named cache volume and configuration folder:

```bash
sudo docker stop searxng
sudo docker rm searxng
```

Then run the creation command above. Do not remove `searxng-data` or the config folder. `latest` can change; record the pulled digest if you need to reproduce a particular version.

## 4. Verify actual JSON results

Inspect startup:

```bash
sudo docker logs --tail 40 searxng
```

Expect a listening server and a started worker. Then, on the server:

```bash
curl -fsS --max-time 30 --get 'http://127.0.0.1:8888/search' \
  --data-urlencode 'q=llama.cpp server documentation' \
  --data-urlencode 'format=json' \
  -o /tmp/searxng-test.json
```

Only after curl succeeds:

```bash
python -c 'import json; d=json.load(open("/tmp/searxng-test.json")); print("Results:",len(d.get("results",[]))); [print(x["title"],x["url"],sep="\n") for x in d.get("results",[])[:3]]; print("Engine failures:",d.get("unresponsive_engines",[]))'
```

A nonempty `results` array verifies useful search, not just a responding web UI. A response can contain useful results while also reporting an engine as `too many requests` or `CAPTCHA`. Individual engine failures do not mean the whole search failed. Do not repeatedly hammer blocked engines; inspect results, wait, or select another available engine.

Optional engine registration errors or a missing `limiter.toml` warning do not by themselves establish that all search is broken. For a private instance with the limiter disabled, verify the actual JSON results and inspect any enabled engine that fails.

Check consumption:

```bash
sudo docker stats --no-stream searxng
```

## 5. Check from a client

Replace `192.168.1.50` with the server IP:

```bash
curl --connect-timeout 5 -fsS --max-time 30 --get 'http://192.168.1.50:8888/search' \
  --data-urlencode 'q=llama.cpp server documentation' \
  --data-urlencode 'format=json'
```

On Windows use `curl.exe`. Inspect for nonempty results, then set the client's MCP `SEARXNG_URL` to `http://192.168.1.50:8888` and follow the [Code adapter setup](04-code-oss-setup.md#4-add-search-and-webpage-reading). The same-machine adapter may use loopback even though the service is LAN-published.

## 6. Manage the existing service

Run the command for the action you want:

```bash
sudo docker stop searxng
sudo docker start searxng
sudo docker restart searxng
sudo docker logs --tail 50 searxng
sudo docker stats --no-stream searxng
```

The restart policy starts it after reboot unless explicitly stopped. Stop/start does not repull an image. Editing `settings.yml` requires a restart. Do not rerun `docker run --name searxng` just to restart an existing container.

| Problem | Next check |
|---|---|
| Cannot reach Docker daemon | Docker service and `docker info` |
| Container name already exists | `sudo docker ps -a`; start it or intentionally recreate it |
| JSON request gets 403 | Mounted settings include `json` under `search.formats`; restart after correction |
| Server works, remote client fails | LAN port publication, routing, firewall, guest Wi-Fi isolation |
| Empty results | `unresponsive_engines`, container logs and upstream limits |
| Container exits under load | Inspect status/logs and `OOMKilled`; raise the RAM ceiling only if evidence requires it |
| UI works, MCP does not | Direct JSON test first, then MCP config, Node and enabled tools |

## 7. Hosted instances are optional, but must allow API access

An operator-controlled hosted instance can replace local Docker by changing `SEARXNG_URL`. Browser uptime and TLS grades do not establish JSON/API access. Test `/search?q=...&format=json` and inspect actual JSON results. A normal SearXNG homepage is not itself a remote MCP server.

Public instances may return HTTP 429, browser-cookie challenges, or redirected HTML checks instead of JSON, even when the browser UI and uptime ratings look healthy. That does not establish a permanent problem with the service. Do not bypass its challenges; use an instance whose operator permits the intended API workload, or self-host.
