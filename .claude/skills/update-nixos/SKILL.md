---
name: update-nixos
description: Update NixOS flake inputs and deploy to all servers, fixing build errors if needed
user_invocable: true
---

# Update NixOS Infrastructure

Follow these steps to update and deploy the NixOS infrastructure:

## Step 1: Update flake inputs

Run `nix flake update` in the repo root. Wait for it to complete. If it fails, diagnose and report to the user.

After `nix flake update` succeeds, commit the updated `flake.lock` with the message `chore: upgrade depss`.

## Step 2: Deploy to all servers in parallel

Run all server deploy scripts **in parallel** using the Agent tool. Launch one agent per server, all in a single message. Each agent should run its deploy script from the repo root with a timeout of 1200000ms (20 minutes).

The deploy scripts are:

1. `sh chronos.sh` — deploys to chronos.plan.ai (uses port 22222)
2. `sh logos.sh` — deploys to logos.plan.ai
3. `sh atlas.sh` — deploys to atlas.plan.ai
4. `sh aarch64.sh` — deploys to aarch64.plan.ai
5. `sh omen.sh` — deploys to omen

## Step 3: Handle build failures

If any deploy agent reports a failure:

1. Read the build error output carefully.
2. Identify the NixOS module or package causing the failure — look for lines like `error:`, `attribute ... not found`, or `build of ... failed`.
3. Find and fix the relevant `.nix` file in the repo (check `modules/`, `configuration.nix`, `flake.nix`, and the server-specific directories like `atlas/`, `chronos/`, `logos/`, `pi/`, `omen/`).
4. Re-run **only** the failed server's deploy script.
5. If it fails again with a different error, repeat the fix cycle up to 3 times per server.
6. If a server still fails after 3 fix attempts, report the failure to the user.

## Step 3.5: Commit fixes

After all deploys complete, if any `.nix` files were modified to fix build errors, commit those changes with a descriptive commit message like `fix: <what was fixed>`. If fixes were applied for multiple servers, they can be combined into a single commit.

## Step 4: Push commits

After all deploys complete and any fix commits have been made, run `git push` to push all commits to the remote.

## Step 5: Summary

After all deploys complete (or exhaust retries), report:
- Which servers deployed successfully
- Which servers failed and what the final error was
- What fixes were applied (if any)
