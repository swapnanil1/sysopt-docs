# Code OSS client: model and search tools

[Start here](../README.md) · [Network access](05-network-access.md) · [Search server](06-search-server.md)

**Run this guide on the client**, with the project open locally in Code. The server performs model inference; Code executes file edits, terminal commands, and MCP tools on the client. The client can be a laptop, desktop, or the server machine itself.

This walkthrough targets builds with **Chat: Manage Language Models → Add Models → Custom Endpoint** and MCP support. If that provider is absent, use a compatible build or an agent extension with its own provider configuration; the Agents customization screen alone does not establish provider availability.

## 1. Have the server connection ready

Complete [network access](05-network-access.md) first and record the model URL, model ID, and context size. The examples below use a Linux server at **192.168.1.50:18080**, model **swift-qwen**, and a **65536** context. Replace the example IP with your server's address. Use `127.0.0.1` when client and server are the same machine.

The supplied Windows server launcher uses localhost port **8080**, a **32768** context, and its model ID must be read from `/v1/models`. The client's operating system does not determine these values. Running Code on Windows does not require installing the Windows model server.

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
        "url": "http://192.168.1.50:18080/v1/chat/completions",
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

The server hardware, not the client hardware, determines this budget. For this 27B example, the server guide recommends an RX 9070-class / 16 GB VRAM baseline or better. A 64K context can leave little memory for other GPU clients. Start with a smaller context if needed, measure memory under load, and close GPU-heavy apps while serving. The client does not need an inference GPU or a copy of the model.

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

First set up the [SearXNG server](06-search-server.md) and verify that the client can reach it. This section connects the community-maintained [mcp-searxng adapter](https://github.com/ihor-sokoliuk/mcp-searxng) to that service. The adapter searches through SearXNG and reads selected pages directly; returned text becomes part of the model's context.

Install **Node.js 22 or newer and npm on this client**, then restart Code so it can find `npx`. Check in Code's terminal:

```bash
node --version
npx --version
```

### A. Add the MCP configuration

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
        "SEARXNG_URL": "http://192.168.1.50:8888"
      }
    }
  }
}
```

Replace the example server IP in `SEARXNG_URL` with your search server's address. Use `http://127.0.0.1:8888` only if SearXNG runs on this same machine. No API key is required. The model and search services can use the same server or different servers.

Code starts the adapter through `npx`, which downloads the package on first use. The adapter talks to Code over stdio, so it opens no additional listening port. Configuration follows [Code's MCP reference](https://code.visualstudio.com/docs/agents/reference/mcp-configuration).

### B. Check search and page reading

1. Save the file. Run **MCP: List Servers → searxng → Start**, and review the trust prompt.
2. Open a **local Agent** chat with **Swift 1.5 Qwen 27B (local)** selected.
3. In the chat's tool picker, enable **searxng_web_search** and **web_url_read**. Leave other search tools off initially to keep the model's tool list small.
4. Send this test:

> Use searxng_web_search to find the official llama.cpp server documentation. Return three results, then use web_url_read to read the most relevant official page, limiting the returned text to 4000 characters. Explain its server startup instructions and cite the URL. Do not edit files.

Check the activity for **both an executed search and an executed page read**. Links written from memory do not prove browsing worked. The adapter's [tool reference](https://github.com/ihor-sokoliuk/mcp-searxng/blob/main/docs/tools.md) documents both operations. Page reading extracts content; this basic setup cannot reliably read login-only, CAPTCHA-protected, or JavaScript-only pages.

For everyday use, ask the agent to search, read relevant sources, and cite their URLs. Keep requests to a few results and short page extracts so web content does not fill Swift's context. This gives the local agent a search-and-read workflow; answer quality still depends on the model using the tools correctly. The complete Swift/Code integration has not yet been tested end to end.

## Troubleshooting

- **Connection refused or timed out:** use the [network checks and firewall guidance](05-network-access.md). Check the server address, port, and service before changing editor settings.
- **Unknown model:** compare `/v1/models` with the configured `id`.
- **404:** use the complete `/v1/chat/completions` URL and Chat Completions API type. Paste a plain URL, not Markdown link syntax.
- **Context exceeded:** align the editor budget with the server's `-c`; start a new thread with less attached context.
- **Invalid or missing model tool calls:** check `--jinja`, the model's chat template support, and the server log on the server machine.
- **MCP fails to start:** use **MCP: List Servers → searxng → Show Output**. Check the client's Node version and `npx` discovery.
- **Search fails:** first repeat the direct JSON check in the [search server guide](06-search-server.md#3-check-from-a-client). If it works, inspect the MCP output and `SEARXNG_URL`.

This connection is for Chat and its agent tools. It does not automatically configure inline autocomplete.
