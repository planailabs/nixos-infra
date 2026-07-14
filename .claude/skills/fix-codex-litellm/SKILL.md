---
name: fix-codex-litellm
description: Use when the codex.plan.ai litellm plugin (Codex OAuth custom provider) is throwing errors — HTTP 400/4xx/5xx from the Codex /responses endpoint, request/response translation failures, model-name or auth errors — to diagnose, fix the provider fork, and redeploy codex.plan.ai.
version: 1.0.0
author: plan.ai
license: MIT
metadata:
  hermes:
    tags: [nixos, infrastructure, litellm, codex, deploy]
    related_skills: [update-nixos]
user_invocable: true
---

# Fix codex.plan.ai litellm plugin

## Overview

`codex.plan.ai` runs a litellm proxy (official `ghcr.io/berriai/litellm-database`
image, DB mode) fronting ChatGPT's Codex backend through a **custom OAuth
provider**. The provider is a pinned fork —
`mkg20001/litellm-codex-oauth-provider` — that bridges chat-completions calls to
the Codex `/responses` API (`https://chatgpt.com/backend-api/codex/responses`).

Errors surface in the calling app's logs (e.g. `openclaw` on other hosts) and in
the litellm container logs on `codex.plan.ai`. Most bugs live in the **fork's
translation code**, not in this repo's Nix. This skill diagnoses the failure,
fixes it at the right layer, and redeploys.

Run all repo commands from the `nixos-infra` root. The git/gh account here is
`mkg20001`, which has **ADMIN** on the fork — fixes go directly to the fork's
`main`.

## Architecture map

- `codex/default.nix` — the host. Builds the litellm config dir at each start
  (`litellm-codex-config` oneshot → `genLitellmConfig`), runs the container, and
  defines the `codex_handler.py` shim. Config dir lives at `/var/lib/litellm-codex`,
  bind-mounted read-only into `/config`.
- `pkgs/litellm-codex-oauth-provider.nix` — packages the fork (pinned `rev` +
  `hash`). Its source is copied into the config dir (importable via
  `PYTHONPATH=/config`).
- Fork internals (clone to inspect — see Step 3):
  - `prompts.py` — **request** side: chat-completions messages → Codex `input`.
    `derive_instructions`, `_to_codex_input_items`, `_to_responses_content`.
  - `adapter.py` — **response** side: Codex `/responses` payload (JSON or SSE) →
    litellm `ModelResponse`. `transform_response`, `convert_sse_to_json`.
  - `models.py` / `model_map.py` — live model discovery + slug mapping.
  - `auth.py` — OAuth access-token refresh (rewrites `/root/.codex/auth.json`).
  - `streaming_utils.py`, `sse_utils.py` — SSE handling.
  - `images.py` — vision: downloads remote `http(s)` image URLs and inlines
    them as base64 `data:` URLs (the backend can't reliably fetch arbitrary
    public URLs — the Codex CLI only ever sends data URLs).
  - `provider.py` also implements `image_generation`/`aimage_generation` on
    top of the Responses-API hosted `image_generation` tool (there is no
    dedicated images endpoint; the b64 image arrives in
    `image_generation_call` output items' `result` field).
- Handler shim (`codexHandlerPy` in `codex/default.nix`) — re-exports the
  provider instance AND removes discovered model slugs from
  `litellm.open_ai_chat_completion_models` so litellm's dispatch doesn't route
  codex models to its built-in OpenAI handler. Also patches
  `litellm.images.main.get_optional_params_image_gen`: for custom providers
  litellm returns `{}` there (its provider-config registry is a hardcoded
  if/elif over built-ins), silently dropping standard image params
  (`n`/`quality`/`size`/`style`) before they reach the custom handler.

## Step 1: Capture the error

Get the exact error and its shape. The `param`/traceback tells you which layer.

Ask the user for the failing log line if not already provided, and pull the
container logs from the host:

```bash
ssh root@codex.plan.ai 'journalctl -u podman-litellm --no-pager -n 200'
ssh root@codex.plan.ai 'journalctl -u litellm-codex-config --no-pager -n 80'
```

## Step 2: Classify the failure

- **Request-translation (most common).** HTTP 400 from `.../codex/responses`
  with `invalid_request_error` naming an `input[...]` param, e.g.
  `Invalid value: 'text' ... Supported values are: 'input_text', ...` at
  `input[N].content[0].type`. → fix `prompts.py`. (Known example: list-form
  message `content` parts forwarded with chat-completions types instead of
  Responses-API types `input_text`/`input_image`/`output_text`.)
- **Response-translation.** Errors after a 200 from Codex — missing choices,
  bad tool_calls, SSE parse failures, wrong usage. → fix `adapter.py`.
- **Model not supported.** `model is not supported when using Codex with a
  ChatGPT account`, or a slug that 400s. Codex slugs change over time and are
  **discovered live** — nothing is hardcoded. Regenerate the config:
  `ssh root@codex.plan.ai systemctl restart podman-litellm` (re-runs
  `litellm-codex-config`). Check its journal for the discovered model_list.
- **Missing/hidden models, or 404 "Model not found" on /responses.** The
  backend version-gates BOTH endpoints: `/codex/models` by the `client_version`
  query param and `/codex/responses` by the `version` header. genLitellmConfig
  resolves the latest codex release tag from GitHub at each start and shares it
  via `/var/lib/litellm-codex/client-version.env` (fallback:
  `pkgs.codex.version`, which lags upstream). If new models are missing, check
  the journal's `codex client_version:` line first.
- **Broken/empty pricing (`priced models:` empty in the config journal).**
  Prices are scraped from the OpenAI pricing page by regex in
  `codex/default.nix` (`fetch_pricing`); the page's encoded-row format has
  changed more than once (column added, `"-"` placeholders for missing prices).
  Fetch the page, inspect the encoded rows around a known slug, adjust the
  parser, and test it standalone before deploying.
- **Dispatch / "api_key must be set".** Error names the custom provider
  (`CodexException`) but the traceback is in `llms/openai/openai.py` — a codex
  slug leaked into `litellm.open_ai_chat_completion_models`. → the shim in
  `codex/default.nix` (`codexHandlerPy`) should strip it; verify
  `available_model_slugs()` covers the slug.
- **Auth / token.** 401/expired. The provider refreshes `/root/.codex/auth.json`
  in place (mounted rw). If refresh is broken, re-run `codex login` on the host.
  Fixes to refresh logic go in `auth.py`.
- **Vision / images.** Three distinct shapes:
  - *Client refuses to send images* ("model does not support vision"): litellm
    only advertises what `model_info` declares. genLitellmConfig derives it per
    model from the discovery payload (`supports_vision` ← `input_modalities`
    contains `"image"`, `max_input_tokens` ← `context_window`); check
    `/model/info` on the proxy first.
  - *Remote image URL 400s* with `"Error while downloading file. Upstream
    status code: NNN."`, param `url`: the backend tried (and failed) to fetch
    the URL server-side. `images.py` should have inlined it as a data URL
    before send — check the container log for `failed to inline image` (the
    inliner deliberately forwards the URL on failure so the backend reports
    the error). Known cause: CDNs 403 non-descriptive user agents; `images.py`
    sends a descriptive UA. Also verify the URL itself is valid — a bad URL
    400s for everyone.
  - *Base64 `data:` URLs* need no inlining and always work — use one as the
    regression baseline when debugging the other shapes.
- **Image generation.** `/v1/images/generations` is served by
  `provider.py:aimage_generation` via the hosted `image_generation` tool on
  `/responses`. `size`/`quality`/`output_format`/`background` forward onto the
  tool spec (`auto` is dropped; DALL-E-style `standard`/`hd` map to
  `medium`/`high`); `n` fans out into concurrent runs (capped at 4);
  results are always `b64_json`. If it returns "no image data", dump the raw
  SSE events — the b64 lives in `response.output_item.done` items of type
  `image_generation_call`, field `result`.
  - *"no healthy deployments" for image model names*: clients ask for standard
    names (`gpt-image-*`, `dall-e-3`); genLitellmConfig aliases those to the
    top-priority codex slug with `model_info.mode: image_generation`.
  - *`n`/`quality`/`size` ignored*: they must survive litellm's
    `get_optional_params_image_gen`, which drops them for custom providers —
    that's what the shim patch (see Architecture map) fixes. Verify by calling
    the provider directly in the container with `optional_params={"n": 2}`.

## Step 3: Reproduce and fix in the fork

1. Read the current pin from `pkgs/litellm-codex-oauth-provider.nix` (`rev`).
2. Clone and check out that exact commit:
   ```bash
   d=$(mktemp -d); git clone git@github.com:mkg20001/litellm-codex-oauth-provider "$d/f"
   cd "$d/f" && git checkout <pinned-rev>
   ```
3. Locate the failing translation in the layer from Step 2. Prefer OpenAI's
   typed models (`openai.types.responses`) as the source of truth for the wire
   shape.
4. Make the **minimal** fix. Keep pure functions pure (the adapter is
   deliberately side-effect free). Add a focused helper rather than inlining.
5. Sanity-check the logic in plain Python before building (fast feedback).

To probe what the backend itself supports (new hosted tools, content shapes),
POST to it directly — copy `/root/.codex/auth.json` and
`/var/lib/litellm-codex/client-version.env` off the host, then send a raw
`/responses` payload with headers `Authorization: Bearer <access_token>`,
`chatgpt-account-id`, `OpenAI-Beta: responses=experimental`,
`originator: codex_cli_rs`, and `version: <client_version>` (without `version`
newer models 404). This is how image-generation support was discovered: a
payload with `"tools": [{"type": "image_generation"}]` streamed
`image_generation_call` items. The container's python also works for quick
runtime checks: `podman exec litellm sh -c 'cd /app && .venv/bin/python -c ...'`
(the host itself has no python3).

## Step 4: Push to the fork

`origin/main` should equal the pinned rev (this repo tracks the fork tip). Commit
onto `main` and push over SSH (gh here uses the SSH protocol):

```bash
cd "$d/f"
git checkout -B main origin/main   # after: git fetch origin main
git add -A && git commit -F - <<'EOF'
fix(<area>): <what>

<why — include the exact backend error text>

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
git remote set-url origin git@github.com:mkg20001/litellm-codex-oauth-provider.git
git push origin main
```

If `origin/main` has advanced past the pinned rev, rebase the fix onto `main`
first so you don't regress newer commits.

## Step 5: Repin the flake

Update `pkgs/litellm-codex-oauth-provider.nix`: bump `rev` to the new commit,
`version` to `0.3.1-unstable-<today>`, and refresh `hash`:

```bash
nix-prefetch-url --unpack --type sha256 \
  "https://github.com/mkg20001/litellm-codex-oauth-provider/archive/<new-rev>.tar.gz" \
  | tail -1 | xargs nix hash to-sri --type sha256
```

Verify the repinned package builds and contains the fix (the overlay package is
not a flake output; build it via the overlay):

```bash
nix build --impure --no-link --print-out-paths --expr \
  'let f = builtins.getFlake (toString ./.); pkgs = import f.inputs.nixpkgs {
     system = "x86_64-linux"; overlays = [ (import ./pkgs/overlay.nix) ]; };
   in pkgs.litellm-codex-oauth-provider'
```

Grep the resulting store path's
`lib/python*/site-packages/litellm_codex_oauth_provider/*.py` to confirm your
change is present.

> If you can't push to the fork (no access), fall back to a local Nix patch:
> add `patches = [ ./litellm-codex-oauth-provider-<slug>.patch ]` to the
> derivation and stage the patch file (flakes only see git-tracked files).
> Prefer the fork push; drop the patch once the fork carries the fix.

## Step 6: Deploy

```bash
git add pkgs/litellm-codex-oauth-provider.nix   # flakes only see tracked files
sh codex.sh   # nixos-rebuild switch --target-host root@codex.plan.ai (impure)
```

`codex.sh` regenerates the config dir (`litellm-codex-config`) and restarts the
container on switch — but only if the container/config **unit text** changed.
A provider-source-only bump changes the static dir the units reference, yet
the switch output may not list `podman-litellm` under "restarting". If it
didn't restart, do it explicitly (this also re-runs the config oneshot):

```bash
ssh root@codex.plan.ai 'systemctl restart podman-litellm.service'
```

## Step 7: Verify

```bash
ssh root@codex.plan.ai 'journalctl -u podman-litellm --no-pager -n 80'
```

Confirm the container came up healthy and the original error is gone. Ideally
re-trigger the failing request (or ask the user to) and watch the log clear.

Test end-to-end through the proxy with the master key (in `/etc/litellm.env`
on the host — `ssh root@codex.plan.ai 'grep LITELLM_MASTER_KEY /etc/litellm.env'`).
The proxy takes ~30s to come up after a restart; poll `/v1/models` until 200.

```bash
KEY=sk-...; BASE=https://codex.plan.ai
# capabilities litellm advertises (drives client behavior)
curl -s $BASE/model/info -H "Authorization: Bearer $KEY"
# chat (add "stream": true to cover the astreaming path too)
curl -s $BASE/v1/chat/completions -H "Authorization: Bearer $KEY" \
  -H 'Content-Type: application/json' \
  -d '{"model":"<slug>","messages":[{"role":"user","content":"hi"}]}'
# vision: content part {"type":"image_url","image_url":{"url":"<data-or-https-url>"}}
# image generation:
curl -s $BASE/v1/images/generations -H "Authorization: Bearer $KEY" \
  -H 'Content-Type: application/json' \
  -d '{"model":"<slug>","prompt":"...","size":"1024x1024","quality":"low"}'
```

For vision, test both a base64 `data:` URL (pure translation path) and a
remote `https:` URL (exercises the `images.py` inliner).

## Step 8: Commit

Commit the repin with a conventional message; push only if the user asks.

```bash
git commit -m 'fix(codex): bump litellm-codex-oauth-provider — <what>'
```

Do not touch the unrelated pre-existing `flake.lock` modification unless asked.

## Common pitfalls

1. Flakes only include **git-tracked** files — `git add` any new patch file or
   the deploy build won't see it.
2. The overlay package isn't a flake output; build it via the overlay expression
   above, not `nix build .#litellm-codex-oauth-provider`.
3. Codex model slugs are discovered live and change over time — never hardcode
   them; regenerate the config instead.
4. Keep `adapter.py` helpers side-effect free (sync + async paths share them).
5. Request bugs → `prompts.py`; response bugs → `adapter.py`. The 400's `param`
   (`input[...]` = request) tells you which.
6. gh here pushes over SSH — if an https remote fails with "could not read
   Username", `git remote set-url origin git@github.com:...`.
7. After `sh codex.sh`, check the switch output actually restarted
   `podman-litellm` — a provider-only bump may not, leaving the old code
   running (see Step 6).
8. The host has no `python3` on PATH — run helper scripts locally or inside
   the container (`podman exec litellm ... .venv/bin/python`).
9. When fetching third-party URLs from the provider (e.g. image inlining),
   send a descriptive `User-Agent` — CDNs like Wikimedia 403 library-default
   UAs.

## Verification checklist

- [ ] captured the exact error and identified the layer (request/response/model/auth)
- [ ] fix committed and pushed to the fork's `main`
- [ ] `pkgs/litellm-codex-oauth-provider.nix` repinned (rev + hash + version)
- [ ] repinned package builds and contains the fix
- [ ] `sh codex.sh` deployed successfully
- [ ] container healthy and original error gone in the logs
- [ ] repin committed with a conventional message
