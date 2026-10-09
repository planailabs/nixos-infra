---
mode: watch
every: 2m
devshell: false
title: codex.plan.ai failed upstream
---

The litellm proxy on codex.plan.ai just logged a Codex-upstream failure. The raw log line is:

{{message}}

Load the repo skill `codex-healthcheck` and run the probe from it (master key from `ssh root@codex.plan.ai 'grep ^LITELLM_MASTER_KEY /etc/litellm.env'`: `/v1/models` plus one tiny non-streamed `/v1/chat/completions`).
- Probe passes → this was a transient upstream blip or one bad request: change nothing, and message me in one line with the log line and the passing probe.
- Probe fails → load `fix-codex-litellm` and repair it as in the nightly check: container/config, then auth, then the fork + repin + `sh codex.sh` deploy; at most one deploy; never touch another host; never re-run `codex login` unattended; one repair per event, no loops.
- Account-side/upstream failures (401 on a revoked refresh token, or an unexplained Codex change) → report with evidence and ask, do not retry.

Report to me only when you repaired something, when I must act, or when a transient blip repeated (more than a handful of these lines in an hour). Otherwise stay silent. Write anything new you learned into the project topic `codex`.
