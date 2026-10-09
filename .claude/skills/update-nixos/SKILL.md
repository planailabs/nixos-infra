---
name: update-nixos
description: Use when updating NixOS flake inputs and deploying nixos-infra to all plan.ai servers, including fixing build errors and pushing resulting commits.
version: 1.1.0
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

This is also the skill behind the nightly, unattended update run. That run is
expected to be a quiet no-op on most days:

- Check whether anything actually moved *before* rewriting `flake.lock`
  (`nix flake update --dry-run`, or compare `nix flake metadata --json` input
  revs against the locked revs).
- If every input is already current, stop: report `nothing to update`. Do not
  deploy, commit or push.
- If inputs moved (or the dry run can't tell you, which is itself a reason to
  look), continue with the full workflow below.

Run fully autonomously when invoked as the nightly job — nobody is watching, so
do not ask for confirmation mid-run. Never leave production broken silently: if a
server is still failing after the 3 fix attempts, or you conclude you cannot fix
it, message the person while the run is still going (server name, last real
error, the repo/input you traced it to) and then carry on with the remaining
servers rather than aborting the run.

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

### Every server gets deployed

**Every deploy script in the repository root is part of this workflow.** Deploy the whole list below, every run — not just the ones named here, and not just the ones that succeeded last time. A host that was broken yesterday must be tried again today.

The full list is everything matching `*.sh` in the repository root that wraps `nixos-rebuild`, i.e. every script except `update.sh`, `reinstall-*.sh`, `sd-image.sh`, `incus-image.sh` and `export-incus.sh`. Before you start, take stock so the list can never silently shrink:

```bash
for f in *.sh; do
  case "$f" in reinstall-*|sd-image.sh|incus-image.sh|export-incus.sh|update.sh) continue;; esac
  grep -l nixos-rebuild "$f"
done
```

Cross-check that against the flake's `nixosConfigurations`:

```bash
grep -E '^      [a-z0-9-]+ = nixpkgs' flake.nix
```

Every configuration in the flake should either have a deploy script here or be a deliberate exception (currently `deploy`, which is the CI/deploy-host configuration itself). If you add a server to the flake, add its deploy script here and add it to this list. If you find a deploy script not in this list, deploy it anyway and add it here.

### Deploy scripts

| Script | Target | Notes |
|---|---|---|
| `sh chronos.sh` | chronos.plan.ai | via port 22222 |
| `sh logos.sh` | logos.plan.ai | |
| `sh atlas.sh` | atlas.plan.ai | `boot`, not `switch` |
| `sh aarch64.sh` | aarch64.plan.ai | needs a remote builder, see below |
| `sh omen.sh` | omen.plan.ai | `exec sh odysseus.sh` |
| `sh odysseus.sh` | omen.plan.ai | same host, config `odysseus`; `boot` |
| `sh peira.sh` | peira.plan.ai | |
| `sh metis.sh` | metis.plan.ai | |
| `sh obsidian.sh` | obsidian.plan.ai | |
| `sh agency.sh` | agency.plan.ai | |
| `sh relay.sh` | relay.plan.ai | |
| `sh peira-relay.sh` | relay.peira.plan.ai | |
| `sh charon.sh` | 49.12.9.126 | plain IP, not a hostname |
| `sh uptime.sh` | uptime.plan.ai | |
| `sh scanner.sh` | 150.40.117.230 | plain IP; hosts the rustnmap API |
| `sh mmrcd.sh` | mmrcd.plan.ai | |
| `sh cloud-images.sh` | cloud-images.plan.ai | |
| `sh hippocampus.sh` | hippocampus.plan.ai | |
| `sh hugger.sh` | hugger-omen.plan.ai | lives on the omen box |
| `sh hugger-amo.sh` | hugger-amo.plan.ai | |
| `sh hugger-hetzner.sh` | hugger-hetzner.plan.ai | |
| `sh hyperion.sh` | hyperion.plan.ai | `boot`, not `switch` |
| `sh codex.sh` | codex.plan.ai | |
| `sh pi.sh` | 200:7ef6:…:fdd9 | home-pi, Yggdrasil IPv6; builds on `aarch64.plan.ai` |

### Suggested batching

1. `chronos.sh`, `logos.sh`, `atlas.sh`
2. `aarch64.sh`, `omen.sh`, `peira.sh`
3. `metis.sh`, `obsidian.sh`, `agency.sh`
4. `relay.sh`, `peira-relay.sh`
5. `charon.sh`, `uptime.sh`, `scanner.sh`
6. `mmrcd.sh`, `cloud-images.sh`, `hippocampus.sh`
7. `hugger.sh`, `hugger-amo.sh`, `hugger-hetzner.sh`
8. `hyperion.sh`, `codex.sh`, `pi.sh`

Always include `relay.sh` and `peira-relay.sh` in the update workflow. Run them after the other batches unless the user explicitly asks to deploy a relay earlier or only deploy a relay. Treat relay deployment failures like any other deploy failure: inspect the first real Nix/build/SSH error, apply the minimal fix, and re-run only the failed relay script after successful servers have already completed.

`pi.sh` is the odd one out: it builds by delegating to `aarch64.plan.ai` (`--build-host`) and targets a Yggdrasil IPv6 address, so it needs both the builder and the Pi's mesh route to be up. Expect it to be the most fragile; treat failure like any other and report it.

### Running deploys from an agent host (reagent)

Two traps will silently ruin a run here. Both are about how the deploy is *started*, not about the repo.

1. **Launch detached, from a non-interactive shell.** Start each script as:

   ```bash
   setsid sh -c 'sh logos.sh > /tmp/logos.log 2>&1; echo EXIT=$? >> /tmp/logos.log' < /dev/null > /dev/null 2>&1 &
   ```

   - Launching with a bare `&` from an *interactive* terminal gets the process batch-stopped (`Stopped(SIGTTOU)`, state `T`) and it hangs forever mid-`nix-copy-closure`. It looks exactly like a slow deploy. Check for it with `ps -o pid,stat,cmd` — a `T` state that never changes means it is stopped, not working. `kill -CONT` resumes it, but prefer starting correctly with `setsid`.
   - Always capture to a log file and append `EXIT=$?`. Reading output back from a job handle is unreliable, and the exit code is the only trustworthy success signal.

2. **Run nix commands with `devshell: false`.** reagent runs commands inside `nix develop`, and this flake has no `devShells.*.default`. `nix` then copies the flake *through git* (for the `private` submodule), which re-enters the devshell lookup and fails with:

   ```
   error: flake 'git+file:///…/nixos-infra' does not provide attribute
          'devShells.x86_64-linux.default' … or 'defaultPackage.x86_64-linux'
   ```

   This looks like a broken flake and is not — it is the outer devshell. Run deploys and `nix build`/`nix flake` commands outside the devshell.

### Preflight before the first batch

Do these once, before launching anything; each one otherwise costs a full build cycle before failing:

- **Check out the `private` submodule.** The host configs `import "${self.private}/<host>.nix"` through git. If it is missing, every build dies with `path '…/private/chronos.nix' does not exist`:

  ```bash
  git submodule update --init --recursive
  ```

- **Seed `known_hosts` for every target**, or the deploy dies with `Host key verification failed` *after* a long build:

  ```bash
  for h in mmrcd.plan.ai cloud-images.plan.ai hippocampus.plan.ai codex.plan.ai hugger-hetzner.plan.ai; do
    ssh-keyscan -T 10 -t ed25519,rsa "$h" >> ~/.ssh/known_hosts 2>/dev/null
  done
  ```

- **Probe reachability first.** `nc -w5 -z <addr> 22` (or a `ssh -o BatchMode=yes -o ConnectTimeout=8 root@<host> hostname`) saves a build on a host that is simply down. A host that is down is not a build failure — report it as an outage (see Step 3).

- **Do not trust a first-attempt failure too quickly.** A single deploy attempt that fails with `Host key verification failed` or a transient `No route to host` is often just a missing known-host entry or a flaky route; fix that and re-run the affected script once before you start diagnosing Nix.

### Building for aarch64 (`aarch64.sh` and `pi.sh`)

Derivations for `aarch64-linux` cannot be built on an x86_64 host; they need a remote builder. `deploy/default.nix` registers `aarch64.plan.ai` as a `buildMachine`, but that only helps on that host. On the machine running this skill, supply the builder explicitly:

```bash
--builders 'ssh-ng://root@aarch64.plan.ai aarch64-linux - 4 1 nixos-test,big-parallel'
```

If you see hundreds of these, the builder was not used:

```
error: Cannot build '/nix/store/…-foo.drv'.
       Reason: platform mismatch
       Required system: 'aarch64-linux'
       Current system: 'x86_64-linux'
```

**`--builders` is a restricted setting.** The nix daemon honours it only from a *trusted* user, so as an untrusted user (reagent) you get:

```
warning: ignoring the client-specified setting 'builders', because it is a restricted
setting and you are not a trusted user
```

and the builds fail as above. `--option system-features '… aarch64-linux'` and `NIX_CONFIG`/`NIX_USER_CONF_FILES` are refused for the same reason (they are restricted settings *because* the user is untrusted — circular), and the untrusted daemon also rejects a local store with `Permission denied`. This is not a repo bug and cannot be fixed from inside the repo: it needs the agent host to add `reagent` (or whatever user runs this) to `nix.settings.trusted-users` or expose a privileged build path. Report it that way rather than inventing a workaround, and do not mark it fixed.

## Step 3: Handle build failures

If any deploy fails:

1. Read the build error output carefully.
2. Identify the NixOS module, package, or flake input causing the failure. Look for lines like `error:`, `attribute ... not found`, `build of ... failed`, `while evaluating`, and the first project-owned source path in the trace.
3. First fix issues owned by this repo. Check `modules/`, `configuration.nix`, `flake.nix`, and server-specific directories such as `atlas/`, `chronos/`, `logos/`, `pi/`, and `omen/`.
4. If the failure is caused by an upstream flake input or tool repository that plan.ai controls, fix it in that tool repository instead of working around it here:
   - Use `nix flake metadata --json` and `flake.lock` to identify the input name, locked rev, and repository URL.
   - Locate an existing checkout if available, otherwise clone the upstream repository under a temporary working directory.
   - Reproduce or inspect the failing derivation/source in that repository, make the minimal fix, run the relevant formatter/tests/build checks, commit with a conventional commit message, and push the upstream fix.
   - Return to `nixos-infra`, update only the affected flake input when possible (for example `nix flake lock --update-input <input>`; use `nix flake update` only if targeted update is not possible), inspect and commit the resulting `flake.lock` change.
   - Re-run only the affected server's deploy script.
5. Re-run only failed server deploy scripts after fixes; do not re-run successful servers unnecessarily.
6. If it fails again with a different Nix error, repeat the fix cycle up to 3 times per server, including upstream tool-repo fixes when that is the actual source of the failure.
7. If a server still fails after 3 fix attempts, report the failure to the user with the last real error and the repository/input you traced it to.

### Distinguish build failures from outages and environment problems

Not every failed deploy is a build error, and treating a dead host like a broken package wastes a whole run. Classify the first real error before fixing anything:

- **Outage — the host is unreachable.** Look for `No route to host`, `Connection timed out`, or SSH connect failures *after* a successful build. Do not touch the repo. Check whether the host is actually down (try the address directly, check the route), report it as an outage with the evidence, and move on to the remaining servers. Do not retry a dead host three times.
  - A hostname resolving to a *server-local* address is a common cause: if `omen.plan.ai` resolves only to an address inside its own /64, the route fails and `tracepath6` dies with `!H` at the last hop. That is a DNS/address or host problem, not ours.
  - A hostname resolving to a **Cloudflare** address (e.g. `2606:4700:…`) will never have port 22 open. Report it as a misconfigured record.
- **Environment — our user lacks a privilege.** The `--builders` / `trusted-users` case above. Not fixable in the repo; report the one-line change needed.
- **Build failure — a derivation or evaluation error.** Only this goes through the 3-attempt fix cycle below: `error:`, `Cannot build …`, `attribute … not found`, `while evaluating`, `build of … failed`, followed by the first project-owned source path.

### Fixing the actual fault, not the symptom

When a service fails *after* a successful `switch` (the deploy script exits non-zero because a unit is unhealthy), the interesting error is in the switch output and in the journal on the target host:

```bash
ssh root@<host> 'systemctl status <unit> --no-pager -l; journalctl -u <unit> -n 40 --no-pager'
```

A packaged binary that will not start is a packaging bug, not a NixOS config bug — fix it in the repository that owns the package, not by working around it here. For example, `status=127` with `error while loading shared libraries: libssl.so.3: cannot open shared object file` was `fixupPhase`'s `patchelf` emptying the binary's RPATH (`readelf -d <out>/bin/<bin> | grep -i path` showing a blank runpath); the fix belonged in the upstream package's `.nix` (`dontPatchELF`/`dontStrip` plus an explicit `postFixup` patchelf), followed by `nix flake lock --update-input <input>` here.

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

- whether anything was updated, and which inputs moved
- a per-server deploy result — success, fixed-then-success, or still failing with the final real error
- which servers deployed successfully
- which servers failed and the final error, classified as a build failure vs. a host outage vs. an environment limitation
- what fixes were applied, which files or upstream repositories they touched, and whether they were pushed
- anything deliberately left alone for a human

## Common Pitfalls

1. Do not run more than 3 deploys in parallel.
2. Do not use subagents for the deploy scripts.
3. Do not push before all deploys and fix commits are complete.
4. Re-run only failed deploys after fixes; do not re-run successful servers unnecessarily.
5. Use conventional commit messages for all commits created during this workflow.
6. `nixos-rebuild-ng` may try to stat `/etc/nixos/system.nix` even when `--flake` is passed. The deploy wrappers should set `NIX_PATH=nixos-system="$PWD/flake.nix"` after `cd`-ing into the repo so deployments do not fail when `/etc/nixos` points into an unreadable `/root` directory.
7. Deploy **every** script in the list above, every run. Do not narrow the fleet to the hosts that worked last time, and do not skip a host because it failed previously — try it again.
8. Verify success from the exit code in the log and from the target host's health (`systemctl is-system-running`, `systemctl --failed`), not from the tail of the output. `nixos-rebuild` can print `Done.` and still exit non-zero when a unit failed to start.
9. A deploy that appears to hang for tens of minutes is usually *stopped*, not slow: check `ps -o pid,stat,cmd` for state `T` (see the `setsid`/`SIGTTOU` note above).
10. Confirm the working tree at the end: `git status --short` clean, `git log --oneline origin/trunk..HEAD` empty, no stray `nixos-rebuild` processes. Only `flake.lock` (and genuinely needed fixes) should differ from the starting commit.

## Verification Checklist

- [ ] `nix flake update` completed successfully
- [ ] `flake.lock` update was committed with a conventional commit message
- [ ] every deploy script in the table was run, in batches of at most 3
- [ ] unreachable hosts were reported as outages, not retried as build failures
- [ ] any failed deploys were diagnosed and retried after fixes
- [ ] any fix changes were committed with conventional commit messages, upstream fixes pushed to their own repository first
- [ ] deployed hosts were checked for health, not just for a zero exit
- [ ] commits were pushed
- [ ] final summary includes successes, failures, and fixes
