# hippocampus

[hippocampus](https://git.plan.ai/plan-ai/hippocampus) — a frozen causal LM with
a trainable knowledge-graph adapter, served over an OpenAI-compatible API with a
chat UI at `hippocampus.plan.ai`.

## Overview

- **Hostname:** `hippocampus`
- **Address:** `2a01:4f9:1a:90eb::a:add` (LXC on atlas, IPv6 only — see below)
- **Platform:** x86_64-linux (LXC container)
- **Base:** modelled on `logos` (common + container modules, yggdrasil, nginx + ACME)

## Services

The application is two halves, and this host runs both:

- **hippocampus-frontend** (`127.0.0.1:8080`) — accounts, sessions, quotas,
  data pools and the dataset registry. Carries no model stack at all. Fronted
  by nginx at `hippocampus.plan.ai`.
- **hippocampus-generator** (`127.0.0.1:8100`) — the frozen model, the adapter
  and a dataset cache. It registers itself with the frontend over loopback
  using the shared master token, and the frontend routes generation to it.
- **garage** (`127.0.0.1:3900`) — the S3 dataset store. The application insists
  on exactly one store "so a dataset is never in two places"; a single-node
  garage on this host is that store, without an external provider.
- **Nginx** — reverse proxy with ACME TLS (cert distributed from `acme.plan.ai`).
- **Yggdrasil** — mesh networking on port 14466 (lets `logos` scrape node metrics).

## The generator runs on CPU

This is a container, not a GPU host, so `deviceMap = "cpu"` and it serves the
**SmolLM2 1.7B** adapter only — the Qwen3 8B and Qwen3.5 9B adapters want a
card. Expect first-token latency in the tens of seconds; the nginx vhost has
`proxy_buffering off` and hour-long timeouts to match.

Upstream's `packages.hippocampus-generator` is built against CUDA torch, which
here is both useless and unbuildable (it would compile magma, triton and nccl
locally). `default.nix` instead adds the CPU model stack to the frontend
package — the same application, the same `generator` extra — from the nixpkgs
hippocampus pins, all of which substitutes from cache.nixos.org.

A GPU generator elsewhere (vast.ai, per the upstream README) can register
against this frontend at any time and will be preferred for its own models.

**Memory:** the incus default profile caps containers at 4 GiB, which is not
enough to load a 1.7B checkpoint. This instance overrides `limits.memory` to
10 GiB.

## First boot

`garage-hippocampus-init` gives the garage node its layout, then creates the
`hippocampus` bucket and imports the S3 key both services authenticate with
(defined once, in `private/hippocampus.nix`). `hippocampus-seed` then imports
the graphs that ship with the repo — `examples` and `scientific-vijay2021` — but
only into an empty store, so a deleted dataset stays deleted.

The generator pulls its base weights from Hugging Face on the first request and
keeps them in `/var/lib/hippocampus-generator/huggingface`.

## Sign-in

Generic OIDC against Google (`OIDC_PROVIDERS=google`). Two things worth knowing:

- **The app has no domain filter.** Any Google account can sign in and will be
  created as a plain user. `ADMIN_EMAILS` is set so that admin is granted by
  name — without it the *first* account to arrive would have been made admin.
- The OAuth client's redirect URI must be
  `https://hippocampus.plan.ai/auth/callback/google`.

## IPv6 only

Like `metis`, `obsidian` and `peira`, the DNS record is a plain `AAAA` — no
IPv4. Fronting it with the Cloudflare proxy would give it IPv4, but also a
100-second origin timeout and a 100 MB body limit, neither of which suits slow
CPU generation or PDF pool uploads.
