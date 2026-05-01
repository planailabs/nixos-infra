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

## Step 2: Deploy servers in batches of 3

Deploy the servers in batches of **at most 3 in parallel**. Within a batch, launch each deploy as a background Bash command (`run_in_background: true`) running the script from the repo root. Wait for all 3 to complete before starting the next batch — use TaskOutput with `block: true` on each background task ID to await completion, then Read the output file to inspect results.

Do NOT use the Agent tool for deploys — agents abandon long-running background scripts before they finish. Run the deploy scripts directly via Bash.

The deploy scripts are:

1. `sh chronos.sh` — deploys to chronos.plan.ai (uses port 22222)
2. `sh logos.sh` — deploys to logos.plan.ai
3. `sh atlas.sh` — deploys to atlas.plan.ai
4. `sh aarch64.sh` — deploys to aarch64.plan.ai
5. `sh omen.sh` — deploys to omen
6. `sh peira.sh` — deploys to peira.plan.ai
7. `sh metis.sh` — deploys to metis.plan.ai
8. `sh obsidian.sh` — deploys to obsidian.plan.ai

Suggested batching: (chronos, logos, atlas) → (aarch64, omen, peira) → (metis, obsidian).

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
