# Zed with the local Swift model

The examples use the Linux launcher’s port **18080**. If using the Windows launcher, substitute **8080**, or match whichever port your server uses.

Connect Zed to the Swift 1.5 Qwen3.8-27B GGUF used by [the Linux setup](../linux/01-setup.md). The server loads the weights; Zed sends requests to it.

## 1. Start the text server

For a first run with 16K context:

```bash
llama-server \
  -m ~/llm/models/Swift-1.5-Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf \
  --alias swift-qwen \
  -ngl 99 -c 16384 -fa on --jinja --host 0.0.0.0 --port 18080
```

For the tuned configuration, run `~/llm/start-llm.sh` instead, or choose text in `~/llm/llm.sh`. Run only one server on port 18080. The repository launcher includes `--alias swift-qwen` and `--jinja`.

These launches allow access from a trusted home LAN without an API key. Use `--host 127.0.0.1` in the command above, or `start-llm.sh --local`, for localhost only. Do not forward the server port through your router.

In another terminal:

```bash
curl -fsS http://127.0.0.1:18080/health
curl -fsS http://127.0.0.1:18080/v1/models
```

Wait for health status `ok`; the model list should contain `swift-qwen`. That is the API model id, independent of the filename on disk.

## 2. Configure Zed

In Zed's command palette, open `zed: open settings file`. On Linux this is normally `~/.config/zed/settings.json`. Merge this into your existing settings; if `language_models` already exists, add the `llama.cpp` entry inside it.

```json
{
  "language_models": {
    "llama.cpp": {
      "api_url": "http://127.0.0.1:18080",
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

Use the server root URL for this native provider, without `/v1`. No API key is needed for this launch command. These provider fields follow [Zed's local-model documentation](https://zed.dev/docs/ai/use-a-local-model).

On a laptop, set `api_url` to `http://<PC-LAN-IP>:18080`, for example `http://192.168.1.50:18080`. Run Zed and open the project on the laptop: its agent edits and terminal tools run there, while the PC handles inference. See [finding the PC's IP and checking connectivity](../linux/03-launch-and-tuning.md#use-the-pcs-model-from-a-laptop).

Match `max_tokens` to the server's `-c`: **16384** for the quick start, **65536** for the repository's tuned launcher, or **49152** if you reduced its context. This setting describes context capacity; it does not allocate more server memory. The launcher's `-n 16384` is a separate reply cap.

## 3. Try chat, then file tools

Open your project in Zed, run `agent: new thread`, choose the built-in Zed Agent, and select **Swift 1.5 Qwen 27B (local)**. First ask a short text question. Then ask:

> Read README.md and name two files it links to. Do not edit anything.

Check that the agent actually reads the file. Next, try a small edit in a disposable project and review the diff. Chat success alone does not verify tool calling; `supports_tools` advertises the capability to Zed but cannot make a model execute tools reliably. This guide's Swift/Zed tool loop has not yet been verified end to end.

## Troubleshooting

- **Connection refused:** keep the server terminal running and check `/health`.
- **Model missing or unknown:** check `/v1/models`; the settings name and server alias must match. Restart after adding the alias.
- **Context errors:** match `max_tokens` to `-c`, then start a fresh thread with fewer files attached.
- **Tool calls appear as text or fail:** confirm the running server has `--jinja`, inspect its log, and check that your llama.cpp build supports this GGUF's tool template.

This config covers Zed Agent and model-backed assistance. Autocomplete/edit prediction has [separate settings](https://zed.dev/docs/ai/edit-prediction).
