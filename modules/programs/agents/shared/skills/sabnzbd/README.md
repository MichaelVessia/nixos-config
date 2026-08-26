# SABnzbd Skill

Agent guidance for operating SABnzbd through Executor and the consolidated
Garage MCP service.

## Delivery path

```text
agent -> Executor MCP -> garageMcpHomelab -> garage-mcp -> SABnzbd
```

The skill exposes five reads and three approval-gated mutations. It intentionally
has no local CLI, compatibility shell script, raw curl recipes, or local
SABnzbd credentials.

## Prerequisites

- The agent has the Executor MCP server configured.
- Executor has the `garage-mcp` integration and `garageMcpHomelab` connection.
- Executor has `require_approval` policies for the exact saved-connection addresses:
  - `garage-mcp.user.garageMcpHomelab.sabnzbd_pause`
  - `garage-mcp.user.garageMcpHomelab.sabnzbd_resume`
  - `garage-mcp.user.garageMcpHomelab.sabnzbd_delete`
- Each mutation policy has been exercised through Executor and cancelled before
  tool invocation.
- Garage MCP stores the SABnzbd connection details in its private deployment.

See `SKILL.md` for the tool catalog, invocation workflow, and safety rules.
