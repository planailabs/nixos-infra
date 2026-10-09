---
name: codex-healthcheck
description: Use when checking whether the codex.plan.ai litellm proxy works (scheduled health check) or when it is reported broken — probe /v1/models + a tiny chat completion, classify the failure against the known layers, then fix it (container/config, fork+repin+deploy, auth) and verify.
version: 1.0.0
author: plan.ai
license: MIT
metadata:
  tags: [nixos, infrastructure, litellm, codex, healthcheck, deploy]
  related_skills: [fix-codex-litellm, update-nixos]
user_invocable: true
---

# codex.plan.ai health check

Answer one question with evidence: **does `codex.plan.ai` serve its models right now**, and
if not, repair it. `fix-codex-litellm` has the architecture map, the failure taxonomy and the
full repo/fork/deploy mechanics — this skill is the *check* that decides whether that skill
is needed. Run everything from the `nixos-infra` root.

## 1. Probe (cheap first, stop at the first failure)

Project commands run in a `nix develop`; this flake has no default devshell, so run shell
tasks with `devshell: false`. `/etc/litellm.env` on the host holds `LITELLM_MASTER_KEY`.

```bash
BASE=https://codex.plan.ai
KEY=$(ssh root@codex.plan.ai 'grep ^LITELLM_MASTER_KEY /etc/litellm.env | cut -d= -f2-')

# a. reachability + advertised slugs (a non-empty list of codex slugs)
curl -sS -m 20 $BASE/v1/models -H "Authorization: Bearer $KEY"

# b. one tiny chat completion through the custom provider (OAuth + request and
#    response translation). Never stream at this hour — astreaming is covered by
#    the same wire path, and an SSE hang should not eat the night.
SLUG=$(curl -sS -m 20 $BASE/v1/models -H "Authorization: Bearer $KEY" \
  | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["data"][0]["id"])')
curl -sS -m 60 $BASE/v1/chat/completions -H "Authorization: Bearer $KEY" \
  -H 'Content-Type: application/json' \
  -d "{\"model\":\"$SLUG\",\"max_tokens\":16,\"messages\":[{\"role\":\"user\",\"content\":\"Reply with OK.\"}]}"
```

A healthy proxy answers `b.` with `choices[0].message` and `usage`. HTTP errors, an empty
`choices`, or a timeout are failures. Vision and image generation are *not* nightly probes
(expensive, and free to test on demand) — they are listed in `fix-codex-litellm`.

Record as evidence: the HTTP status, the error's `param`/message, the timestamp, and whether
`sh codex.sh` was run in the last day (that deploy also replaces the provider source — see 4).

## 2. When it fails: read the host logs

```bash
ssh root@codex.plan.ai 'systemctl status podman-litellm --no-pager -n 40; journalctl -u podman-litellm --no-pager -n 200'
ssh root@codex.plan.ai 'journalctl -u litellm-codex-config --no-pager -n 80'
```

Classify with `fix-codex-litellm`'s taxonomy (request translation, response translation,
model not supported, missing models, pricing, dispatch, auth, vision, image generation).

## 3. Auth only

`401`/expired, or `journalctl` showing the refresh failing:

```bash
ssh root@codex.plan.ai 'stat -c %y /root/.codex/auth.json; systemctl restart podman-litellm'
sleep 30   # the proxy takes ~30s; then re-run probe b
```

If the **refresh token** is revoked (`codex login` needed) that is the account's, not the
repo's — report it, do not loop (see `fix-codex-litellm` Step 2, Auth).

## 4. Repo / config only

A failure the container restart in (3) does not cure, with the config journal naming a
cause: model discovery empty → fallback slugs, `priced models:` empty → the pricing regex in
`codex/default.nix`, the handler shim in the same file for dispatch errors. Fix it there with
`fix-codex-litellm`'s constraints (never hardcode slugs), then deploy:

```bash
sh codex.sh                       # devshell: false; impure; targets root@codex.plan.ai
sleep 45 && ${probe b again}      # the switch may not restart podman-litellm on a
                                  # provider-only bump — then restart it explicitly
```

## 5. Fork / provider only

Translation bugs (`prompts.py` / `adapter.py` / `images.py`) are fixed in
`mkg20001/litellm-codex-oauth-provider`, then repinned in
`pkgs/litellm-codex-oauth-provider.nix` and deployed — `fix-codex-litellm` Steps 3-6, in
full. It touches the fork's `main` and the host; it is allowed here, but nothing else is:
`sh codex.sh` on `codex.plan.ai`, never another host, and no `codex login` unattended.

## 6. Upgrades can break the fork

Two host timers change codex.plan.ai on their own: `litellm-codex-refresh` (weekly;
re-discovers models + rescrapes prices) and `litellm-image-update` (weekly; pulls
`ghcr.io/berriai/litellm-database:main-stable` and restarts the container when it changed).
If the probe fails only for the newest slug, run
`ssh root@codex.plan.ai 'systemctl start litellm-codex-refresh'`, wait, re-probe; if it is
still broken, do not roll the image or repin blindly — ask.

## 7. Verify and report

End the run by re-running probe `b` (the healthy JSON is the fix's proof) and re-checking the
container log for the original error. Never claim a fix without the passing probe. If the run
changed the repo, commit it (`fix(codex): …`) and push; if it did not, change nothing. A run
that needed `fix-codex-litellm` Steps 3-6 records the new rev and the failure shape in the
project's topic `codex` (memory).
