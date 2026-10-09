---
alwaysApply: true
---
# A gcroot for every system build before deploying

Before running a deploy script (`<host>.sh`, anything that runs `nixos-rebuild`
for a host), build that host's system toplevel with a gcroot in `.gcroots/`,
named after the configuration, with the same flags the script uses:

```sh
NIX_PATH=nixos-system="$PWD/flake.nix" nix build ".#nixosConfigurations.<config>.config.system.build.toplevel" --impure -L -o .gcroots/<config>
```

`<config>` is the script's `--flake .#<config>` (e.g. `odysseus.sh` deploys
`odysseus`). Only then run the deploy script: it evaluates the same system and
deploys the build the gcroot holds, so the deployed system can't be garbage
collected here. Do it for every host you deploy, again for every new build.

`.gcroots/` and `.reagent/` are gitignored: never commit them. If a host's
system can't be built on this machine (another platform, e.g. `pi.sh` builds on
the aarch64 builder), say so instead of deploying without a gcroot.
