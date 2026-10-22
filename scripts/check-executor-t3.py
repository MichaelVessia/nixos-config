#!/usr/bin/env python3
"""Check shared Executor access to T3 without starting agent work."""

import argparse
import json
import os
import select
import subprocess
import time


CHECK_CONNECTIONS = """
const inventory = await tools.executor.coreTools.connections.list({});
if (!inventory.ok) return { error: inventory.error.message };
const checks = [];
for (const integration of ['t3_forge', 't3_flomac', 't3_dev_machine', 't3_foundry']) {
  const connection = inventory.data.connections.find(c => c.integration === integration);
  if (!connection) return { error: integration + ': no saved connection' };
  const path = connection.address.replace(/^tools\\./, '') + '.t3_environment_read';
  const result = await tools[path]({});
  if (!result.ok) return { error: integration + ': ' + result.error.message };
  if (result.data.isError) return { error: integration + ': upstream tool failed' };
  const environment = result.data.structuredContent;
  if (!environment?.environmentId) return { error: integration + ': no environment identity' };
  checks.push({ integration, address: connection.address, label: environment.label });
}
return { checks };
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--codex", default="codex", help="Codex binary used by T3")
    args = parser.parse_args()
    process = subprocess.Popen(
        [args.codex, "app-server"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    buffer = b""
    request_id = 0

    def request(method, params):
        nonlocal buffer, request_id
        request_id += 1
        process.stdin.write(
            (json.dumps({"id": request_id, "method": method, "params": params}) + "\n").encode()
        )
        process.stdin.flush()
        deadline = time.monotonic() + 45
        while True:
            while b"\n" not in buffer:
                remaining = deadline - time.monotonic()
                if remaining <= 0 or not select.select([process.stdout], [], [], remaining)[0]:
                    raise RuntimeError(f"{method} timed out")
                chunk = os.read(process.stdout.fileno(), 65536)
                if not chunk:
                    raise RuntimeError("Codex app server exited before the check completed")
                buffer += chunk
            line, buffer = buffer.split(b"\n", 1)
            response = json.loads(line)
            if response.get("id") != request_id:
                continue
            if "error" in response:
                raise RuntimeError(f"{method} failed, code {response['error']['code']}")
            return response["result"]

    try:
        request("initialize", {
            "clientInfo": {"name": "executor_t3_check", "version": "1.0.0"},
            "capabilities": {"experimentalApi": True},
        })
        process.stdin.write(b'{"method":"initialized"}\n')
        process.stdin.flush()
        config = request("config/read", {"cwd": os.getcwd()})["config"]
        servers = config.get("mcp_servers", {})
        if servers.get("executor", {}).get("url") != "https://executor-mcp.bison-gray.ts.net/mcp":
            raise RuntimeError("Executor must use its advertised Tailscale origin")
        if {"t3-forge", "t3-flomac", "t3-dev-machine"} & servers.keys():
            raise RuntimeError("Remove the direct remote T3 entries from Codex")
        session = request("thread/start", {
            "ephemeral": True,
            "sandbox": "read-only",
            "approvalPolicy": "never",
        })
        response = request("mcpServer/tool/call", {
            "threadId": session["thread"]["id"],
            "server": "executor",
            "tool": "execute",
            "arguments": {"code": CHECK_CONNECTIONS},
        })
        execution = response.get("structuredContent", {})
        if response.get("isError") or execution.get("status") != "completed":
            raise RuntimeError("Executor did not complete the connection check")
        result = execution.get("result", {})
        if result.get("error"):
            raise RuntimeError(result["error"])
        checks = result.get("checks", [])
        if len(checks) != 4:
            raise RuntimeError("Executor did not verify all four T3 connections")
        for check in checks:
            print(f"PASS: {check['integration']} through {check['address']} ({check['label']})")
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError) as error:
        raise SystemExit(f"FAIL: {error}")
