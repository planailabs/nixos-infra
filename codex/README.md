# codex

LiteLLM gateway exposing ChatGPT Plus / Codex models through OpenAI-compatible
APIs, using the [`litellm-codex-oauth-provider`](https://github.com/jslorrma/litellm-codex-oauth-provider)
custom provider.

## Overview

- **Hostname:** `codex`
- **Platform:** x86_64-linux (LXC container)
- **Base:** modelled on `logos` (common + container modules, yggdrasil, nginx + ACME)

## Services

- **LiteLLM** — LLM gateway on `127.0.0.1:8080`, fronted by nginx at `codex.plan.ai`.
  Runs `pkgs.litellm-with-codex`, which is the nixpkgs litellm proxy with the
  Codex OAuth provider bundled into its Python environment.
- **Nginx** — reverse proxy with ACME TLS (cert distributed from `acme.plan.ai`).
- **Yggdrasil** — mesh networking on port 14466 (lets `logos` scrape node metrics).

## Models

Configured in `default.nix` under `services.litellm.settings.model_list`:

| Model name | Backing model |
|------------|---------------|
| `chatgpt-plus-gpt-5.1-codex-max` | `codex/gpt-5.1-codex-max` |
| `chatgpt-plus-gpt-5.1-codex` | `codex/gpt-5.1-codex` |
| `chatgpt-plus-gpt-5.1-codex-mini` | `codex/gpt-5.1-codex-mini` |
| `chatgpt-plus-gpt-5.1` | `codex/gpt-5.1` |

## Secrets

`LITELLM_MASTER_KEY` (the API key clients present to the proxy) lives in the
`private` submodule at `private/codex.nix` → `/etc/litellm.env`.

### Authenticating with Codex

The Codex OAuth credentials are **not** stored in the repo. The Codex CLI is in
the host's `systemPackages`, so authenticate directly on the box:

```sh
ssh root@codex.plan.ai
codex login        # writes /root/.codex/auth.json
```

`CODEX_AUTH_FILE` points the provider at `/root/.codex/auth.json`, and litellm
runs as **root** (not the module's default DynamicUser) so it can rewrite that
file on token refresh.

### Token refresh

This host uses a [fork](https://github.com/mkg20001/litellm-codex-oauth-provider)
of the provider that **implements OAuth access-token refresh**: when the access
token is expired (or about to be), it exchanges the `refresh_token` at
`https://auth.openai.com/oauth/token` and writes the rotated tokens back to
`/root/.codex/auth.json` in place. Redeploys never clobber it (the seed copy is
skipped when the file exists). You only need to re-run `codex login` and update
the secret if the **refresh token itself** is revoked.

## Usage

```sh
curl https://codex.plan.ai/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "chatgpt-plus-gpt-5.1-codex", "messages": [{"role": "user", "content": "hi"}]}'
```

## Firewall

Open TCP ports: 80, 443

## Configuration

- `default.nix` — main server configuration (litellm + credential wiring)
- `nginx.nix` — nginx virtual host
- `../private/codex.nix` — secrets (litellm master key, ACME token)
- `../pkgs/litellm-codex-oauth-provider.nix` — the provider package
- `../pkgs/overlay.nix` — builds `litellm-with-codex`

## Deploying

From the repository root:

```sh
./codex.sh
```

This runs `nixos-rebuild switch` targeting `root@codex.plan.ai`.
