# Zitadel Login v2 patches

Against `zitadel/zitadel` v4.20.2 (paths from the repo root, `apps/login/…`); for
the login package of the plan-ai nixpkgs fork's Zitadel v4.

`0001-…`: users have to accept the terms of service and privacy policy (AGB &
Datenschutzerklärung) before a sign-in completes, again whenever they change.

- The documents are what the legal settings link to (`tosLink`, `privacyLink`;
  `ansible/zitadel` sets them from `legal_tos_link`). One URL may serve both.
- Their sha256 (of both, if they differ) is fetched at runtime and is compared
  with the user's metadata key `agb`. A user whose hash is missing or outdated
  gets `/legal`; accepting stores the current hash, as registering does.
- `prompt=none` answers `consent_required`. A document that can't be fetched
  doesn't block sign-in (logged); the last fetched hash is kept.
- Env: `LEGAL_DOCUMENT_TTL_SECONDS` (300), `LEGAL_ACCEPTANCE_METADATA_KEY` (`agb`).
- The login's service user needs `IAM_LOGIN_CLIENT` (has `user.read`/`user.write`
  for the metadata), as upstream requires anyway.
- Not covered: the device flow (its own consent page).

To change: work on the `plan-ai/legal-acceptance` branch of a zitadel checkout
(`git am` this onto the tag), `pnpm exec vitest --run` in `apps/login`, then
`git format-patch -1 -o <here>`.
