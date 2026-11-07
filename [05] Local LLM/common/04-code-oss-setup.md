# Code OSS: Swift chat, agents, and web tools

[Start here](../README.md) · [Network access](05-network-access.md) · [Search server](06-search-server.md) · [Custom Swift agents](07-swift-agents.md)

Run these steps on each client with its project open locally. llama.cpp does inference on the LAN server; Code reads and edits files, executes commands, and calls MCP tools on the client. Use a Code OSS build that provides the Custom Endpoint provider and MCP support; provider availability depends on the bundled or enabled extensions. This is Code's chat/agent interface; no Continue extension is needed for this connection.

## 1. Verify the LAN server

Start `~/llm/start-llm.sh` on the Linux server. It binds **0.0.0.0:18080**, with model alias **swift-qwen**, **65,536 total context**, and **16,384 maximum output tokens**. Use its LAN address in the client. The examples use `192.168.1.50`; replace it everywhere with yours.

```bash
curl --connect-timeout 5 -fsS http://192.168.1.50:18080/health
curl --connect-timeout 5 -fsS http://192.168.1.50:18080/v1/models
```

Wait for health `ok` and verify the alias. Do not put `0.0.0.0` in a request URL: it is a listening address. Loopback health checks on the server remain useful, but the model is hosted across the trusted LAN. No router port forwarding is part of this setup.

A Windows client needs no Windows model installation to connect to this Linux server. A Windows-hosted model uses port 8080 and its separate Windows memory budget; see the [network guide](05-network-access.md).

## 2. Add the custom endpoint

Press **Ctrl+Shift+P → Chat: Manage Language Models → Add Models → Custom Endpoint**. Name it **Local llama.cpp**, choose **Chat Completions**, and use `local` if an API key is required. Configure the opened **chatLanguageModels.json**, not `settings.json`:

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
        "name": "Swift Qwen 27B Local",
        "url": "http://192.168.1.50:18080/v1/chat/completions",
        "toolCalling": true,
        "vision": false,
        "contextWindow": 65536,
        "maxOutputTokens": 16384
      }
    ]
  }
]
```

Preserve existing providers by adding this object to their array. If the UI generated a secret reference, keep it and enter the placeholder through the UI. `local` is not an OpenAI credential. If you deliberately enabled server API authentication, use the corresponding server key instead. See the [Custom Endpoint reference](https://code.visualstudio.com/docs/agent-customization/language-models#_add-a-custom-endpoint-model).

### Context and output must fit together

**65,536 total = 49,152 input + 16,384 output**. Input includes instructions, tool descriptions, conversation history, file contents, and search results. `contextWindow` includes output. If using separate fields, use `maxInputTokens: 49152` and `maxOutputTokens: 16384` instead. Do not set `maxInputTokens: 65536` plus 16,384 output for this server, and do not advertise 128K or 144K. Client settings do not allocate more server context.

The server's `-n 16384` is a reply ceiling, not a mandatory answer length. Keep prompts and tool output focused. A successfully loaded 64K cache is not proof of quality or stability at a fully occupied context.

### Keep vision disabled for this release

`"vision": true` only advertises a capability; it does not install an image encoder or projector. The [publisher's GSQ-RCO model card](https://huggingface.co/ukisai/Swift-1.5-Qwen3.8-27B-GSQ-RCO-GGUF#usage) states that a Swift 27B vision projector has not been verified for this release. The documented setup is text-only. Do not attach the unrelated Qwen3-VL image-generation projector to Swift. See [image generation versus image understanding](../linux/05-image-generation.md#image-generation-is-separate-from-swift-vision).

## 3. Verify the agent tool loop

Open a new Chat, choose **Agent**, and select **Swift Qwen 27B Local** in the model picker. The model picker and agent picker serve different purposes. A custom agent does not itself start or select the model server.

Start with:

> Read README.md and identify two files it links to. Do not modify anything.

Inspect the tool activity for actual file reads. Then, in a disposable project:

> Add a greeting function in greet.js, import and call it from index.js, then run it with Node and report the output.

Review the edits and terminal results. Verify text chat, file reading, edits, terminal execution, search, and URL reading separately; one working operation does not validate all the others. `toolCalling: true` is not proof that every task or tool works reliably.

For separate reusable Ask, Plan, and Agent profiles, install the [Swift agents](07-swift-agents.md). The built-in originals remain intact.

### Utility tasks

Where available, set **Chat: BYOK Utility Model Default** (`chat.byokUtilityModelDefault`) to **Main Agent Model**. Explicit **Chat: Utility Model** (`chat.utilityModel`) and **Chat: Utility Small Model** (`chat.utilitySmallModel`) selections override that default. These settings help built-in utility flows use your model; they do not establish the endpoint or change the main model selection. Verify the settings exposed by your build.

## 4. Add search and webpage reading

First verify [SearXNG's JSON endpoint](06-search-server.md). It uses CPU/system RAM and does not load a GPU model. The adapter below runs on the client and provides tools to Code; search is not a new capability flag in `chatLanguageModels.json`.

Install Node.js **22 or newer** and npm if needed. On an Arch client:

```bash
sudo pacman -Syu --needed nodejs npm
node --version
npx --version
```

Restart Code after installation so it sees `npx`.

Run **MCP: Open User Configuration** for all projects, or edit `.vscode/mcp.json` for one project. Add the server while preserving other entries:

```json
{
  "servers": {
    "searxng": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "mcp-searxng"],
      "env": {
        "SEARXNG_URL": "http://192.168.1.50:8888"
      }
    }
  }
}
```

Replace the IP with the search server's. If the adapter runs on the same machine as SearXNG, `http://127.0.0.1:8888` also reaches it. For a remote client, SearXNG must be published to the LAN as described in the search guide. Its URL is a SearXNG base URL, not a remote MCP `/mcp` endpoint. This local adapter uses stdio, not a listening port.

The first launch downloads the community-maintained [mcp-searxng package](https://github.com/ihor-sokoliuk/mcp-searxng). Confirm that the adapter reports a discovered tool inventory; names and counts may change with package versions. `npx -y` accepts the package download; pin a tested package version if repeatability across installations is important.

1. Run **MCP: List Servers → searxng → Start** and inspect the output.
2. In a new Agent chat with Swift selected, open **Configure Tools** beside the input.
3. Enable **searxng_web_search** and **web_url_read** under `searxng`.
4. Test:

> Use searxng_web_search to find the official llama.cpp server documentation. Return three results, then use web_url_read to read the most relevant official page, limiting the returned text to 4000 characters. Explain the server startup instructions and cite the URL. Do not edit files.

Code supplies enabled tool schemas to Swift. Swift requests a tool; Code executes the MCP call and returns its result to Swift. No model restart or special search flag is needed. Verify both a result-bearing search call and a separate page-reading call: links in an answer are not proof of a fetched page. See the adapter's [tool reference](https://github.com/ihor-sokoliuk/mcp-searxng/blob/main/docs/tools.md).

Limit results and extracts to what the task needs. Basic page extraction does not guarantee access to login-only, CAPTCHA-protected, or JavaScript-rendered pages. Retrieved web content is evidence, not authority to run commands or override the user's task.

## 5. Troubleshooting

### Only `agent-host-copilotcli` is accepted as vendor

If Code reports `Value is not accepted. Valid values: "agent-host-copilotcli"` for `customendpoint`, its current provider inventory may not include Custom Endpoint. Do not substitute that vendor or remove `vendor`: it identifies a different provider and does not create a Custom Endpoint connection.

Some Code OSS distributions bundle the GitHub Copilot extension that provides Custom Endpoint, while others require an extension or a different compatible build. Check **Extensions → @builtin copilot**, enable it if disabled, then **Developer: Reload Window**. Retry **Chat: Manage Language Models → Add Models**. If Custom Endpoint is still absent, inspect the **GitHub Copilot** Output channel and extension-host logs for activation problems. Presence of the source is not proof that it registered successfully in that session. Some other builds genuinely lack the provider; decide on an alternate extension only after checking.

### Sway asks to use weaker encryption

Check **Preferences: Configure Runtime Arguments**. A common Code OSS Linux location is `~/.vscode-oss/argv.json`; use the editor command to find the active profile's runtime file. `"password-store": "basic"` selects Chromium's weak fallback, not an OS keyring. It affects stored credentials, not model speed or HTTP transport.

Before switching to `"password-store": "gnome-libsecret"`, verify that an implementation of Secret Service (for example GNOME Keyring) is installed, available, and unlocked in the Sway session. Restart Code fully after changing runtime arguments; you may need to sign in again. Do not erase credential databases to silence the prompt. Follow the [official keychain troubleshooting](https://code.visualstudio.com/docs/configure/settings-sync#_troubleshooting-keychain-issues).

### Other connection and tool issues

| Symptom | Check |
|---|---|
| Connection refused or timeout | Server health, LAN IP, port, firewall and client isolation before changing Code |
| Unknown model | `/v1/models` must match `swift-qwen` |
| HTTP 404 | Full `/v1/chat/completions` URL and Chat Completions API type |
| Context exceeded | 65,536 total, 16,384 output; start a fresh thread with fewer attachments |
| Tool JSON printed instead of executed | Agent mode, selected Swift model, enabled tools, `--jinja`, and server log |
| MCP stays at initialize or cannot find npx | Node version, restart Code, inspect MCP Output; first package download can take time |
| Four tools discovered, but model never searches | Enable the tools for that chat/custom agent and ask for an explicit search |
| `///search` in adapter logs | An adapter may introduce redundant slashes when joining URLs. Inspect the HTTP response and returned results before treating this as a failure. Keep the base URL without trailing slashes; do not patch a working adapter solely for this log line |
| Search fails | Test SearXNG JSON directly, then inspect per-engine failures and MCP logs |

## 6. Inline autocomplete and optional token tools

Chat/Agent configuration does not connect local Tab completions. The [VS Code model documentation](https://code.visualstudio.com/docs/agent-customization/language-models#_can-i-use-local-language-models) distinguishes local BYOK chat from inline suggestions. An extension such as Continue can provide a separate local autocomplete path; see its [autocomplete guide](https://docs.continue.dev/customize/deep-dives/autocomplete).

A small model trained for code completion (for example Qwen2.5-Coder 1.5B) is a more suitable experiment than sharing Swift's one busy inference slot for every keystroke. A separate CPU-only server could avoid additional VRAM use but still consumes system RAM/CPU; measure latency on the target machine. No autocomplete model is installed by this guide.

The bundled Swift agents already request focused reads and concise answers. Caveman and RTK are optional, not required dependencies. RTK filters terminal output and may help with verbose test/build logs; it does not increase raw generation speed and its savings have not been measured here. Preserve access to complete diagnostics when debugging.
