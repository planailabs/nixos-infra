---
name: zitadel-bootstrap
description: Use when setting up Zitadel for a new plan.ai-style deployment (a cloud console, a chat/agent and optionally a Harbor on their own domains, like webapp.agency) or re-running it — asks for the domains, org and login names, social-login credentials and shared keys, writes ansible/zitadel/deployments/<name>.yml, runs setup.yml (Zitadel orgs, login policy, IdPs, projects, clients, service users) and secrets.yml (the rest of the secrets, private/<name>-{cloud,chat,harbor}.nix).
version: 1.0.0
author: plan.ai
license: MIT
metadata:
  tags: [nixos, zitadel, ansible, secrets, bootstrap]
  related_skills: [update-nixos]
user_invocable: true
---

# Zitadel bootstrap for a console + chat deployment

`ansible/zitadel/` does what was done by hand for webapp.agency: everything a
console (plan-ai-cloud), a chat (plan-ai-chat) and a Harbor need from their
Zitadel, and the private NixOS files that carry the secrets. It is idempotent
and its state, `private/<deployment>-zitadel.json`, is the source of truth:
delete a secret from it to rotate it. `deployments/webapp.yml` is a worked
example; the VM test (`nix build .#checks.x86_64-linux.zitadel-ansible -L`)
shows a full run.

Run everything from the `nixos-infra` root. Never print the state file or the
rendered files: they are secrets.

## 1. Ask

Ask the user, with the defaults in brackets (webapp.agency's values as the
example). Don't guess domains or names: they become clients, orgs and what
people see on the login page.

| Variable | Question | Example |
| --- | --- | --- |
| `deployment` | Short name for files and the console's service user | `webapp` |
| `zitadel_url` | Zitadel's URL (the instance must exist, first-run setup done) | `https://id.webapp.agency` |
| `zitadel_pat_command` | How to read an IAM_OWNER PAT (the first instance's bootstrap machine user writes one with `FirstInstance.PatPath`) | `ssh root@<host> cat /var/lib/zitadel/bootstrap.pat` |
| `partner_org_name` | The org partners sign in through | `webapp-agency` |
| `partner_login_name` | What the services call that sign-in | `the.webapp.agency Partner` |
| `apps_project_name` | Project holding the services' clients | `webapp.agency apps` |
| `console_domain` | The console's domain | `cms.webapp.agency` |
| `agent_domain` | The chat's domain | `agent.webapp.agency` |
| `harbor_domain` | Harbor's domain, or empty for none | `harbor.webapp.agency` |
| `admin_emails` | Who administers console, chat and Harbor | `[maciej@plan.ai]` |
| `internal_login_name`, `internal_allowed_domains` | Name and allowed email domains of the services' own Google sign-in (optional) | `the.webapp.agency Internal`, `[plan.ai, webapp.agency]` |
| `litellm_url`, `litellm_key_alias` | LiteLLM for the chat's agents, and the key's alias | `https://codex.plan.ai`, `webapp-chat` |
| `harbor_ssh`, `harbor_database` | Where to insert the console's Harbor admin token (empty: skip) | `root@<harbor host>`, `harbor` |

Then the secrets, as environment variables (only on the first run; the state
remembers them):

- `GITHUB_CLIENT_ID`/`_SECRET`, `GOOGLE_CLIENT_ID`/`_SECRET`: the partner org's
  social logins. Give the user the callback to register:
  `<zitadel_url>/ui/login/login/externalidp/callback`.
- `INTERNAL_GOOGLE_CLIENT_ID`/`_SECRET`: the services' own Google client;
  redirect URIs `https://<console_domain>/auth/google/callback` and
  `https://<harbor_domain>/auth/google/callback`.
- `LITELLM_MASTER_KEY`, `REGISTRY_ADMIN_TOKEN`: shared with cloud.plan.ai,
  in `private/logos-cloud.nix` (`inference.master_key`, `registry.admin_token`).
- `CONTEXT7_API_KEY`, `FIRECRAWL_API_KEY`: the agents' MCP servers (plan.ai's
  are in `private/logos-chat.nix`), optional.

Read shared values from the private files into the environment yourself;
don't ask the user to paste what the repo already has.

## 2. Run

```bash
cd ansible/zitadel
$EDITOR deployments/<deployment>.yml              # from the answers
GITHUB_CLIENT_ID=… GITHUB_CLIENT_SECRET=… GOOGLE_CLIENT_ID=… GOOGLE_CLIENT_SECRET=… \
  ansible-playbook setup.yml -e @deployments/<deployment>.yml
LITELLM_MASTER_KEY=… REGISTRY_ADMIN_TOKEN=… INTERNAL_GOOGLE_CLIENT_ID=… … \
  ansible-playbook secrets.yml -e @deployments/<deployment>.yml
```

`setup.yml` writes the state after every step that produced a secret, so a
failed run loses nothing; run it again. A second run of either playbook
reports `changed=0`.

## 3. Wire up

- The host's config imports `private/<deployment>-cloud.nix` and `-chat.nix`
  (webapp/cloud.nix and webapp/chat.nix show how), Harbor's
  `private/<deployment>-harbor.nix`.
- Public ids the configs need: the chat's `connector.console.audience_project_id`
  is `console_api.project_id` and the Harbor app's `mcp.audience_project_id`
  is `harbor_api.project_id` (read with `jq` from the state; ids aren't secret).
- Commit the private repo (state and rendered files), then nixos-infra's
  `private` pointer; deploy.

## Notes

- An existing social login is left as it is; to change its secret, delete it
  in Zitadel and run `setup.yml` again with the new credentials.
- The bootstrap PAT is IAM_OWNER: once the deployment is up, remove the
  bootstrap user's PAT in Zitadel and delete the PatPath file, and point
  `zitadel_pat_command` at the console's own IAM_OWNER PAT in the state
  (`jq -r .console_pat …/private/<deployment>-zitadel.json`), as
  `deployments/webapp.yml` does.
