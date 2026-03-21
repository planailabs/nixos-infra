#!/bin/sh

set -exu

mkdir -p /root/.ssh
echo -e "Host github.com\n\tStrictHostKeyChecking no\n" >> /root/.ssh/config
echo -e "Host git.plan.ai\n\tStrictHostKeyChecking no\n" >> /root/.ssh/config
if test -v ID_ED; then
  set +x
  echo "$ID_ED" > /root/.ssh/id_ed25519
  set -x
fi
chmod 400 /root/.ssh/id_ed25519

nix flake update
git config --global user.name "CI"
git config --global user.email "ci@git.plan.ai"
if git commit -m "Update nixos [ci skip]" flake.lock; then
  git push -o ci.skip git@git.mkg20001.io:plan-ai/nixos-infra HEAD:trunk
fi
