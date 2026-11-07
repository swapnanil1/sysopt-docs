# Optional Swift Ask, Plan, and Agent profiles

[Code setup](04-code-oss-setup.md) · [Linux server](../%5B02%5D%20Linux.md)

These are separate custom agents for **Swift-1.5-Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf**. They preserve Code's built-in Ask, Plan, Agent, and Explore. Their instructions favor sequential work on one inference slot, focused file reads, bounded web results, and concise reports. They do not alter tokenization, raise the server context, or guarantee instruction compliance or measured token savings.

## Install on each Code OSS client

Close or save any local edits to previous copies before replacing them. Set `LLM_DOCS` to your checkout before running the copy commands:

```bash
LLM_DOCS="/path/to/sysopt-docs/[05] Local LLM"
CODE_PROMPTS="$HOME/.config/Code - OSS/User/prompts"
mkdir -p "$CODE_PROMPTS"
cp -n "$LLM_DOCS/common/agents/swift-ask.agent.md" \
  "$LLM_DOCS/common/agents/swift-plan.agent.md" \
  "$LLM_DOCS/common/agents/swift-agent.agent.md" \
  "$CODE_PROMPTS/"
```

`cp -n` preserves existing files. To upgrade them later, review the diff and deliberately replace the reviewed copies. On another editor build/profile, use **Chat: New Custom Agent** and choose its user/profile destination, or install in the project's `.github/agents/` folder. Avoid installing duplicate user and workspace copies with the same names. See [VS Code custom agents](https://code.visualstudio.com/docs/agent-customization/custom-agents).

Run **Developer: Reload Window**, start a new chat, select the agent, and separately select **Swift Qwen 27B Local** from the model picker. The files intentionally omit a hardcoded model selector: editor-specific model identifiers may differ between clients. A running LAN model endpoint is still required.

## Roles and tools

| Agent | Purpose | Tool access |
|---|---|---|
| [Swift Ask](agents/swift-ask.agent.md) | Investigate and explain; no edits or command execution | `read`, `search`, SearXNG search and URL reader |
| [Swift Plan](agents/swift-plan.agent.md) | Research an implementation plan; no edits or command execution | Same tools; explicit handoff to Swift Agent |
| [Swift Agent](agents/swift-agent.agent.md) | Implement, inspect diffs, run relevant verification | Adds `edit` and `execute` |

`read`, `search`, `edit`, and `execute` are groups, not individual tiny tools. Expand **Configure Tools** to inspect their actual inventory. The Agent list is sufficient for ordinary code editing and terminal-based tests. It does not enable every installed service: browser automation, GitHub-specific tools, and other MCP integrations need their own entries when required.

All three set `agents: []` and omit delegation tools. The Plan profile offers an **Implement with Swift** handoff with `send: false`: review and send it yourself. This switches the active role; it does not run another parallel model. The shared model remains a one-slot server.

The SearXNG tool IDs assume the MCP server is named `searxng` and exposes `searxng_web_search` and `web_url_read`, as in the tested configuration. If tool names differ in another package version, use Code's YAML completions and actual MCP tool list to adjust them. Do not assume generic `web` automatically grants these MCP tools.

## Verify each profile

- **Ask:** ask it to read README.md and explain two linked files. Expect real file reads and no edits or terminal execution.
- **Plan:** ask for a bounded change plan. Expect research, affected files, and verification steps, with no implementation. Test the handoff separately.
- **Agent:** in a disposable project, request one small edit and the relevant test. Inspect the diff and actual command result.
- **Web:** request one explicit search and one URL read; inspect both executed calls.

Valid YAML and file installation alone do not verify every role, handoff or tool end to end; use the checks above. Agent instructions supplement Code's underlying prompts; they do not replace all built-in system instructions or bypass permissions.

## Why no extra token-saving plugin by default?

The profiles already limit unnecessary reads, repeated tool failures, parallel exploration, and verbose reports. Do not shorten code, error messages, or evidence just to reduce prose. Caveman and RTK are optional experiments. RTK may reduce terminal-output context for noisy commands, but savings and correctness must be checked on the actual workload and full diagnostics should remain accessible. Neither tool increases Swift's hardware generation rate.
