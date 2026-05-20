# Agent Instructions for nixos-infra

This repository contains NixOS infrastructure for plan.ai servers.

## Shared skills

### update-nixos

All agents working in this repository should treat the `update-nixos` workflow below as available and user-invocable. Agent-specific copies live at `.claude/skills/update-nixos/SKILL.md` and `.hermes/skills/update-nixos/SKILL.md`; this section mirrors the workflow so agents that read `AGENTS.md` can use the same procedure.

Use this skill when the user asks to update NixOS, update flake inputs, upgrade the infra, or deploy the updated NixOS infrastructure.

#### Step 1: Update flake inputs

Run `nix flake update` in the repo root. Wait for it to complete. If it fails, diagnose and report to the user.

After `nix flake update` succeeds, commit the updated `flake.lock` with the message `chore: upgrade depss`.

#### Step 2: Deploy servers in batches of 3

Deploy the servers in batches of at most 3 in parallel. Within a batch, launch each deploy as a background shell command running the script from the repo root. Wait for all commands in the batch to complete before starting the next batch, then inspect each command's output.

Do not delegate deploys to subagents or external agent workers: long-running background deploy scripts can outlive delegated agent contexts. Run the deploy scripts directly from the shell.

The deploy scripts are:

1. `sh chronos.sh` — deploys to chronos.plan.ai using port 22222
2. `sh logos.sh` — deploys to logos.plan.ai
3. `sh atlas.sh` — deploys to atlas.plan.ai
4. `sh aarch64.sh` — deploys to aarch64.plan.ai
5. `sh omen.sh` — deploys to omen
6. `sh peira.sh` — deploys to peira.plan.ai
7. `sh metis.sh` — deploys to metis.plan.ai
8. `sh obsidian.sh` — deploys to obsidian.plan.ai
9. `sh agency.sh` — deploys to agency.plan.ai

Suggested batching: `(chronos, logos, atlas)` -> `(aarch64, omen, peira)` -> `(metis, obsidian, agency)`.

#### Step 3: Handle build failures

If any deploy fails:

1. Read the build error output carefully.
2. Identify the NixOS module or package causing the failure. Look for lines like `error:`, `attribute ... not found`, or `build of ... failed`.
3. Find and fix the relevant `.nix` file in the repo. Check `modules/`, `configuration.nix`, `flake.nix`, and server-specific directories such as `atlas/`, `chronos/`, `logos/`, `pi/`, `omen/`.
4. Re-run only the failed server's deploy script.
5. If it fails again with a different error, repeat the fix cycle up to 3 times per server.
6. If a server still fails after 3 fix attempts, report the failure to the user.

#### Step 4: Commit fixes

After all deploys complete, if any `.nix` files were modified to fix build errors, commit those changes with a descriptive commit message like `fix: <what was fixed>`. If fixes were applied for multiple servers, they can be combined into a single commit.

#### Step 5: Push commits

After all deploys complete and any fix commits have been made, run `git push` to push all commits to the remote.

#### Step 6: Summary

After all deploys complete or exhaust retries, report:

- Which servers deployed successfully
- Which servers failed and the final error
- What fixes were applied, if any
