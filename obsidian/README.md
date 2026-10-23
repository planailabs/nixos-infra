# obsidian

Headless Obsidian plus two web front ends over the `plan-ai/knowledge` vault.

## Services

- **obsidian** — Electron under Xvfb, holds the vault at
  `/var/lib/obsidian/home/knowledge` and runs the Local REST API plugin on
  `127.0.0.1:27123` (`OBSIDIAN_API_KEY` in `/etc/obsidian/mcp.env`).
- **obsidian-mcp-server** — MCP over Streamable HTTP on `127.0.0.1:3010`, read
  only (`OBSIDIAN_READ_ONLY=true`), published at `https://obsidian.plan.ai/mcp`.
- **silverbullet** — read-only web UI at `https://wiki.plan.ai`, behind
  oauth2-proxy (`login.plan.ai`).

## MCP authentication

`/mcp` is internet-reachable, so the server enforces a bearer token
(`MCP_AUTH_MODE=jwt`, HS256). The signing key is `MCP_AUTH_SECRET_KEY` in
`/etc/obsidian/mcp.env` (private submodule) — never in this repo:

```sh
key=$(ssh root@obsidian.plan.ai 'sed -n "s/^MCP_AUTH_SECRET_KEY=//p" /etc/obsidian/mcp.env')
python3 - "$key" <<'PY'
import base64, hashlib, hmac, json, sys, time

def b64(raw):
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()

# Scopes are checked per tool and per resource, with no wildcard: a call needs
# exactly `tool:<name>:read|write|admin`. Read-only mode publishes these four
# tools and three resources.
scopes = [
    "tool:obsidian_get_note:read",
    "tool:obsidian_list_notes:read",
    "tool:obsidian_list_tags:read",
    "tool:obsidian_search_notes:read",
    "resource:obsidian-vault-note:read",
    "resource:obsidian-tags:read",
    "resource:obsidian-status:read",
]

signing_input = b64(json.dumps({"alg": "HS256", "typ": "JWT"}).encode()) + "." + b64(json.dumps({
    "client_id": "obsidian-operator",
    "scope": " ".join(scopes),
    "sub": "operator",
    "exp": int(time.time()) + 365 * 24 * 3600,
}, separators=(",", ":")).encode())
print(signing_input + "." + b64(hmac.new(sys.argv[1].encode(), signing_input.encode(), hashlib.sha256).digest()))
PY
```

The token carries no per-user identity — anyone holding it reads the vault, so
treat it like the vault password and re-mint when someone leaves. Note the
server rejects tokens without a `client_id`/`cid` and a `scope` claim, and
`exp` must be in the future. A token with the handshake but not a tool's scope
still answers `tools/list` and fails the call with "Insufficient permissions".

Connect a client with:

```sh
claude mcp add --transport http obsidian https://obsidian.plan.ai/mcp \
  --header "Authorization: Bearer $TOKEN"
```

The landing page at `https://obsidian.plan.ai/` shows the tool inventory only to
callers that present a valid token (`landing.requireAuth` in
`../pkgs/obsidian-mcp-server/default.nix`).

## Deploying

```sh
./obsidian.sh
```
