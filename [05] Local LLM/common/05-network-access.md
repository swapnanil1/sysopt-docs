# Network access: connect clients to services

[Start here](../README.md) · [Linux server](../%5B02%5D%20Linux.md) · [Code client](04-code-oss-setup.md) · [Zed client](03-zed-setup.md)

Use this guide after installing the model server. The examples use a Linux server at `192.168.1.50`; replace that example address with yours. The client may run Windows, Linux, or macOS. The search checks apply only if you installed [SearXNG](06-search-server.md).

## 1. Check the server locally

Run the installed launcher on the server:

```bash
~/llm/start-llm.sh
```

It listens on all IPv4 interfaces at port **18080** without an API key. `~/llm/start-llm.sh --local` restricts it to localhost. In another server terminal:

```bash
ss -ltn 'sport = :18080'
curl -fsS http://127.0.0.1:18080/health
curl -fsS http://127.0.0.1:18080/v1/models
```

Expect `0.0.0.0:18080`, health status `ok`, and model ID `swift-qwen`. A server bound only to `127.0.0.1` cannot accept remote clients. Wait for model loading to finish before testing inference.

**Windows-hosted model:** the supplied Windows launchers use localhost port **8080** and a **32768** context. Check `http://127.0.0.1:8080/health` and `/v1/models` on that server; use the returned model ID in the editor. Those launchers do not configure LAN binding or Windows Firewall access. The documented LAN setup here uses the Linux server. This restriction does not apply to a Windows client connecting to that Linux server.

## 2. Find the server address

On the Linux server:

```bash
ip -br -4 address show scope global
```

Choose the address on the Ethernet/Wi-Fi interface, ignoring Docker bridges and VPN interfaces. If it shows `192.168.1.50/24`, clients use `192.168.1.50`, without `/24`. Interface names vary between machines. A router DHCP reservation can keep this address stable.

`0.0.0.0` is a listening address, not an address to paste into a client. `127.0.0.1` always refers to the device running the client; it reaches the server only when both roles share a machine.

| Client field | Example for a Linux server |
|---|---|
| Code Chat Completions request URL | `http://192.168.1.50:18080/v1/chat/completions` |
| Zed `api_url` | `http://192.168.1.50:18080` |
| OpenAI-compatible base URL | `http://192.168.1.50:18080/v1` |
| Search MCP `SEARXNG_URL` | `http://192.168.1.50:8888` |

No API key is required for this setup. Use `local` if the client requires a placeholder. The model and search server can be separate machines; use the address of the machine hosting each service.

## 3. Allow model access through UFW

On a server using UFW:

```bash
sudo ufw status verbose
ip -4 route show scope link
```

Find the connected subnet for the trusted Ethernet/Wi-Fi LAN, ignoring Docker and VPN routes. A route beginning `192.168.1.0/24 dev ...` identifies subnet `192.168.1.0/24`.

If UFW is active, replace the example subnet below with yours, then run on the server:

```bash
LAN_SUBNET='192.168.1.0/24'  # Replace with your trusted LAN subnet
sudo ufw allow from "$LAN_SUBNET" to any port 18080 proto tcp
sudo ufw status numbered
```

This rule permits model access from that subnet without depending on a particular interface name. Use a single client's IPv4 address instead of a subnet to allow only that client. If UFW is inactive, check the firewall you actually use; do not enable another firewall just for this step. No model restart is needed after adding the rule.

The model and search services are intended for a trusted LAN. Anyone who can reach their ports can use them, and HTTP does not encrypt requests or responses. Do not forward these ports through the router. Docker-published search traffic follows Docker's networking rules; the UFW rule above applies to the host's llama.cpp process, not a general access policy for Docker containers. See [Docker port publishing](https://docs.docker.com/engine/network/port-publishing/).

## 4. Verify from the client

From a Linux/macOS client terminal, replacing the example server IP:

```bash
curl --connect-timeout 5 -fsS http://192.168.1.50:18080/health
curl --connect-timeout 5 -fsS http://192.168.1.50:18080/v1/models
```

From Windows PowerShell:

```powershell
Test-NetConnection -ComputerName 192.168.1.50 -Port 18080
curl.exe --connect-timeout 5 -fsS http://192.168.1.50:18080/health
curl.exe --connect-timeout 5 -fsS http://192.168.1.50:18080/v1/models
```

Expect `TcpTestSucceeded : True` on Windows, health status `ok`, and the model ID. For search, open `http://192.168.1.50:8888` in the client's browser and follow the [JSON search check](06-search-server.md#3-check-from-a-client).

If a check fails, isolate the layer before changing the editor:

| Result | Next check |
|---|---|
| Server-local health fails | Launcher output, model loading, and listening port |
| Server-local works; client times out | Server IP, firewall rules, guest Wi-Fi/client isolation, VPN route |
| Client health works; editor fails | Exact URL and API type, model ID, client proxy settings |
| Model works; search fails | SearXNG container and port 8888 separately |

Paste plain URLs into configuration files, not Markdown links. After the connection checks pass, configure [Code](04-code-oss-setup.md) or [Zed](03-zed-setup.md) and test an actual file read. Health checks alone do not verify agent tool use.

## 5. Shared server behavior

The Linux launcher uses `-np 1`: all clients share one inference slot, so requests may wait for each other. Another client does not load another model copy. Match each client's context limit to the running server's `-c`; an editor cannot enlarge the server's allocation.

Run the editor and open the project on the client to keep file edits and terminal execution there. This guide assumes ordinary local editor sessions, not Remote SSH or dev containers, which place tools in a different execution environment.
