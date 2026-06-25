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

Held in the `private` submodule at `private/codex.nix`:

- `/etc/litellm.env` — `LITELLM_MASTER_KEY` (the API key clients present to the proxy).
- `/etc/codex-auth.json` — the Codex CLI OAuth credentials.

### Obtaining `codex-auth.json`

1. On any machine with the Codex CLI, run `codex login`.
2. Copy the resulting `~/.codex/auth.json` into `private/codex.nix`
   (`environment.etc."codex-auth.json"`).
3. Redeploy.

The provider loads the file via systemd `LoadCredential` (exposed to the service
as `$CREDENTIALS_DIRECTORY/codex-auth`, pointed at by `CODEX_AUTH_FILE`).

> **Note:** upstream has **not** implemented automatic token refresh. When the
> access token expires, re-run `codex login`, update `private/codex.nix`, and
> redeploy.

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
- `../private/codex.nix` — secrets (master key, Codex auth.json)
- `../pkgs/litellm-codex-oauth-provider.nix` — the provider package
- `../pkgs/overlay.nix` — builds `litellm-with-codex`

## Deploying

From the repository root:

```sh
./codex.sh
```

This runs `nixos-rebuild switch` targeting `root@codex.plan.ai`.
