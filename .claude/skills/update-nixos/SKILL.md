---
name: update-nixos
description: Update NixOS flake inputs and deploy to all servers, fixing build errors if needed
user_invocable: true
---

# Update NixOS Infrastructure

Follow these steps to update and deploy the NixOS infrastructure:

## Step 1: Update flake inputs

Run `nix flake update` in the repo root. Wait for it to complete. If it fails, diagnose and report to the user.

## Step 2: Deploy to each server

Run each server's deploy script **sequentially**. The deploy scripts are:

2. `sh chronos.sh` — deploys to chronos.plan.ai (uses port 22222)
3. `sh logos.sh` — deploys to logos.plan.ai
1. `sh atlas.sh` — deploys to atlas.plan.ai

Run each from the repo root. Use a timeout of 600000ms (10 minutes) per deploy.

## Step 3: Handle build failures

If a deploy script fails:

1. Read the build error output carefully.
2. Identify the NixOS module or package causing the failure — look for lines like `error:`, `attribute ... not found`, or `build of ... failed`.
3. Find and fix the relevant `.nix` file in the repo (check `modules/`, `configuration.nix`, `flake.nix`, and the server-specific directories like `atlas/`, `chronos/`, `logos/`, `pi/`).
4. Re-run **only** the failed server's deploy script.
5. If it fails again with a different error, repeat the fix cycle up to 3 times per server.
6. If a server still fails after 3 fix attempts, move on to the next server and report the failure to the user at the end.

## Step 3.5: Commit fixes after each server

After a server deploys successfully (whether on first try or after fixes), if any `.nix` files were modified to fix build errors, commit those changes before moving on to the next server. Use a descriptive commit message like `<server>: <what was fixed>`. This ensures fixes are saved incrementally and not lost if a later deploy fails.

## Step 4: Summary

After all deploys complete (or exhaust retries), report:
- Which servers deployed successfully
- Which servers failed and what the final error was
- What fixes were applied (if any)
