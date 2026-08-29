# Executor v1.6.1–v1.6.3 changes

Executor was upgraded in the homelab from v1.6.0 to v1.6.3. This brief summarizes the changes most relevant to a self-hosted integration gateway.

## v1.6.1

- Added opt-in per-integration MCP search tools. `?search_tools=true` exposes a small `search_<integration>` tool for each connected integration; later work in the same release reduced their tool-definition cost from about 5,000 to 2,000 tokens at 30 integrations. [#1741](https://github.com/UsefulSoftwareCo/executor/pull/1741), [#1749](https://github.com/UsefulSoftwareCo/executor/pull/1749)
- Fixed remote MCP stream cleanup. Closing a connection now aborts its long-lived SSE request instead of leaking a Bun request slot. [#1716](https://github.com/UsefulSoftwareCo/executor/pull/1716)
- Improved MCP and OAuth correctness: missing MCP credentials report `expired`, dynamic OAuth registration identifies web/native clients correctly, and MCP pool keys no longer retain raw credentials. [#1582](https://github.com/UsefulSoftwareCo/executor/pull/1582), [#1609](https://github.com/UsefulSoftwareCo/executor/pull/1609), [#1573](https://github.com/UsefulSoftwareCo/executor/pull/1573)
- Improved local security by tightening credential/settings file permissions and reducing credential retention in browser/process memory. [#1576](https://github.com/UsefulSoftwareCo/executor/pull/1576), [#1579](https://github.com/UsefulSoftwareCo/executor/pull/1579), [#1570](https://github.com/UsefulSoftwareCo/executor/pull/1570), [#1574](https://github.com/UsefulSoftwareCo/executor/pull/1574)
- Made large Microsoft Graph OpenAPI specifications practical by using precomputed slices and streaming previews instead of parsing the 43 MB monolith. [#1753](https://github.com/UsefulSoftwareCo/executor/pull/1753), [#1751](https://github.com/UsefulSoftwareCo/executor/pull/1751), [#1755](https://github.com/UsefulSoftwareCo/executor/pull/1755)
- Fixed migration races, idle runtime reclamation, catalog refresh races, and several storage/connection failure paths. [v1.6.1 release PR](https://github.com/UsefulSoftwareCo/executor/pull/1743)

## v1.6.2

- Fixed overlapping API requests accidentally sharing one request's database provider/connection. Each request now gets an isolated execution-stack build and database connection. [#1802](https://github.com/UsefulSoftwareCo/executor/pull/1802)
- Repaired macOS desktop signing resources accidentally omitted from v1.6.1. This primarily affects desktop builds, not the homelab container. [#1807](https://github.com/UsefulSoftwareCo/executor/pull/1807)

Source: [v1.6.2 release](https://github.com/UsefulSoftwareCo/executor/releases/tag/v1.6.2).

## v1.6.3

### Most relevant to this homelab

- Stale tool catalogs refresh concurrently, and tools reads stop waiting after a short grace period instead of being blocked by slow upstream servers. Self-hosting adds `EXECUTOR_TOOLS_SYNC_TTL_MS` to control the default 15-minute freshness window. [#1560](https://github.com/UsefulSoftwareCo/executor/pull/1560), [#1824](https://github.com/UsefulSoftwareCo/executor/pull/1824)
- Added an integration-connect shortcut in the sidebar. [#1720](https://github.com/UsefulSoftwareCo/executor/pull/1720)
- Remote MCP servers behind authenticating proxies can now use custom request headers; HTTP 403 proceeds to authentication instead of being classified as unreachable. [#1821](https://github.com/UsefulSoftwareCo/executor/pull/1821)
- A boot migration repairs old SQLite OAuth-expiry values that could make every saved integration disappear after an upgrade. [#1823](https://github.com/UsefulSoftwareCo/executor/pull/1823)
- MCP OAuth gained explicit scopes, and OAuth apps can omit RFC 8707 `resource`, improving compatibility with servers behind Microsoft Entra. [#1607](https://github.com/UsefulSoftwareCo/executor/pull/1607), [#1822](https://github.com/UsefulSoftwareCo/executor/pull/1822)
- Self-hosted deployments can allow extra browser origins with `EXECUTOR_TRUSTED_ORIGINS` while keeping generated URLs pinned to `EXECUTOR_WEB_BASE_URL`. [#1441](https://github.com/UsefulSoftwareCo/executor/pull/1441)

### Other additions and hardening

- Stdio MCP source command, arguments, working directory, and declared environment can be edited in the UI. [#1775](https://github.com/UsefulSoftwareCo/executor/pull/1775)
- 1Password can span multiple explicitly addressed vaults. [#1829](https://github.com/UsefulSoftwareCo/executor/pull/1829)
- The Connect-an-agent card remembers transport, artifact, search, and approval choices. [#1772](https://github.com/UsefulSoftwareCo/executor/pull/1772)
- Added safer destructive-action confirmations and corrected foreign-organization URL handling. [#1546](https://github.com/UsefulSoftwareCo/executor/pull/1546), [#1825](https://github.com/UsefulSoftwareCo/executor/pull/1825)
- Hardened secret handling across GraphQL introspection logs, OAuth errors, persisted health samples, authorization-session cleanup, refresh-token rotation, and transaction-bound cleanup. [#1575](https://github.com/UsefulSoftwareCo/executor/pull/1575), [#1567](https://github.com/UsefulSoftwareCo/executor/pull/1567), [#1596](https://github.com/UsefulSoftwareCo/executor/pull/1596), [#1569](https://github.com/UsefulSoftwareCo/executor/pull/1569), [#1377](https://github.com/UsefulSoftwareCo/executor/pull/1377), [#1572](https://github.com/UsefulSoftwareCo/executor/pull/1572)
- Improved idle MCP connection/session cleanup and Last-Event-ID stream scoping. [#1577](https://github.com/UsefulSoftwareCo/executor/pull/1577), [#1529](https://github.com/UsefulSoftwareCo/executor/pull/1529)

Source: [v1.6.3 release](https://github.com/UsefulSoftwareCo/executor/releases/tag/v1.6.3).
