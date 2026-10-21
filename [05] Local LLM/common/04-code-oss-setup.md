# Code OSS: built-in agent with local llama.cpp

Use the Swift 1.5 Qwen3.8-27B text server from this guide inside Code's Chat panel. This walkthrough targets builds with **Chat: Manage Language Models → Add Models → Custom Endpoint**, available in compatible Code OSS builds. If that provider is absent, your build needs an update or a separate agent extension such as Cline; the Agents customization screen alone does not establish provider availability.

## 1. Start and check the server

Run the tuned launcher in a terminal and leave it open:

```bash
~/llm/start-llm.sh
```

Alternatively, choose text in `~/llm/llm.sh`. Only start one server. In your installed launcher, check that the server arguments include `--alias swift-qwen`, `--jinja`, and `-c 65536`. Older copies may lack the alias: add it and restart. Keep the device, Q8 KV cache, and MTP settings from [the launcher guide](../linux/03-launch-and-tuning.md).

In another terminal:

```bash
curl -fsS http://127.0.0.1:8080/health
curl -fsS http://127.0.0.1:8080/v1/models
```

Expect health status `ok` and model id `swift-qwen`.

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
        "url": "http://127.0.0.1:8080/v1/chat/completions",
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

## Troubleshooting

- **Connection refused:** keep the launcher running; check `/health`.
- **Unknown model:** compare `/v1/models` with `id`; restart after adding the alias.
- **404:** use the full `/v1/chat/completions` URL and the Chat Completions API type.
- **Context exceeded:** align the editor budget with `-c`; start a new thread with less attached context.
- **Invalid or missing tool calls:** check `--jinja`, the model's chat template support in your llama.cpp build, and `~/llm/logs/server.log`.

The model connection is for Chat and its agent tools. It does not automatically configure inline autocomplete.
