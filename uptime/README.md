# uptime

Uptime Kuma on `uptime.plan.ai`, nginx in front of `127.0.0.1:3636`.

## What lives where

- `default.nix` / `nginx.nix` / `uptime-kuma.nix` — host, vhost and service.
- **Monitors, groups and the status page are not in this repo.** They are rows
  in `/var/lib/uptime-kuma/kuma.db` (`monitor`, `group`, `monitor_group`,
  `status_page`), created and edited in the admin UI at
  `https://uptime.plan.ai/dashboard`. Changing them means either the UI or a
  SQLite write against the live database — never a Nix change.

## The public status page

`/api/status-page/public` (slug `public`, "plan.ai Status", group assignment
`auto`) is world-readable and lists every monitor by its internal name:

    mgmt · mgmt API · Relay · Chat · Nix Cache (Xzar) · GitLab · GitLab SSH …
    Supabase Auth/Consent Proxy · External Authentication Handler (Zitadel) …

That is the internal inventory — host codenames, the Nix cache, the GitLab
trio, the Zitadel/Supabase auth stack — published to anyone who asks. It is a
data change, not a config change, so it is an **owner action**: either rename
the monitors in the UI to customer-facing labels ("Git", "Package cache",
"Sign-in"), or switch the status page off `auto` and publish only the
deliberately public services.

Also worth knowing: `/metrics` is already protected (401), the dashboard login
page is public (`/dashboard`), and Kuma is patched by the flake input — check
`/setup` is closed after any restore from backup.
