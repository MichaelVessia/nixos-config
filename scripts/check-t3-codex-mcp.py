#!/usr/bin/env python3
"""Check Foundry's remote MCP settings without starting a model turn."""

import argparse
import json
import os
import select
import subprocess
import time
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--codex", default="codex", help="T3 provider's Codex binary")
    args = parser.parse_args()
    expected = {
        "t3-forge": "https://forge.bison-gray.ts.net/mcp",
        "t3-flomac": "https://flomac.bison-gray.ts.net/mcp",
        "t3-dev-machine": "https://dev-machine.bison-gray.ts.net/mcp",
    }
    scopes = {"orchestration:read", "orchestration:operate"}
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
        initialized = request("initialize", {
            "clientInfo": {"name": "t3_mcp_config_check", "version": "1.0.0"},
            "capabilities": {"experimentalApi": True},
        })
        process.stdin.write(b'{"method":"initialized"}\n')
        process.stdin.flush()
        home = Path(initialized["codexHome"])
        result = request("config/read", {"includeLayers": True, "cwd": str(Path.cwd())})
        user_layers = [
            layer for layer in result.get("layers", [])
            if layer["name"].get("type") == "user"
            and Path(layer["name"]["file"]) == home / "config.toml"
        ]
        if not user_layers:
            raise RuntimeError("The app server did not load its user config.toml")
        servers = result["config"].get("mcp_servers", {})
        for name, url in expected.items():
            server = servers.get(name, {})
            user_server = user_layers[-1]["config"].get("mcp_servers", {}).get(name, {})
            if (
                server.get("url") != url
                or not server.get("enabled", True)
                or set(server.get("scopes", [])) != scopes
                or user_server.get("url") != url
                or set(user_server.get("scopes", [])) != scopes
            ):
                raise RuntimeError(f"{name}: the loaded URL, scopes, or enabled setting is incorrect")
        print(f"PASS: Codex loaded all remote entries from {home / 'config.toml'}")

        # T3 injects this dotted entry in thread/start, alongside the user config.
        session = request("thread/start", {
            "ephemeral": True,
            "cwd": str(Path.cwd()),
            "sandbox": "read-only",
            "approvalPolicy": "never",
            "config": {
                "tools.update_plan.enabled": True,
                "mcp_optional_startup_grace_ms": 10000,
                "mcp_servers.t3-code": {"url": "http://127.0.0.1:1/mcp", "enabled": False},
            },
        })
        for name in expected:
            status = request("mcpServerStatus/list", {
                "threadId": session["thread"]["id"],
                "serverName": name,
                "detail": "toolsAndAuthOnly",
            })
            if not any(server["name"] == name for server in status["data"]):
                raise RuntimeError(f"{name}: missing after T3's thread MCP override")
            print(f"PASS: {name} remains configured with T3's thread MCP override")
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
