---
alwaysApply: true
---
# Never commit the `private` submodule pointer by accident

`private` (secrets: tokens, keys, per-host config) is a submodule. Its pointer
in this repo decides which secrets every host gets. A commit that moves it to an
older revision drops secrets that services need: on 2026-11-06 a flake-input
update committed a stale checkout of `private` (0f2eb26 → 142ca5f) and the chat
and the cloud console crash-looped on logos once deployed.

- Before working, bring the submodule to the commit this repo records:
  `git submodule update --init private`.
- Stage files by name (`git add flake.lock`, `git add logos/chat.nix`), never
  `git add -A`, `git add .` or `git commit -a`.
- Before every commit, `git diff --cached --submodule=log private` must be empty
  unless the task is about `private`. If it isn't, `git restore --staged private`.
- If the task *is* about `private`: commit in `private` first, push it, then
  record the new pointer here. Only ever move the pointer forward:
  `git -C private merge-base --is-ancestor <old> <new>` must succeed.
