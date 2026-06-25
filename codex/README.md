# codex

LiteLLM gateway exposing ChatGPT Plus / Codex models through OpenAI-compatible
APIs, using a [fork](https://github.com/mkg20001/litellm-codex-oauth-provider) of
the `litellm-codex-oauth-provider` custom provider.

## Overview

- **Hostname:** `codex`
- **Platform:** x86_64-linux (LXC container)
- **Base:** modelled on `logos` (common + container modules, yggdrasil, nginx + ACME)

## Services

- **LiteLLM** — LLM gateway on `127.0.0.1:8080`, fronted by nginx at `codex.plan.ai`.
  Runs the official `ghcr.io/berriai/litellm-database` image (pinned by digest)
  via podman/`oci-containers`. The nixpkgs litellm package can't do DB mode (no
  `litellm_proxy_extras`, no generated prisma client), so the upstream image —
  which bundles the prisma engines and runs migrations on startup — is used to
  get virtual keys, spend tracking and the admin UI. The Codex OAuth provider is
  mounted into the container as source (see `litellmStaticDir` / `genLitellmConfig`
  in `default.nix`).
- **PostgreSQL** — local DB backing litellm's virtual keys / spend / UI.
  Loopback-only, trust auth (single-purpose host; only the container connects
  over the shared host network namespace).
- **Nginx** — reverse proxy with ACME TLS (cert distributed from `acme.plan.ai`).
- **Yggdrasil** — mesh networking on port 14466 (lets `logos` scrape node metrics).

> **Note:** the litellm container needs nesting (podman inside the LXC). If the
> host's hypervisor disallows it, `podman-litellm.service` won't start — enable
> nesting on the container at the hypervisor level.

## Models

The model list is **not hardcoded**. On each container start, the
`litellm-codex-config` oneshot queries the account's live, API-usable models from
`GET /backend-api/codex/models` and writes the litellm `model_list` (each exposed
as its slug, backed by `codex/<slug>`). The provider also validates and sources
instructions against that same live list at runtime. If discovery fails it falls
back to a small recent set (`gpt-5.5`, `gpt-5.4`, `gpt-5.4-mini`).

See the current set with `curl https://codex.plan.ai/v1/models` (or the admin UI).
To refresh after OpenAI ships new models: `systemctl restart litellm-codex-config
podman-litellm`.

## Secrets

`LITELLM_MASTER_KEY` (the admin/root key for the proxy and UI) lives in the
`private` submodule at `private/codex.nix` → `/etc/litellm.env`. Per-user
**virtual keys** are minted at runtime against Postgres (via the admin UI at
`https://codex.plan.ai/ui` or `POST /key/generate` with the master key).

### Authenticating with Codex (the upstream account)

The Codex OAuth credentials are **not** stored in the repo. The Codex CLI is in
the host's `systemPackages`, so authenticate directly on the box:

```sh
ssh root@codex.plan.ai
codex login        # writes /root/.codex/auth.json
```

`/root/.codex` is mounted into the container and `CODEX_AUTH_FILE` points the
provider there.

### Token refresh

The provider fork **implements OAuth access-token refresh**: when the access
token is expired (or about to be), it exchanges the `refresh_token` at
`https://auth.openai.com/oauth/token` and writes the rotated tokens back to
`/root/.codex/auth.json` in place. You only need to re-run `codex login` if the
**refresh token itself** is revoked.

## Usage

```sh
# Admin (master key) — also used to mint virtual keys:
curl https://codex.plan.ai/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-5.5", "messages": [{"role": "user", "content": "hi"}]}'

# Mint a per-user virtual key:
curl https://codex.plan.ai/key/generate \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" -d '{"models": ["gpt-5.5"]}'
```

## Firewall

Open TCP ports: 80, 443

## Configuration

- `default.nix` — host config (Postgres, litellm container, config dir, codex CLI)
- `nginx.nix` — nginx virtual host
- `../private/codex.nix` — secrets (litellm master key, ACME token)
- `../pkgs/litellm-codex-oauth-provider.nix` — the provider package (mounted as source)

## Deploying

From the repository root:

```sh
./codex.sh
```

This runs `nixos-rebuild switch` targeting `root@codex.plan.ai`. After the first
deploy, run `codex login` on the host to populate `/root/.codex/auth.json`.
