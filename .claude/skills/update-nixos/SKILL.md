---
name: update-nixos
description: Use when updating NixOS flake inputs and deploying nixos-infra to all plan.ai servers, including fixing build errors and pushing resulting commits.
version: 1.0.0
author: plan.ai
license: MIT
metadata:
  hermes:
    tags: [nixos, infrastructure, deploy, flake-update]
    related_skills: []
user_invocable: true
---

# Update NixOS Infrastructure

## Overview

This skill updates the nixos-infra flake inputs, deploys the resulting NixOS configurations to all servers, fixes build errors when possible, commits any fixes, and pushes the result.

Run commands from the repository root.

## When to Use

Use this skill when the user asks to:

- update NixOS
- update or upgrade nixos-infra
- update flake inputs
- deploy the updated NixOS infrastructure
- run the infra update workflow

## Step 1: Update flake inputs

Run:

```bash
nix flake update
```

Wait for it to complete. If it fails, diagnose the failure and report it to the user.

After `nix flake update` succeeds, commit the updated `flake.lock` using the conventional commit message below:

```bash
git add flake.lock
git commit -m 'chore: update flake inputs'
```

## Step 2: Deploy servers in batches of 3

Deploy servers in batches of at most 3 in parallel. Within each batch, launch each deploy script directly as a background shell process from the repository root. Wait for every process in the batch to complete, then inspect all output before starting the next batch.

Do not delegate deploys to subagents or external agent workers. Long-running deploy scripts can outlive delegated agent contexts; run the deploy scripts directly from the shell.

Deploy scripts:

1. `sh chronos.sh` — deploys to chronos.plan.ai using port 22222
2. `sh logos.sh` — deploys to logos.plan.ai
3. `sh atlas.sh` — deploys to atlas.plan.ai
4. `sh aarch64.sh` — deploys to aarch64.plan.ai
5. `sh omen.sh` — deploys to omen
6. `sh peira.sh` — deploys to peira.plan.ai
7. `sh metis.sh` — deploys to metis.plan.ai
8. `sh obsidian.sh` — deploys to obsidian.plan.ai
9. `sh agency.sh` — deploys to agency.plan.ai

Suggested batching:

1. `chronos.sh`, `logos.sh`, `atlas.sh`
2. `aarch64.sh`, `omen.sh`, `peira.sh`
3. `metis.sh`, `obsidian.sh`, `agency.sh`

## Step 3: Handle build failures

If any deploy fails:

1. Read the build error output carefully.
2. Identify the NixOS module or package causing the failure. Look for lines like `error:`, `attribute ... not found`, or `build of ... failed`.
3. Find and fix the relevant `.nix` file in the repo. Check `modules/`, `configuration.nix`, `flake.nix`, and server-specific directories such as `atlas/`, `chronos/`, `logos/`, `pi/`, and `omen/`.
4. Re-run only the failed server's deploy script.
5. If it fails again with a different error, repeat the fix cycle up to 3 times per server.
6. If a server still fails after 3 fix attempts, report the failure to the user.

## Step 4: Commit fixes

After all deploys complete, if any `.nix` files were modified to fix build errors, commit those changes with a descriptive conventional commit message:

```bash
git add <changed-files>
git commit -m 'fix: <what was fixed>'
```

If fixes were applied for multiple servers, they can be combined into a single commit.

## Step 5: Push commits

After all deploys complete and any fix commits have been made, push all commits:

```bash
git push
```

## Step 6: Summary

Report:

- Which servers deployed successfully
- Which servers failed and the final error
- What fixes were applied, if any

## Common Pitfalls

1. Do not run more than 3 deploys in parallel.
2. Do not use subagents for the deploy scripts.
3. Do not push before all deploys and fix commits are complete.
4. Re-run only failed deploys after fixes; do not re-run successful servers unnecessarily.
5. Use conventional commit messages for all commits created during this workflow.
6. `nixos-rebuild-ng` may try to stat `/etc/nixos/system.nix` even when `--flake` is passed. The deploy wrappers should set `NIX_PATH=nixos-system="$PWD/flake.nix"` after `cd`-ing into the repo so deployments do not fail when `/etc/nixos` points into an unreadable `/root` directory.

## Verification Checklist

- [ ] `nix flake update` completed successfully
- [ ] `flake.lock` update was committed with a conventional commit message
- [ ] all deploy scripts were run in batches of at most 3
- [ ] any failed deploys were diagnosed and retried after fixes
- [ ] any fix changes were committed with conventional commit messages
- [ ] commits were pushed
- [ ] final summary includes successes, failures, and fixes
