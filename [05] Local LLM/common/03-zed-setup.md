# Zed client: connect to the model server

[Start here](../README.md) · [Network access](05-network-access.md)

**Run this guide on the client.** Open the project there: Zed runs file and terminal tools on the client while the server handles inference. A client needs neither model files nor an inference GPU. The same machine can perform both roles.

## 1. Have the server connection ready

Complete [network access](05-network-access.md) and record the server address, model ID, and context size. The example uses a Linux server at **192.168.1.50:18080** with model ID **swift-qwen**. Replace the IP with your server's address; use `127.0.0.1` if Zed runs on the server machine.

The Linux quick start has a 16384 context; its tuned launcher has 65536. The supplied Windows server launcher uses localhost port 8080 and a 32768 context; read its model ID from `/v1/models`. These values depend on the server, not on the OS running Zed.

## 2. Configure Zed

In Zed's command palette, open `zed: open settings file`. On Linux this is normally `~/.config/zed/settings.json`. Merge this into your existing settings; if `language_models` already exists, add the `llama.cpp` entry inside it.

```json
{
  "language_models": {
    "llama.cpp": {
      "api_url": "http://192.168.1.50:18080",
      "auto_discover": false,
      "available_models": [
        {
          "name": "swift-qwen",
          "display_name": "Swift 1.5 Qwen 27B (local)",
          "max_tokens": 16384,
          "supports_tools": true,
          "supports_images": false
        }
      ]
    }
  }
}
```

Use the server root URL for this native provider, without `/v1`. No API key is needed for the unauthenticated server configuration in this guide. These provider fields follow [Zed's local-model documentation](https://zed.dev/docs/ai/use-a-local-model).

Match `max_tokens` to the server's `-c`: **16384** for the quick start, **65536** for the repository's tuned launcher, or **49152** if you reduced its context. This setting describes context capacity; it does not allocate more server memory. The launcher's `-n 16384` is a separate reply cap.

## 3. Try chat, then file tools

Open your project in Zed, run `agent: new thread`, choose the built-in Zed Agent, and select **Swift 1.5 Qwen 27B (local)**. First ask a short text question. Then ask:

> Read README.md and name two files it links to. Do not edit anything.

Check that the agent actually reads the file. Next, try a small edit in a disposable project and review the diff. Chat success alone does not verify tool calling; `supports_tools` advertises the capability to Zed but cannot make a model execute tools reliably. This guide's Swift/Zed tool loop has not yet been verified end to end.

## Troubleshooting

- **Connection refused or timed out:** follow the [network checks](05-network-access.md); the model service must be running on the server.
- **Model missing or unknown:** check `/v1/models`; the settings name and server alias must match. Restart after adding the alias.
- **Context errors:** match `max_tokens` to `-c`, then start a fresh thread with fewer files attached.
- **Tool calls appear as text or fail:** confirm the running server has `--jinja`, inspect its log, and check that your llama.cpp build supports this GGUF's tool template.

This config covers Zed Agent and model-backed assistance. Autocomplete/edit prediction has [separate settings](https://zed.dev/docs/ai/edit-prediction).
