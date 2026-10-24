# Code OSS: built-in agent with local llama.cpp

The examples use the Linux launcher’s port **18080**. If using the Windows launcher, substitute **8080**, or match whichever port your server uses.

Use the Swift 1.5 Qwen3.8-27B text server from this guide inside Code's Chat panel. This walkthrough targets builds with **Chat: Manage Language Models → Add Models → Custom Endpoint**, available in compatible Code OSS builds. If that provider is absent, your build needs an update or a separate agent extension such as Cline; the Agents customization screen alone does not establish provider availability.

## 1. Start and check the server

Run the tuned launcher in a terminal and leave it open:

```bash
~/llm/start-llm.sh
```

Alternatively, choose text in `~/llm/llm.sh`. Only start one server. In your installed launcher, check that the server arguments include `--alias swift-qwen`, `--jinja`, and `-c 65536`. Keep the device, Q8 KV cache, and MTP settings from [the launcher guide](../linux/03-launch-and-tuning.md).

In another terminal:

```bash
curl -fsS http://127.0.0.1:18080/health
curl -fsS http://127.0.0.1:18080/v1/models
```

Expect health status `ok` and model id `swift-qwen`.

**Using a laptop with inference on another PC?** Follow the [LAN launcher setup](../linux/03-launch-and-tuning.md#use-the-pcs-model-from-a-laptop). The launcher enables LAN access by default. Replace `127.0.0.1` in the model URL with the PC's LAN IP; no API key is needed (`local` works if the editor requires a value). Run Code and open the project on the laptop so agent edits and terminal commands happen there.

## 2. Add the local model

Open **Chat: Manage Language Models** from the command palette. Choose **Add Models → Custom Endpoint**, name the group **Local llama.cpp**, and select **Chat Completions**. If prompted for a key, use `local` for this unauthenticated server.

Code opens `chatLanguageModels.json`. Add this provider object to its array, preserving other providers. This is a separate file from `settings.json`:

```json
[
  {
    "name": "Local llama.cpp",
    "vendor": "customendpoint",
    "apiKey": "local",
    "apiType": "chat-completions",
    "models": [
      {
        "id": "swift-qwen",
        "name": "Swift 1.5 Qwen 27B (local)",
        "url": "http://127.0.0.1:18080/v1/chat/completions",
        "toolCalling": true,
        "vision": false,
        "contextWindow": 65536,
        "maxOutputTokens": 8192
      }
    ]
  }
]
```

`local` is a placeholder, not an OpenAI credential. If you enabled server authentication with `--api-key`, retain the UI-generated secret reference and supply that server key instead. Configuration fields follow [Code's Custom Endpoint documentation](https://code.visualstudio.com/docs/agent-customization/language-models#_add-a-custom-endpoint-model).

### Choose a context budget for your hardware

For this 27B example, use the recommended RX 9070-class / 16 GB VRAM baseline or better. A 64K context can leave little memory for other GPU clients. Start with a smaller context if needed, measure memory under load, and close GPU-heavy apps while serving. Sway is optional; available VRAM matters more than the desktop name.

The proposed budget is **65,536 total = 57,344 input + 8,192 output**. Input includes instructions, tool definitions, file contents, and conversation history. For a UI asking for separate limits, use `maxInputTokens: 57344` and `maxOutputTokens: 8192`.

If you lower the server to `-c 49152`, also lower the editor context to 49152 (40,960 input + 8,192 output). For the setup guide's 16K quick start, use a 16384 context and a smaller output allowance such as 4096. Editor settings cannot enlarge the server's allocation. The launcher's `-n 16384` is a separate reply ceiling; requesting 8192 from the client is fine.

## 3. Use the built-in agent

Open your project folder, start a new Chat session, select **Agent** and **Swift 1.5 Qwen 27B (local)**. Use the local built-in agent session. You do not need to create a custom agent profile first.

Start with a file-read check:

> Read README.md and identify two linked files. Do not change anything.

Confirm that the tool activity shows an actual file read. Then try a bounded task in a disposable project:

> Add a greeting function in greet.js, import and call it from index.js, then run it with Node and report the output.

Review both edits and the command result. This exercises file reading, multiple-file edits, and terminal execution. If the model only prints suggested code, inspect tool availability and the server log. Enabling `toolCalling` does not itself establish reliable tool use. End-to-end Swift integration remains to be tested with this model and client.

### BYOK utility tasks

In Settings, search for `chat.byokUtilityModelDefault` and leave it at **Main Agent Model** to use the selected local model for built-in utility flows too. Explicit **Chat: Utility Model** or **Chat: Utility Small Model** selections override this default. This setting does not create the server connection or select the main chat model.

## 4. Optional: add free local web search

Run SearXNG on a Linux PC and use it from Code on that PC or another device on your home LAN. It searches online engines; the community-maintained [mcp-searxng adapter](https://github.com/ihor-sokoliuk/mcp-searxng) lets the agent search and read selected pages. Swift continues running through llama.cpp.

```text
Code Agent + Swift → MCP tool → local SearXNG → online search engines
                             → read a result's URL → page text for Swift
```

There is no search API key or subscription in this setup. It still needs internet access, and upstream engines can rate-limit or block requests; free does not mean guaranteed unlimited searches. Queries leave your PC. The search services use CPU and system RAM, with no GPU allocation configured; returned text uses the model's existing context budget.

### A. Install the prerequisites

Run these commands on the **Arch/CachyOS PC hosting SearXNG**. Code runs locally on each client device, outside SSH sessions or dev containers:

```bash
sudo pacman -Syu --needed docker nodejs npm curl openssl
sudo systemctl enable --now docker
node --version
npx --version
```

Each device running Code needs **Node.js 22 or newer** and npm for the MCP adapter. Docker is needed only on the PC hosting SearXNG. Restart Code after installing Node so it can find `npx`. Docker commands below use `sudo`; no Docker group change is needed.

### B. Start SearXNG for the home LAN

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

The image downloads on first use. `0.0.0.0:8888:8080` publishes search on the PC's IPv4 interfaces at port **8888**, without API authentication. Any device that can reach that port can use it; use this setup on a trusted home LAN and do not forward the port through the router. HTTP does not encrypt searches or results. llama.cpp uses **18080**. The limiter is disabled for this private setup; `secret_key` is SearXNG's internal signing secret, not a client API key. See [Docker's port-publishing reference](https://docs.docker.com/engine/network/port-publishing/) and the [SearXNG container documentation](https://docs.searxng.org/admin/installation-docker.html).

Wait a few seconds, then open **http://127.0.0.1:8888** in a browser and try a search. Also check the JSON endpoint used by MCP:

```bash
curl -fsS --get 'http://127.0.0.1:8888/search' \
  --data-urlencode 'q=llama.cpp server documentation' \
  --data-urlencode 'format=json'
```

Expect JSON containing a nonempty `results` array with titles and URLs. An empty array is not a successful search check; inspect `unresponsive_engines` for upstream failures. Enabling `json` in `search.formats` is required for the [search API](https://docs.searxng.org/dev/search_api.html).

### C. Connect Code to the search tools

Open the command palette and run **MCP: Open User Configuration** to use search across projects. Alternatively, create `.vscode/mcp.json` for just one project. This is separate from `chatLanguageModels.json`.

Add `searxng` inside the existing `servers` object, preserving other servers. For a new file, paste the whole example:

```json
{
  "servers": {
    "searxng": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "mcp-searxng"],
      "env": {
        "SEARXNG_URL": "http://127.0.0.1:8888"
      }
    }
  }
}
```

On a laptop, change `SEARXNG_URL` to `http://<PC-LAN-IP>:8888`, for example `http://192.168.1.50:8888`. Find the PC's address with `ip -br -4 address show scope global`. Check that URL in the laptop's browser, then restart the MCP server after saving the configuration. No key is required. Keep `127.0.0.1` only when Code and SearXNG run on the same PC.

Code starts the adapter through `npx`, which downloads the package on first use. The adapter talks to Code over stdio, so it opens no additional listening port. Configuration follows [Code's MCP reference](https://code.visualstudio.com/docs/agents/reference/mcp-configuration).

### D. Check that Swift searches and reads a page

1. Save the file. Run **MCP: List Servers → searxng → Start**, and review the trust prompt.
2. Open a **local Agent** chat with **Swift 1.5 Qwen 27B (local)** selected.
3. In the chat's tool picker, enable **searxng_web_search** and **web_url_read**. Leave other search tools off initially to keep the model's tool list small.
4. Send this test:

> Use searxng_web_search to find the official llama.cpp server documentation. Return three results, then use web_url_read to read the most relevant official page, limiting the returned text to 4000 characters. Explain its server startup instructions and cite the URL. Do not edit files.

Check the activity for **both an executed search and an executed page read**. Links written from memory do not prove browsing worked. The adapter's [tool reference](https://github.com/ihor-sokoliuk/mcp-searxng/blob/main/docs/tools.md) documents both operations. Page reading extracts content; this basic setup cannot reliably read login-only, CAPTCHA-protected, or JavaScript-only pages.

For everyday use, ask the agent to search, read relevant sources, and cite their URLs. Keep requests to a few results and short page extracts so web content does not fill Swift's context. This gives the local agent a search-and-read workflow; answer quality still depends on the model using the tools correctly. The complete Swift/Code integration has not yet been tested end to end.

### Stop, restart, and troubleshoot

SearXNG runs in the background and starts after reboot unless you explicitly stop it. Use these commands as needed; run only the command for the action you want:

```bash
sudo docker stop searxng            # Stop search when not needed
sudo docker start searxng           # Start the existing container again
sudo docker restart searxng         # Reload after editing settings.yml
sudo docker logs --tail 50 searxng   # Inspect startup/search errors
```

- **Container name already in use:** use `sudo docker start searxng`; the creation command is only needed once.
- **Cannot connect to the Docker daemon / missing docker.sock:** run `sudo systemctl enable --now docker`, then `sudo docker info`. If startup fails, inspect `sudo journalctl -u docker -b --no-pager -n 50`.
- **Browser or curl cannot connect:** check `sudo docker ps -a` and the container logs before troubleshooting MCP. For laptop access, verify the PC IP and the published binding `0.0.0.0:8888->8080/tcp`; guest Wi-Fi isolation or firewall rules can block access.
- **JSON request returns 403:** check that the mounted `settings.yml` includes `json`, then restart the container. The browser UI working alone does not prove JSON access works.
- **Empty results, CAPTCHA, or 429:** an upstream engine may be blocking requests. Wait and retry less frequently; inspect the engine errors and try another available engine. Self-hosting does not remove upstream limits.
- **MCP fails to start:** use **MCP: List Servers → searxng → Show Output**. Check Node's version and that Code can find `npx`.
- **No MCP commands or tool calls:** your Code OSS build may lack MCP integration, or Swift may not be calling tools correctly. Check the tool picker and section 3 before changing SearXNG.

## Troubleshooting

- **Connection refused:** keep the launcher running; check `/health`.
- **Unknown model:** compare `/v1/models` with `id`; restart after adding the alias.
- **404:** use the full `/v1/chat/completions` URL and the Chat Completions API type.
- **Context exceeded:** align the editor budget with `-c`; start a new thread with less attached context.
- **Invalid or missing tool calls:** check `--jinja`, the model's chat template support in your llama.cpp build, and `~/llm/logs/server.log`.

The model connection is for Chat and its agent tools. It does not automatically configure inline autocomplete.
